/**
 * Announcements Routes
 *
 * Admin broadcasts to all members. Stored in `announcements` table with
 * per-user read tracking in `announcement_reads`.
 *
 * Flutter endpoints used:
 *   GET  /announcements                 — paginated list
 *   GET  /announcements/unread-count    — badge count
 *   GET  /announcements/:id             — single announcement
 *   POST /announcements/:id/read        — mark one as read
 *   POST /announcements/read-all        — mark all as read
 */

const express = require('express');
const { param, query } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

/**
 * Serialise an announcement into the shape the Flutter `Announcement` model
 * reads.
 *
 * The table stores `body` and `category`, while the client model reads
 * `content` and `type` (plus camelCase dates and `isPinned`). Returning the raw
 * row — which is what this endpoint used to do — meant the client rendered a
 * blank title/body even when a row existed. Translation happens here so the
 * mismatch is fixed in one place rather than in the client and the admin UI
 * separately.
 */
function toClient(row, isRead) {
  return {
    id: row.id,
    title: row.title || '',
    content: row.body || '',
    body: row.body || '',
    type: row.category || 'general',
    category: row.category || 'info',
    displayMode: row.display_mode || 'banner',
    priority: row.priority || 'normal',
    isPinned: Boolean(row.is_pinned),
    dismissible: row.dismissible !== false,
    actionLabel: row.action_label || null,
    actionUrl: row.action_url || null,
    linkUrl: row.link_url || null,
    createdAt: row.created_at || row.published_at,
    publishedAt: row.published_at || row.created_at,
    expiresAt: row.expires_at,
    isRead,
  };
}

/**
 * Only announcements that are active, published, unexpired and targeted at this
 * member are visible. RLS enforces the same rule for direct client access, but
 * the API uses the service role (which bypasses RLS), so the filter has to be
 * applied here too — otherwise a direct message to one member would leak into
 * every member's list.
 */
async function visibleAnnouncementsFor(profileId, { activeOnly = true } = {}) {
  let q = supabase.from('announcements').select('*');
  if (activeOnly) q = q.eq('is_active', true);
  q = q.order('is_pinned', { ascending: false }).order('created_at', { ascending: false });

  const { data, error } = await q;
  if (error) throw error;

  // Resolve the member's organization once, for the 'organization' audience.
  const { data: profile } = await supabase
    .from('profiles')
    .select('organization_id')
    .eq('id', profileId)
    .maybeSingle();
  const orgId = profile?.organization_id || null;

  const now = Date.now();
  return (data || []).filter((a) => {
    if (a.published_at && new Date(a.published_at).getTime() > now) return false;
    if (a.expires_at && new Date(a.expires_at).getTime() <= now) return false;
    if (a.audience === 'specific') {
      return Array.isArray(a.target_profile_ids) && a.target_profile_ids.includes(profileId);
    }
    if (a.audience === 'organization') {
      return Boolean(orgId) && a.target_organization_id === orgId;
    }
    return true; // audience 'all'
  });
}

/**
 * GET /api/v1/announcements/unread-count
 * Must be defined before /:id to avoid route collision.
 */
router.get('/unread-count', async (req, res) => {
  try {
    const visible = await visibleAnnouncementsFor(req.user.id);

    const { data: myReads, error: readErr } = await supabase
      .from('announcement_reads')
      .select('announcement_id')
      .eq('profile_id', req.user.id);
    if (readErr) throw readErr;

    const readSet = new Set((myReads || []).map((r) => r.announcement_id));
    const count = visible.filter((a) => !readSet.has(a.id)).length;

    res.json({ success: true, count });
  } catch (err) {
    logger.error('announcements unread-count error:', err);
    res.json({ success: true, count: 0 });
  }
});

/**
 * POST /api/v1/announcements/read-all
 * Must be defined before /:id to avoid route collision.
 */
router.post('/read-all', async (req, res) => {
  try {
    // Only announcements this member can actually see may be marked read —
    // otherwise the read table accumulates ids for content they never received.
    const visible = await visibleAnnouncementsFor(req.user.id);

    if (visible.length > 0) {
      const { data: alreadyRead } = await supabase
        .from('announcement_reads')
        .select('announcement_id')
        .eq('profile_id', req.user.id);

      const readSet = new Set((alreadyRead || []).map((r) => r.announcement_id));
      const toInsert = visible
        .filter((a) => !readSet.has(a.id))
        .map((a) => ({
          profile_id: req.user.id,
          announcement_id: a.id,
          read_at: new Date().toISOString(),
        }));

      if (toInsert.length > 0) {
        await supabase.from('announcement_reads').insert(toInsert);
      }
    }

    res.json({ success: true, message: 'All announcements marked as read.' });
  } catch (err) {
    logger.error('announcements read-all error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/announcements
 */
router.get(
  '/',
  [
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('unreadOnly').optional().isBoolean(),
  ],
  validate,
  async (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;
      const unreadOnly = req.query.unreadOnly === 'true';

      const visible = await visibleAnnouncementsFor(req.user.id);

      const { data: myReads } = await supabase
        .from('announcement_reads')
        .select('announcement_id')
        .eq('profile_id', req.user.id);

      const readSet = new Set((myReads || []).map((r) => r.announcement_id));

      let items = visible.map((a) => toClient(a, readSet.has(a.id)));
      if (unreadOnly) items = items.filter((a) => !a.isRead);

      // Paginate the filtered list, not the raw table, so an announcement
      // targeted away from this member cannot consume a page slot.
      const total = items.length;
      const start = (page - 1) * limit;
      const paged = items.slice(start, start + limit);

      res.json({
        success: true,
        announcements: paged,
        total,
        page,
        limit,
        unreadCount: items.filter((a) => !a.isRead).length,
        totalCount: total,
      });
    } catch (err) {
      logger.error('announcements list error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/announcements/:id
 */
router.get('/:id', [param('id').notEmpty()], validate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('announcements')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();

    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Announcement not found' });

    // Do not disclose an announcement targeted at somebody else. Serving it by
    // id would leak content the member was deliberately excluded from.
    const visible = await visibleAnnouncementsFor(req.user.id, { activeOnly: false });
    if (!visible.some((a) => a.id === data.id)) {
      return res.status(404).json({ success: false, message: 'Announcement not found' });
    }

    const { data: readRow } = await supabase
      .from('announcement_reads')
      .select('id')
      .eq('profile_id', req.user.id)
      .eq('announcement_id', data.id)
      .maybeSingle();

    res.json({ success: true, ...toClient(data, !!readRow) });
  } catch (err) {
    logger.error('announcements get error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * POST /api/v1/announcements/:id/read
 */
router.post('/:id/read', [param('id').notEmpty()], validate, async (req, res) => {
  try {
    const { error } = await supabase
      .from('announcement_reads')
      .upsert(
        {
          profile_id: req.user.id,
          announcement_id: req.params.id,
          read_at: new Date().toISOString(),
        },
        { onConflict: 'profile_id,announcement_id', ignoreDuplicates: true }
      );

    if (error) throw error;

    res.json({ success: true, message: 'Marked as read.' });
  } catch (err) {
    logger.error('announcements mark-read error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
