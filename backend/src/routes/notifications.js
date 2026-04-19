/**
 * Notifications Routes
 *
 * CRUD against the Supabase `notifications` table, scoped to the
 * authenticated member (`profile_id`). Admin fan-out lives on
 * /api/v1/admin/notifications.
 */

const express = require('express');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

router.use(authenticate);

function parsePaging(req) {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
  return { page, limit };
}

/**
 * GET /api/v1/notifications
 */
router.get('/', async (req, res) => {
  try {
    const { page, limit } = parsePaging(req);
    let q = supabase
      .from('notifications')
      .select('*', { count: 'exact' })
      .eq('profile_id', req.user.id)
      .eq('archived', false)
      .order('created_at', { ascending: false })
      .range((page - 1) * limit, page * limit - 1);
    if (req.query.type) q = q.eq('type', req.query.type);
    if (req.query.read === 'true') q = q.eq('read', true);
    if (req.query.read === 'false') q = q.eq('read', false);
    const { data, error, count } = await q;
    if (error) throw error;
    res.json({ success: true, notifications: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    logger.error('notif list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/notifications/unread-count
 */
router.get('/unread-count', async (req, res) => {
  try {
    const { count, error } = await supabase
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('profile_id', req.user.id)
      .eq('read', false)
      .eq('archived', false);
    if (error) throw error;
    res.json({ success: true, count: count || 0 });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/notifications/unread
 */
router.get('/unread', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('profile_id', req.user.id)
      .eq('read', false)
      .eq('archived', false)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, notifications: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/notifications/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Notification not found' });
    res.json({ success: true, notification: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PATCH /api/v1/notifications/:id/read
 */
router.patch('/:id/read', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('notifications')
      .update({ read: true, read_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Notification not found' });
    res.json({ success: true, notification: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/notifications/mark-all-read
 */
router.post('/mark-all-read', async (req, res) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ read: true, read_at: new Date().toISOString() })
      .eq('profile_id', req.user.id)
      .eq('read', false);
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PATCH /api/v1/notifications/:id/archive
 */
router.patch('/:id/archive', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('notifications')
      .update({ archived: true })
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Notification not found' });
    res.json({ success: true, notification: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/notifications/archive-all
 */
router.post('/archive-all', async (req, res) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ archived: true })
      .eq('profile_id', req.user.id);
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * DELETE /api/v1/notifications/:id
 */
router.delete('/:id', async (req, res) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .delete()
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id);
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * DELETE /api/v1/notifications
 */
router.delete('/', async (req, res) => {
  try {
    const { error } = await supabase.from('notifications').delete().eq('profile_id', req.user.id);
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
