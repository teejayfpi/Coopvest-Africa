/**
 * Admin announcement management.
 *
 * The existing member-facing routes (routes/announcements.js) only ever *read*
 * announcements; nothing could write one. The admin dashboard's "Announcement
 * Editor" saved to React state and showed a success toast, so no announcement
 * has ever reached a device.
 *
 * These endpoints provide the write side:
 *
 *   GET    /announcements               — list (admin view, includes inactive)
 *   POST   /announcements               — create / publish
 *   PATCH  /announcements/:id           — edit
 *   DELETE /announcements/:id           — remove
 *   POST   /announcements/:id/toggle    — activate / deactivate
 *   GET    /announcements/:id/audience  — who it will reach, before sending
 *   GET    /announcements/targets/members — picker source for targeting
 *
 * Mounted under /api/admin. `requirePermission` maps these paths to
 * notification.send / notification.read (see middleware/requirePermission.js).
 *
 * Response shape: rows are returned in the shape the Flutter `Announcement`
 * model reads (camelCase `content`, `type`, `isRead`, `isPinned`, ISO dates).
 * The model reads `content`/`type` while the table stores `body`/`category`, so
 * returning the raw row would render a blank announcement — the field names are
 * translated here rather than pushing that mismatch onto the client.
 */

const express = require('express');
const { Router } = express;
const { body, param, validationResult } = require('express-validator');

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');

const router = Router();

const DISPLAY_MODES = ['banner', 'popup', 'marquee', 'all'];
const AUDIENCES = ['all', 'specific', 'organization'];
const PRIORITIES = ['low', 'normal', 'high', 'critical'];

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ success: false, error: errors.array()[0].msg });
    return;
  }
  next();
}

async function audit(action, target, metadata, req) {
  try {
    await supabase.from('audit_logs').insert({
      actor_id: req?.user?.id || null,
      actor_role: req?.user?.role || null,
      action,
      target_model: target?.model || null,
      target_id: target?.id || null,
      metadata: { ...metadata, source: 'admin-web' },
      ip_address: req?.ip || null,
      user_agent: req?.headers?.['user-agent'] || null,
    });
  } catch (err) {
    logger.warn('announcements audit insert failed:', err.message);
  }
}

/** Serialise a row into the shape the Flutter model expects. */
function toClient(row, { isRead = false } = {}) {
  return {
    id: row.id,
    title: row.title || '',
    // The client model reads `content`; the table column is `body`.
    content: row.body || '',
    body: row.body || '',
    // …and `type` where the table has `category`.
    type: row.category || 'general',
    category: row.category || 'info',
    displayMode: row.display_mode || 'banner',
    audience: row.audience || 'all',
    priority: row.priority || 'normal',
    isPinned: Boolean(row.is_pinned),
    dismissible: row.dismissible !== false,
    actionLabel: row.action_label || null,
    actionUrl: row.action_url || null,
    linkUrl: row.link_url || null,
    isActive: row.is_active !== false,
    createdAt: row.created_at || row.published_at,
    publishedAt: row.published_at || row.created_at,
    expiresAt: row.expires_at,
    updatedAt: row.updated_at,
    isRead,
    targetProfileIds: row.target_profile_ids || [],
    targetOrganizationId: row.target_organization_id || null,
  };
}

/** Resolve which profile ids an audience selection reaches. */
async function resolveAudience({ audience, targetProfileIds, targetOrganizationId }) {
  if (audience === 'specific') {
    return [...new Set(targetProfileIds || [])];
  }
  if (audience === 'organization') {
    const { data, error } = await supabase
      .from('profiles')
      .select('id')
      .eq('organization_id', targetOrganizationId)
      .eq('is_active', true);
    if (error) throw error;
    return (data || []).map((p) => p.id);
  }
  const { data, error } = await supabase
    .from('profiles')
    .select('id')
    .eq('is_active', true);
  if (error) throw error;
  return (data || []).map((p) => p.id);
}

