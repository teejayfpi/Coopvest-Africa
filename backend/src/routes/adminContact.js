/**
 * Website enquiry management (admin-facing) — /api/admin/contact-messages
 *
 * Feeds the dashboard's Website Enquiries page: list, read, assign, reply to
 * and close the enquiries the public /api/contact endpoint stores.
 *
 * A reply is emailed to the enquirer through `services/mailer` and recorded on
 * the row. The two are deliberately decoupled: the email is attempted first and
 * its outcome is reported to the admin, but a transport failure does not lose
 * the reply the admin typed — the body and timestamp are still stored so the
 * thread is not silently blank. The response says whether the email went, so
 * the dashboard can tell the admin to resend rather than implying it was sent.
 *
 * Authorisation comes from the `requirePermission` mount on /api/admin (see
 * ROUTE_PERMISSIONS): reads need `ticket.read`, writes `ticket.write`.
 */

const express = require('express');
const { body, param } = require('express-validator');

const supabase = require('../config/supabase');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');
const mailer = require('../services/mailer');

const router = express.Router();

const STATUSES = ['new', 'in_progress', 'replied', 'closed'];

/** Shape a row for the dashboard (camelCase, flat). */
const serialize = (row) => ({
  id: row.id,
  reference: row.reference,
  name: row.name,
  email: row.email,
  phone: row.phone ?? null,
  topic: row.topic,
  message: row.message,
  source: row.source,
  status: row.status,
  assignedStaffId: row.assigned_staff_id ?? null,
  replyBody: row.reply_body ?? null,
  repliedAt: row.replied_at ?? null,
  repliedBy: row.replied_by ?? null,
  createdAt: row.created_at,
  updatedAt: row.updated_at ?? row.created_at,
});

/**
 * GET /api/admin/contact-messages
 * Filters: status, search (name/email/reference/topic).
 */
router.get('/', async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, parseInt(req.query.limit) || 20);
    const from = (page - 1) * limit;

    let query = supabase
      .from('contact_messages')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, from + limit - 1);

    if (req.query.status) query = query.eq('status', req.query.status);

    if (req.query.search) {
      // Escape PostgREST filter metacharacters so a search for a literal comma
      // or parenthesis cannot break the or() expression.
      const term = String(req.query.search).replace(/[,()]/g, ' ').trim().slice(0, 100);
      if (term) {
        query = query.or(
          `name.ilike.%${term}%,email.ilike.%${term}%,reference.ilike.%${term}%,topic.ilike.%${term}%`,
        );
      }
    }

    const { data, error, count } = await query;
    if (error) throw error;

    res.json({
      success: true,
      data: (data || []).map(serialize),
      pagination: { page, limit, total: count || 0 },
    });
  } catch (err) {
    logger.error('admin contact-messages list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/admin/contact-messages/:id
 */
router.get('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('contact_messages')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Enquiry not found' });
    res.json({ success: true, data: serialize(data) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/admin/contact-messages/:id/reply
 * Body: { body } — the reply text, emailed to the enquirer.
 */
router.post(
  '/:id/reply',
  [param('id').isUUID(), body('body').isString().isLength({ min: 1, max: 5000 })],
  validate,
  async (req, res) => {
    try {
      const { data: enquiry, error } = await supabase
        .from('contact_messages')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (error) throw error;
      if (!enquiry) return res.status(404).json({ success: false, error: 'Enquiry not found' });

      const replyBody = req.body.body.trim();
      const subject = `Re: ${enquiry.topic} (${enquiry.reference})`;
      const text = `Hello ${enquiry.name},\n\n${replyBody}\n\n—\nCoopvest Africa\n\nYour original message:\n${enquiry.message}`;

      const delivery = await mailer.send({
        to: enquiry.email,
        subject,
        text,
        replyTo: process.env.CONTACT_NOTIFY_TO?.split(',')[0]?.trim() || undefined,
      });

      const now = new Date().toISOString();
      const { data: updated, error: upErr } = await supabase
        .from('contact_messages')
        .update({
          reply_body: replyBody,
          replied_at: now,
          replied_by: req.user.id,
          status: 'replied',
          updated_at: now,
        })
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (upErr) throw upErr;

      const note = delivery.sent
        ? 'Reply emailed to the enquirer.'
        : delivery.reason === 'not_configured'
          ? 'Reply saved, but email is not configured on the server, so it was not sent.'
          : 'Reply saved, but the email could not be delivered. Please retry.';

      logger.info(
        `admin contact reply: ref=${enquiry.reference} emailed=${delivery.sent}${delivery.error ? ` err=${delivery.error}` : ''}`,
      );

      res.status(201).json({ success: true, emailed: delivery.sent, message: note, data: serialize(updated) });
    } catch (err) {
      logger.error('admin contact reply error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

/**
 * PATCH /api/admin/contact-messages/:id
 * Body: { status?, assignedTo? }
 */
router.patch(
  '/:id',
  [
    param('id').isUUID(),
    body('status').optional().isIn(STATUSES),
    body('assignedTo').optional({ nullable: true }).isString(),
  ],
  validate,
  async (req, res) => {
    try {
      const update = { updated_at: new Date().toISOString() };
      if (req.body.status !== undefined) update.status = req.body.status;
      if (req.body.assignedTo !== undefined) update.assigned_staff_id = req.body.assignedTo || null;

      const { data, error } = await supabase
        .from('contact_messages')
        .update(update)
        .eq('id', req.params.id)
        .select('*')
        .maybeSingle();
      if (error) throw error;
      if (!data) return res.status(404).json({ success: false, error: 'Enquiry not found' });
      res.json({ success: true, data: serialize(data) });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

module.exports = router;
