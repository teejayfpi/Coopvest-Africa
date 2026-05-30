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
 * GET /api/v1/announcements/unread-count
 * Must be defined before /:id to avoid route collision.
 */
router.get('/unread-count', async (req, res) => {
  try {
    const { count, error } = await supabase
      .from('announcements')
      .select('id', { count: 'exact', head: true })
      .eq('is_active', true)
      .not('id', 'in', (
        supabase
          .from('announcement_reads')
          .select('announcement_id')
          .eq('profile_id', req.user.id)
      ));

    if (error) {
      // Fallback: count all active announcements minus those the user has read
      const { count: total } = await supabase
        .from('announcements')
        .select('id', { count: 'exact', head: true })
        .eq('is_active', true);

      const { count: read } = await supabase
        .from('announcement_reads')
        .select('id', { count: 'exact', head: true })
        .eq('profile_id', req.user.id);

      return res.json({ success: true, count: Math.max(0, (total || 0) - (read || 0)) });
    }

    res.json({ success: true, count: count || 0 });
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
    const { data: announcements } = await supabase
      .from('announcements')
      .select('id')
      .eq('is_active', true);

    if (announcements && announcements.length > 0) {
      const { data: alreadyRead } = await supabase
        .from('announcement_reads')
        .select('announcement_id')
        .eq('profile_id', req.user.id);

      const readSet = new Set((alreadyRead || []).map((r) => r.announcement_id));
      const toInsert = announcements
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

      let q = supabase
        .from('announcements')
        .select('*, reads:announcement_reads(id)', { count: 'exact' })
        .eq('is_active', true)
        .order('created_at', { ascending: false })
        .range((page - 1) * limit, page * limit - 1);

      const { data, error, count } = await q;
      if (error) throw error;

      const { data: myReads } = await supabase
        .from('announcement_reads')
        .select('announcement_id')
        .eq('profile_id', req.user.id);

      const readSet = new Set((myReads || []).map((r) => r.announcement_id));

      let announcements = (data || []).map((a) => ({
        ...a,
        reads: undefined,
        isRead: readSet.has(a.id),
      }));

      if (unreadOnly) {
        announcements = announcements.filter((a) => !a.isRead);
      }

      res.json({
        success: true,
        announcements,
        total: count || 0,
        page,
        limit,
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

    const { data: readRow } = await supabase
      .from('announcement_reads')
      .select('id')
      .eq('profile_id', req.user.id)
      .eq('announcement_id', data.id)
      .maybeSingle();

    res.json({ success: true, ...data, isRead: !!readRow });
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