// ── GET /announcements/targets/members ───────────────────────────────────────
// Declared before /:id so it is not consumed as an id.
router.get('/targets/members', async (req, res) => {
  try {
    const limit = Math.min(500, Number(req.query.limit) || 200);
    const search = String(req.query.search || '').trim();

    let q = supabase
      .from('profiles')
      .select('id, user_id, name, full_name, email, phone, organization_id, is_active')
      .eq('is_active', true)
      .order('name', { ascending: true })
      .limit(limit);

    if (search) {
      // Match name or email. `or` keeps it a single round trip.
      q = q.or(`name.ilike.%${search}%,email.ilike.%${search}%,user_id.ilike.%${search}%`);
    }

    const { data, error } = await q;
    if (error) throw error;

    res.json({
      success: true,
      members: (data || []).map((p) => ({
        profileId: p.id,
        memberId: p.user_id || '',
        name: p.name || p.full_name || p.email || '',
        email: p.email || '',
        phone: p.phone || '',
        organizationId: p.organization_id || null,
      })),
    });
  } catch (err) {
    logger.error('announcement targets error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /announcements ───────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(200, Number(req.query.limit) || 50);
    const from = (page - 1) * limit;

    let q = supabase
      .from('announcements')
      .select('*', { count: 'exact' })
      // Pinned first, then newest — matching how the app should present them.
      .order('is_pinned', { ascending: false })
      .order('created_at', { ascending: false })
      .range(from, from + limit - 1);

    if (req.query.activeOnly === 'true') q = q.eq('is_active', true);
    if (req.query.displayMode) q = q.eq('display_mode', req.query.displayMode);

    const { data, error, count } = await q;
    if (error) throw error;

    // Read counts per announcement, so the admin can see actual engagement.
    const ids = (data || []).map((a) => a.id);
    const readCounts = new Map();
    if (ids.length > 0) {
      const { data: reads } = await supabase
        .from('announcement_reads')
        .select('announcement_id')
        .in('announcement_id', ids);
      for (const r of reads || []) {
        readCounts.set(r.announcement_id, (readCounts.get(r.announcement_id) || 0) + 1);
      }
    }

    const { count: memberCount } = await supabase
      .from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('is_active', true);

    res.json({
      success: true,
      announcements: (data || []).map((row) => ({
        ...toClient(row),
        readCount: readCounts.get(row.id) || 0,
        targetCount: row.audience === 'all'
          ? memberCount || 0
          : (row.target_profile_ids || []).length || null,
      })),
      total: count || 0,
      page,
      limit,
      activeMembers: memberCount || 0,
    });
  } catch (err) {
    logger.error('announcements admin list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /announcements/:id/audience ──────────────────────────────────────────
// "Who will this reach?" — checked before sending, so a mis-targeted
// announcement is caught at compose time rather than after the fact.
router.get(
  '/:id/audience',
  [param('id').isUUID().withMessage('id must be a valid announcement id')],
  validate,
  async (req, res) => {
    try {
      const { data: row, error } = await supabase
        .from('announcements')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (error) throw error;
      if (!row) {
        res.status(404).json({ success: false, error: 'Announcement not found' });
        return;
      }

      const ids = await resolveAudience({
        audience: row.audience,
        targetProfileIds: row.target_profile_ids,
        targetOrganizationId: row.target_organization_id,
      });

      const { data: reads } = await supabase
        .from('announcement_reads')
        .select('profile_id')
        .eq('announcement_id', row.id);
      const readSet = new Set((reads || []).map((r) => r.profile_id));

      res.json({
        success: true,
        audience: row.audience,
        targetCount: ids.length,
        readCount: readSet.size,
        unreadCount: Math.max(0, ids.length - readSet.size),
        members: ids.slice(0, 500).map((id) => ({ profileId: id, isRead: readSet.has(id) })),
      });
    } catch (err) {
      logger.error('announcement audience error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── POST /announcements ──────────────────────────────────────────────────────
/**
 * Publish an announcement.
 *
 * `notifyMembers` (default true) also dispatches a push, so a popup or marquee
 * announcement reaches a member who does not have the app open. Without it the
 * "pop up" only appears next time they launch, which is rarely what an admin
 * means by "send it now".
 */
router.post(
  '/',
  [
    body('title').isString().trim().notEmpty().withMessage('title is required'),
    body('body').isString().trim().notEmpty().withMessage('body is required'),
    body('displayMode').optional().isIn(DISPLAY_MODES).withMessage(`displayMode must be one of ${DISPLAY_MODES.join(', ')}`),
    body('audience').optional().isIn(AUDIENCES).withMessage(`audience must be one of ${AUDIENCES.join(', ')}`),
    body('priority').optional().isIn(PRIORITIES).withMessage(`priority must be one of ${PRIORITIES.join(', ')}`),
    body('expiresAt').optional().isISO8601().withMessage('expiresAt must be an ISO date'),
    body('publishedAt').optional().isISO8601().withMessage('publishedAt must be an ISO date'),
  ],
  validate,
  async (req, res) => {
    try {
      const {
        title, body: textBody, category = 'info', displayMode = 'banner',
        audience = 'all', priority = 'normal', isPinned = false,
        dismissible = true, actionLabel = null, actionUrl = null,
        linkUrl = null, expiresAt = null, publishedAt = null,
        targetProfileIds = [], targetOrganizationId = null,
        isActive = true, notifyMembers = true,
      } = req.body;

      // Guard the targeting combination at the API edge too, so the caller gets
      // a clear message instead of a raw constraint violation (23514).
      if (audience === 'specific' && (!Array.isArray(targetProfileIds) || targetProfileIds.length === 0)) {
        res.status(400).json({ success: false, error: 'targetProfileIds is required when audience is "specific"' });
        return;
      }
      if (audience === 'organization' && !targetOrganizationId) {
        res.status(400).json({ success: false, error: 'targetOrganizationId is required when audience is "organization"' });
        return;
      }

      const now = new Date().toISOString();
      const { data: row, error } = await supabase
        .from('announcements')
        .insert({
          title: String(title).trim(),
          body: String(textBody).trim(),
          category,
          display_mode: displayMode,
          audience,
          priority,
          is_pinned: Boolean(isPinned),
          dismissible: dismissible !== false,
          action_label: actionLabel,
          action_url: actionUrl,
          link_url: linkUrl,
          expires_at: expiresAt,
          published_at: publishedAt || now,
          is_active: isActive !== false,
          target_profile_ids: audience === 'specific' ? [...new Set(targetProfileIds)] : null,
          target_organization_id: audience === 'organization' ? targetOrganizationId : null,
          published_by: req.user?.id || null,
          updated_at: now,
        })
        .select('*')
        .single();
      if (error) throw error;

      // Push, so a popup/marquee reaches members who are not in the app.
      let push = { targeted: 0, errors: 0, status: 'skipped', reason: 'not_requested' };
      if (notifyMembers) {
        const ids = await resolveAudience({
          audience, targetProfileIds, targetOrganizationId,
        });
        if (ids.length > 0) {
          const { data: tokens } = await supabase
            .from('device_tokens')
            .select('token')
            .eq('active', true)
            .in('profile_id', ids);
          if (tokens && tokens.length > 0) {
            const result = await notifyService.sendPush({
              tokens: tokens.map((t) => t.token),
              title,
              body: textBody,
              type: 'announcement',
              data: { type: 'announcement', announcementId: row.id, displayMode },
            });
            push = {
              targeted: tokens.length,
              errors: Number.isFinite(result.failureCount) ? result.failureCount : 0,
              status: result.status,
              reason: result.reason || null,
            };
          }
        }
      }

      await audit('ANNOUNCEMENT_PUBLISHED', { model: 'Announcement', id: row.id }, {
        title, displayMode, audience, priority, push,
      }, req);

      res.status(201).json({ success: true, announcement: toClient(row), push });
    } catch (err) {
      logger.error('announcement create error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── PATCH /announcements/:id ─────────────────────────────────────────────────
router.patch(
  '/:id',
  [param('id').isUUID().withMessage('id must be a valid announcement id')],
  validate,
  async (req, res) => {
    try {
      const { data: before } = await supabase
        .from('announcements').select('*').eq('id', req.params.id).maybeSingle();
      if (!before) {
        res.status(404).json({ success: false, error: 'Announcement not found' });
        return;
      }

      const {
        title, body: textBody, category, displayMode, audience, priority,
        isPinned, dismissible, actionLabel, actionUrl, linkUrl,
        expiresAt, publishedAt, isActive, targetProfileIds, targetOrganizationId,
      } = req.body;

      const updates = { updated_at: new Date().toISOString() };
      if (title !== undefined) updates.title = title;
      if (textBody !== undefined) updates.body = textBody;
      if (category !== undefined) updates.category = category;
      if (displayMode !== undefined) updates.display_mode = displayMode;
      if (audience !== undefined) updates.audience = audience;
      if (priority !== undefined) updates.priority = priority;
      if (isPinned !== undefined) updates.is_pinned = Boolean(isPinned);
      if (dismissible !== undefined) updates.dismissible = dismissible !== false;
      if (actionLabel !== undefined) updates.action_label = actionLabel;
      if (actionUrl !== undefined) updates.action_url = actionUrl;
      if (linkUrl !== undefined) updates.link_url = linkUrl;
      if (expiresAt !== undefined) updates.expires_at = expiresAt;
      if (publishedAt !== undefined) updates.published_at = publishedAt;
      if (isActive !== undefined) updates.is_active = isActive !== false;
      if (targetProfileIds !== undefined) updates.target_profile_ids = audience === 'all' ? null : targetProfileIds;
      if (targetOrganizationId !== undefined) updates.target_organization_id = targetOrganizationId;

      const { data: row, error } = await supabase
        .from('announcements')
        .update(updates)
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) throw error;

      await audit('ANNOUNCEMENT_UPDATED', { model: 'Announcement', id: row.id }, {
        changed: Object.keys(updates).filter((k) => k !== 'updated_at'),
        previous: { title: before.title, display_mode: before.display_mode, audience: before.audience, is_active: before.is_active },
      }, req);

      res.json({ success: true, announcement: toClient(row) });
    } catch (err) {
      logger.error('announcement update error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── POST /announcements/:id/toggle ───────────────────────────────────────────
router.post(
  '/:id/toggle',
  [param('id').isUUID().withMessage('id must be a valid announcement id')],
  validate,
  async (req, res) => {
    try {
      const { data: before } = await supabase
        .from('announcements').select('is_active, title').eq('id', req.params.id).maybeSingle();
      if (!before) {
        res.status(404).json({ success: false, error: 'Announcement not found' });
        return;
      }
      const next = req.body?.isActive !== undefined ? Boolean(req.body.isActive) : !before.is_active;

      const { data: row, error } = await supabase
        .from('announcements')
        .update({ is_active: next, updated_at: new Date().toISOString() })
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) throw error;

      await audit(next ? 'ANNOUNCEMENT_ACTIVATED' : 'ANNOUNCEMENT_DEACTIVATED',
        { model: 'Announcement', id: row.id }, { title: before.title, isActive: next }, req);

      res.json({ success: true, announcement: toClient(row) });
    } catch (err) {
      logger.error('announcement toggle error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── DELETE /announcements/:id ────────────────────────────────────────────────
router.delete(
  '/:id',
  [param('id').isUUID().withMessage('id must be a valid announcement id')],
  validate,
  async (req, res) => {
    try {
      const { data: before } = await supabase
        .from('announcements').select('title').eq('id', req.params.id).maybeSingle();

      // Read receipts are children; clear them so the delete cannot be blocked
      // by a foreign key.
      await supabase.from('announcement_reads').delete().eq('announcement_id', req.params.id);

      const { error } = await supabase.from('announcements').delete().eq('id', req.params.id);
      if (error) throw error;

      await audit('ANNOUNCEMENT_DELETED', { model: 'Announcement', id: req.params.id },
        { title: before?.title || null }, req);

      res.json({ success: true, deleted: req.params.id });
    } catch (err) {
      logger.error('announcement delete error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

module.exports = router;
