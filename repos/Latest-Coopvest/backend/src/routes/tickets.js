/**
 * Support Ticket Routes (member-facing)
 *
 * Writes to Supabase tables `tickets`, `ticket_messages`, `ticket_attachments`.
 * The admin view lives on /api/v1/support and the cross-backend admin proxy
 * on /api/v1/admin/tickets.
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

const newTicketNumber = () => `TK-${Date.now().toString(36).toUpperCase()}`;

/**
 * POST /api/v1/tickets
 */
router.post(
  '/',
  [
    body('subject').isString().isLength({ min: 3, max: 200 }),
    body('description').isString().isLength({ min: 3, max: 5000 }),
    body('category').optional().isString(),
    body('priority').optional().isIn(['low', 'medium', 'high', 'urgent']),
  ],
  validate,
  async (req, res) => {
    try {
      const { subject, description, category, priority } = req.body;
      const { data: ticket, error } = await supabase
        .from('tickets')
        .insert({
          ticket_number: newTicketNumber(),
          profile_id: req.user.id,
          subject,
          description,
          category: category || 'general',
          priority: priority || 'medium',
          status: 'open',
        })
        .select('*')
        .single();
      if (error) throw error;

      await supabase.from('ticket_messages').insert({
        ticket_id: ticket.id,
        sender_id: req.user.id,
        sender_role: 'member',
        body: description,
      });

      res.status(201).json({ success: true, ticket });
    } catch (err) {
      logger.error('ticket create error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/tickets
 */
router.get('/', async (req, res) => {
  try {
    let q = supabase
      .from('tickets')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (req.query.status) q = q.eq('status', req.query.status);
    const { data, error } = await q;
    if (error) throw error;
    res.json({ success: true, tickets: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/tickets/:id
 */
router.get('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data: ticket, error } = await supabase
      .from('tickets')
      .select('*')
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .maybeSingle();
    if (error) throw error;
    if (!ticket) return res.status(404).json({ success: false, error: 'Ticket not found' });

    const [msgsRes, attsRes] = await Promise.all([
      supabase.from('ticket_messages').select('*').eq('ticket_id', ticket.id).order('created_at', { ascending: true }),
      supabase.from('ticket_attachments').select('*').eq('ticket_id', ticket.id).order('created_at', { ascending: true }),
    ]);
    if (msgsRes.error) throw msgsRes.error;
    if (attsRes.error) throw attsRes.error;

    res.json({
      success: true,
      ticket: { ...ticket, messages: msgsRes.data || [], attachments: attsRes.data || [] },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/tickets/:id/reply
 */
router.post(
  '/:id/reply',
  [param('id').isUUID(), body('body').isString().isLength({ min: 1, max: 5000 })],
  validate,
  async (req, res) => {
    try {
      const { data: ticket, error } = await supabase
        .from('tickets')
        .select('id')
        .eq('id', req.params.id)
        .eq('profile_id', req.user.id)
        .maybeSingle();
      if (error) throw error;
      if (!ticket) return res.status(404).json({ success: false, error: 'Ticket not found' });

      const { data: msg, error: mErr } = await supabase
        .from('ticket_messages')
        .insert({
          ticket_id: ticket.id,
          sender_id: req.user.id,
          sender_role: 'member',
          body: req.body.body,
        })
        .select('*')
        .single();
      if (mErr) throw mErr;

      await supabase.from('tickets').update({ status: 'awaiting_support', last_activity_at: new Date().toISOString() }).eq('id', ticket.id);

      res.status(201).json({ success: true, message: msg });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * PATCH /api/v1/tickets/:id/close
 */
router.patch('/:id/close', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('tickets')
      .update({ status: 'closed', closed_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Ticket not found' });
    res.json({ success: true, ticket: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
