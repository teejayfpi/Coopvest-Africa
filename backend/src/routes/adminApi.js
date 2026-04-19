/**
 * Cross-backend Admin API (service-token auth)
 *
 * These endpoints are consumed by the Admin Dashboard's own API server, not
 * by a Supabase-authenticated member. They trust a shared secret header
 * (`X-Service-Token`) validated by the `requireService` middleware.
 *
 * Responses are intentionally flat and stable so the admin HTTP client
 * can consume them without reshaping.
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { requireService } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(requireService);

function paging(req) {
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 50));
  return { page, limit, from: (page - 1) * limit, to: page * limit - 1 };
}

async function logAdminAction(action, target, metadata = {}) {
  try {
    await supabase.from('audit_logs').insert({
      actor_id: null,
      action,
      target_model: target?.model || null,
      target_id: target?.id || null,
      metadata: { ...metadata, source: 'admin-web' },
    });
  } catch (err) {
    logger.warn('audit_logs insert failed:', err.message);
  }
}

/**
 * GET /api/v1/admin/members
 */
router.get('/members', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    let q = supabase
      .from('profiles')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);
    if (req.query.q) q = q.or(`name.ilike.%${req.query.q}%,email.ilike.%${req.query.q}%,user_id.ilike.%${req.query.q}%`);
    if (req.query.role) q = q.eq('role', req.query.role);
    if (req.query.isFlagged === 'true') q = q.eq('is_flagged', true);
    if (req.query.isActive === 'false') q = q.eq('is_active', false);
    const { data, error, count } = await q;
    if (error) throw error;
    res.json({ success: true, members: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    logger.error('admin members list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/members/:id
 */
router.get('/members/:id', async (req, res) => {
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!profile) return res.status(404).json({ success: false, error: 'Member not found' });

    const [wallet, savings, kyc, loans, tickets] = await Promise.all([
      supabase.from('wallets').select('*').eq('profile_id', profile.id).maybeSingle(),
      supabase.from('savings').select('*').eq('profile_id', profile.id).maybeSingle(),
      supabase.from('kyc').select('*').eq('profile_id', profile.id).maybeSingle(),
      supabase.from('loans').select('*').eq('profile_id', profile.id).order('created_at', { ascending: false }),
      supabase.from('tickets').select('*').eq('profile_id', profile.id).order('created_at', { ascending: false }),
    ]);
    res.json({
      success: true,
      member: {
        ...profile,
        wallet: wallet.data || null,
        savings: savings.data || null,
        kyc: kyc.data || null,
        loans: loans.data || [],
        tickets: tickets.data || [],
      },
    });
  } catch (err) {
    logger.error('admin member detail error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PATCH /api/v1/admin/members/:id
 */
router.patch(
  '/members/:id',
  [
    body('isActive').optional().isBoolean(),
    body('isFlagged').optional().isBoolean(),
    body('role').optional().isIn(['member', 'admin']),
  ],
  validate,
  async (req, res) => {
    try {
      const update = {};
      if (req.body.isActive !== undefined) update.is_active = !!req.body.isActive;
      if (req.body.isFlagged !== undefined) update.is_flagged = !!req.body.isFlagged;
      if (req.body.role !== undefined) update.role = req.body.role;
      if (Object.keys(update).length === 0) {
        return res.status(400).json({ success: false, error: 'No fields to update' });
      }
      const { data, error } = await supabase
        .from('profiles')
        .update(update)
        .eq('id', req.params.id)
        .select('*')
        .maybeSingle();
      if (error) throw error;
      if (!data) return res.status(404).json({ success: false, error: 'Member not found' });
      await logAdminAction('MEMBER_UPDATED', { model: 'Profile', id: data.id }, update);
      res.json({ success: true, member: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/admin/loans
 */
router.get('/loans', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    let q = supabase
      .from('loans')
      .select('*, profile:profiles(id, user_id, name, email)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);
    if (req.query.status) q = q.eq('status', req.query.status);
    if (req.query.loanType) q = q.eq('loan_type', req.query.loanType);
    if (req.query.profileId) q = q.eq('profile_id', req.query.profileId);
    const { data, error, count } = await q;
    if (error) throw error;
    res.json({ success: true, loans: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/admin/loans/:id/decision
 */
router.post(
  '/loans/:id/decision',
  [
    body('decision').isIn(['approve', 'reject']),
    body('reason').optional().isString().isLength({ max: 1000 }),
  ],
  validate,
  async (req, res) => {
    try {
      const status = req.body.decision === 'approve' ? 'approved' : 'rejected';
      const update = {
        status,
        decided_at: new Date().toISOString(),
        decision_reason: req.body.reason || null,
      };
      const { data, error } = await supabase
        .from('loans')
        .update(update)
        .eq('id', req.params.id)
        .select('*')
        .maybeSingle();
      if (error) throw error;
      if (!data) return res.status(404).json({ success: false, error: 'Loan not found' });
      await logAdminAction(`LOAN_${status.toUpperCase()}`, { model: 'Loan', id: data.id }, { reason: req.body.reason });
      res.json({ success: true, loan: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/admin/wallets
 */
router.get('/wallets', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    const { data, error, count } = await supabase
      .from('wallets')
      .select('*, profile:profiles(id, user_id, name, email)', { count: 'exact' })
      .order('updated_at', { ascending: false })
      .range(from, to);
    if (error) throw error;
    res.json({ success: true, wallets: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/transactions
 */
router.get('/transactions', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    let q = supabase
      .from('transactions')
      .select('*, profile:profiles(id, user_id, name, email)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);
    if (req.query.type) q = q.eq('type', req.query.type);
    if (req.query.profileId) q = q.eq('profile_id', req.query.profileId);
    if (req.query.status) q = q.eq('status', req.query.status);
    const { data, error, count } = await q;
    if (error) throw error;
    res.json({ success: true, transactions: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/savings
 */
router.get('/savings', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    const { data, error, count } = await supabase
      .from('savings')
      .select('*, profile:profiles(id, user_id, name, email)', { count: 'exact' })
      .order('updated_at', { ascending: false })
      .range(from, to);
    if (error) throw error;
    res.json({ success: true, savings: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/tickets
 */
router.get('/tickets', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    let q = supabase
      .from('tickets')
      .select('*, profile:profiles(id, user_id, name, email)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);
    if (req.query.status) q = q.eq('status', req.query.status);
    if (req.query.priority) q = q.eq('priority', req.query.priority);
    const { data, error, count } = await q;
    if (error) throw error;
    res.json({ success: true, tickets: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/tickets/:id
 */
router.get('/tickets/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data: ticket, error } = await supabase
      .from('tickets')
      .select('*, profile:profiles(id, user_id, name, email)')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!ticket) return res.status(404).json({ success: false, error: 'Ticket not found' });

    const [msgs, atts] = await Promise.all([
      supabase.from('ticket_messages').select('*').eq('ticket_id', ticket.id).order('created_at', { ascending: true }),
      supabase.from('ticket_attachments').select('*').eq('ticket_id', ticket.id),
    ]);
    res.json({ success: true, ticket: { ...ticket, messages: msgs.data || [], attachments: atts.data || [] } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/audit-logs
 */
router.get('/audit-logs', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    let q = supabase
      .from('audit_logs')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);
    if (req.query.action) q = q.eq('action', req.query.action);
    if (req.query.targetModel) q = q.eq('target_model', req.query.targetModel);
    if (req.query.actorId) q = q.eq('actor_id', req.query.actorId);
    const { data, error, count } = await q;
    if (error) throw error;
    res.json({ success: true, logs: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/notifications
 */
router.get('/notifications', async (req, res) => {
  try {
    const { page, limit, from, to } = paging(req);
    const { data, error, count } = await supabase
      .from('notifications')
      .select('*, profile:profiles(id, user_id, name, email)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);
    if (error) throw error;
    res.json({ success: true, notifications: data || [], pagination: { page, limit, total: count || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/admin/notifications/broadcast
 */
router.post(
  '/notifications/broadcast',
  [body('title').isString(), body('message').isString(), body('type').optional().isString()],
  validate,
  async (req, res) => {
    try {
      const { title, message, type, profileIds } = req.body;
      let targetIds = profileIds;
      if (!Array.isArray(targetIds) || targetIds.length === 0) {
        const { data } = await supabase.from('profiles').select('id').eq('is_active', true);
        targetIds = (data || []).map((p) => p.id);
      }
      if (targetIds.length === 0) return res.json({ success: true, sent: 0 });

      const rows = targetIds.map((pid) => ({
        profile_id: pid,
        title,
        body: message,
        type: type || 'announcement',
        read: false,
        archived: false,
      }));
      const { error } = await supabase.from('notifications').insert(rows);
      if (error) throw error;
      await logAdminAction('NOTIFICATION_BROADCAST', { model: 'Notification' }, { count: rows.length, title });
      res.status(201).json({ success: true, sent: rows.length });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/admin/overview
 */
router.get('/overview', async (req, res) => {
  try {
    const [members, activeMembers, loans, openTickets] = await Promise.all([
      supabase.from('profiles').select('id', { count: 'exact', head: true }),
      supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('is_active', true),
      supabase.from('loans').select('status, amount'),
      supabase.from('tickets').select('id', { count: 'exact', head: true }).eq('status', 'open'),
    ]);

    const loansList = loans.data || [];
    const loansTotals = loansList.reduce(
      (acc, l) => {
        acc.total += Number(l.amount || 0);
        acc.byStatus[l.status] = (acc.byStatus[l.status] || 0) + 1;
        return acc;
      },
      { total: 0, byStatus: {} }
    );

    res.json({
      success: true,
      overview: {
        members: { total: members.count || 0, active: activeMembers.count || 0 },
        loans: { count: loansList.length, ...loansTotals },
        tickets: { open: openTickets.count || 0 },
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
