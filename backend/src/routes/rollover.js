/**
 * Rollover Routes
 *
 * A rollover extends the tenure of an active loan. Rollover requests are
 * persisted in Supabase `rollovers` and link back to the source loan.
 *
 * Flow:
 *   POST   /                              — member creates rollover request
 *   GET    /                              — member lists their rollovers
 *   GET    /:id                           — get single rollover (member or guarantor)
 *   DELETE /:id                           — member cancels while still pending
 *   GET    /:id/guarantors                — list guarantors for a rollover
 *   POST   /:id/guarantors               — add guarantor to rollover
 *   PATCH  /:id/guarantors/:gid/respond  — guarantor accepts or declines
 *   PATCH  /:id/guarantors/:gid/replace  — borrower replaces a declined guarantor
 *   GET    /:id/eligibility              — check if loan qualifies for rollover
 *   PATCH  /:id/approve                  — admin approves rollover
 *   PATCH  /:id/reject                   — admin rejects rollover
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Fetch a rollover row; returns null if not found. */
async function findRollover(id, profileId = null) {
  let query = supabase.from('rollovers').select('*').eq('id', id);
  if (profileId) query = query.eq('profile_id', profileId);
  const { data, error } = await query.maybeSingle();
  if (error) throw error;
  return data;
}

/** Fetch a rollover_guarantor row. */
async function findGuarantor(rolloverId, guarantorId) {
  const { data, error } = await supabase
    .from('rollover_guarantors')
    .select('*')
    .eq('rollover_id', rolloverId)
    .eq('id', guarantorId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/** Check whether all guarantors for a rollover have accepted. */
async function allGuarantorsAccepted(rolloverId) {
  const { data, error } = await supabase
    .from('rollover_guarantors')
    .select('status')
    .eq('rollover_id', rolloverId);
  if (error) throw error;
  if (!data || data.length === 0) return false;
  return data.every(g => g.status === 'accepted');
}

// ── POST / — create rollover request ─────────────────────────────────────────

router.post(
  '/',
  [
    body('loanId').isString().notEmpty(),
    body('extensionMonths').isInt({ min: 1, max: 12 }),
    body('guarantors').isArray({ min: 1, max: 3 }).optional(),
    body('reason').isString().optional(),
  ],
  validate,
  async (req, res) => {
    try {
      const { loanId, extensionMonths, reason, guarantors = [] } = req.body;

      const { data: loan, error: lErr } = await supabase
        .from('loans')
        .select('*')
        .eq('loan_id', loanId)
        .eq('profile_id', req.user.id)
        .maybeSingle();
      if (lErr) throw lErr;
      if (!loan) return res.status(404).json({ success: false, error: 'Loan not found' });

      if (loan.status !== 'active') {
        return res.status(400).json({ success: false, error: 'Only active loans can be rolled over' });
      }

      // Prevent duplicate pending rollover
      const { data: existing } = await supabase
        .from('rollovers')
        .select('id')
        .eq('loan_id', loan.id)
        .eq('status', 'pending')
        .maybeSingle();
      if (existing) {
        return res.status(409).json({ success: false, error: 'A pending rollover request already exists for this loan' });
      }

      const { data: rollover, error: rErr } = await supabase
        .from('rollovers')
        .insert({
          loan_id: loan.id,
          profile_id: req.user.id,
          extension_months: extensionMonths,
          reason: reason || null,
          status: 'pending',
          guarantor_consent_deadline: new Date(
            Date.now() + 7 * 24 * 60 * 60 * 1000,
          ).toISOString(), // 7 days
        })
        .select('*')
        .single();
      if (rErr) throw rErr;

      // Insert guarantors if provided
      if (guarantors.length > 0) {
        const guarantorRows = guarantors.map(g => ({
          rollover_id: rollover.id,
          guarantor_id: g.guarantorId,
          guarantor_name: g.guarantorName,
          guarantor_phone: g.guarantorPhone,
          status: 'invited',
          invited_at: new Date().toISOString(),
        }));
        const { error: gErr } = await supabase
          .from('rollover_guarantors')
          .insert(guarantorRows);
        if (gErr) throw gErr;
      }

      logger.info(`Rollover created: ${rollover.id} for loan ${loanId}`);
      res.status(201).json({ success: true, rollover });
    } catch (err) {
      logger.error('rollover create error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// ── GET / — list member's rollovers ──────────────────────────────────────────

router.get('/', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('rollovers')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, rollovers: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /:id — single rollover ────────────────────────────────────────────────

router.get('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    // Allow both the borrower and any guarantor to fetch rollover details
    const { data, error } = await supabase
      .from('rollovers')
      .select('*, rollover_guarantors(*)')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Rollover not found' });

    // Check the requester is either the borrower or a guarantor
    const isOwner = data.profile_id === req.user.id;
    const isGuarantor = (data.rollover_guarantors || []).some(
      g => g.guarantor_id === req.user.id,
    );
    if (!isOwner && !isGuarantor) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    res.json({ success: true, rollover: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── DELETE /:id — cancel rollover ─────────────────────────────────────────────

router.delete('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const existing = await findRollover(req.params.id, req.user.id);
    if (!existing) return res.status(404).json({ success: false, error: 'Rollover not found' });
    if (existing.status !== 'pending') {
      return res.status(400).json({ success: false, error: 'Only pending rollovers can be cancelled' });
    }

    const { data, error } = await supabase
      .from('rollovers')
      .update({ status: 'cancelled', cancelled_at: new Date().toISOString() })
      .eq('id', existing.id)
      .select('*')
      .single();
    if (error) throw error;

    res.json({ success: true, rollover: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /:id/eligibility — check loan eligibility ─────────────────────────────

router.get(
  '/:id/eligibility',
  [param('id').isString().notEmpty()],
  validate,
  async (req, res) => {
    try {
      // :id here is the loan_id (string), not rollover uuid
      const { data: loan, error: lErr } = await supabase
        .from('loans')
        .select('*')
        .eq('loan_id', req.params.id)
        .eq('profile_id', req.user.id)
        .maybeSingle();
      if (lErr) throw lErr;
      if (!loan) return res.status(404).json({ success: false, error: 'Loan not found' });

      const repaymentPercentage =
        loan.total_repaid && loan.amount
          ? (loan.total_repaid / loan.amount) * 100
          : 0;
      const hasMinimum50 = repaymentPercentage >= 50;

      // Check consistent savings (3+ months contributions)
      const threeMonthsAgo = new Date();
      threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
      const { count: savingsCount } = await supabase
        .from('contributions')
        .select('*', { count: 'exact', head: true })
        .eq('profile_id', req.user.id)
        .gte('created_at', threeMonthsAgo.toISOString());

      const hasConsistentSavings = (savingsCount || 0) >= 3;
      const isEligible = hasMinimum50 && hasConsistentSavings;

      const errors = [];
      if (!hasMinimum50) errors.push(`Minimum 50% repayment required (current: ${repaymentPercentage.toFixed(1)}%)`);
      if (!hasConsistentSavings) errors.push('Minimum 3 months of consistent savings required');

      res.json({
        success: true,
        eligibility: {
          status: isEligible ? 'eligible' : 'ineligible',
          is_eligible: isEligible,
          has_minimum_50_percent_repayment: hasMinimum50,
          has_consistent_savings: hasConsistentSavings,
          repayment_percentage: repaymentPercentage,
          consecutive_savings_months: savingsCount || 0,
          eligibility_errors: errors,
          eligibility_warnings: [],
        },
      });
    } catch (err) {
      logger.error('eligibility check error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// ── GET /:id/guarantors ───────────────────────────────────────────────────────

router.get('/:id/guarantors', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const rollover = await findRollover(req.params.id, req.user.id);
    if (!rollover) return res.status(404).json({ success: false, error: 'Rollover not found' });

    const { data, error } = await supabase
      .from('rollover_guarantors')
      .select('*')
      .eq('rollover_id', req.params.id)
      .order('created_at', { ascending: true });
    if (error) throw error;

    res.json({ success: true, guarantors: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── POST /:id/guarantors — add guarantor ──────────────────────────────────────

router.post(
  '/:id/guarantors',
  [
    param('id').isUUID(),
    body('guarantorId').isString().notEmpty(),
    body('guarantorName').isString().notEmpty(),
    body('guarantorPhone').isString().notEmpty(),
  ],
  validate,
  async (req, res) => {
    try {
      const rollover = await findRollover(req.params.id, req.user.id);
      if (!rollover) return res.status(404).json({ success: false, error: 'Rollover not found' });
      if (rollover.status !== 'pending') {
        return res.status(400).json({ success: false, error: 'Cannot add guarantors to a non-pending rollover' });
      }

      // Max 3 guarantors
      const { count } = await supabase
        .from('rollover_guarantors')
        .select('*', { count: 'exact', head: true })
        .eq('rollover_id', req.params.id)
        .neq('status', 'declined');
      if ((count || 0) >= 3) {
        return res.status(400).json({ success: false, error: 'Maximum 3 guarantors allowed' });
      }

      const { data, error } = await supabase
        .from('rollover_guarantors')
        .insert({
          rollover_id: req.params.id,
          guarantor_id: req.body.guarantorId,
          guarantor_name: req.body.guarantorName,
          guarantor_phone: req.body.guarantorPhone,
          status: 'invited',
          invited_at: new Date().toISOString(),
        })
        .select('*')
        .single();
      if (error) throw error;

      res.status(201).json({ success: true, guarantor: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// ── PATCH /:id/guarantors/:gid/respond — guarantor accepts or declines ────────

router.patch(
  '/:id/guarantors/:gid/respond',
  [
    param('id').isUUID(),
    param('gid').isUUID(),
    body('accepted').isBoolean(),
    body('reason').isString().optional(),
  ],
  validate,
  async (req, res) => {
    try {
      const rollover = await findRollover(req.params.id);
      if (!rollover) return res.status(404).json({ success: false, error: 'Rollover not found' });
      if (rollover.status !== 'pending') {
        return res.status(400).json({ success: false, error: 'This rollover is no longer accepting responses' });
      }

      const guarantor = await findGuarantor(req.params.id, req.params.gid);
      if (!guarantor) return res.status(404).json({ success: false, error: 'Guarantor not found' });

      // Verify the authenticated user is the guarantor
      if (guarantor.guarantor_id !== req.user.id) {
        return res.status(403).json({ success: false, error: 'You are not the assigned guarantor for this entry' });
      }

      if (guarantor.status === 'accepted' || guarantor.status === 'declined') {
        return res.status(400).json({ success: false, error: 'You have already responded to this request' });
      }

      const { accepted, reason } = req.body;
      const newStatus = accepted ? 'accepted' : 'declined';

      const { data: updated, error: uErr } = await supabase
        .from('rollover_guarantors')
        .update({
          status: newStatus,
          decline_reason: accepted ? null : (reason || null),
          responded_at: new Date().toISOString(),
        })
        .eq('id', req.params.gid)
        .select('*')
        .single();
      if (uErr) throw uErr;

      // If all guarantors have accepted, advance rollover to awaiting_admin_approval
      if (accepted) {
        const allAccepted = await allGuarantorsAccepted(req.params.id);
        if (allAccepted) {
          await supabase
            .from('rollovers')
            .update({ status: 'awaiting_admin_approval' })
            .eq('id', req.params.id);
          logger.info(`Rollover ${req.params.id} advanced to awaiting_admin_approval`);
        }
      }

      logger.info(`Guarantor ${req.user.id} ${newStatus} rollover ${req.params.id}`);
      res.json({ success: true, guarantor: updated });
    } catch (err) {
      logger.error('guarantor respond error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// ── PATCH /:id/guarantors/:gid/replace — replace a declined guarantor ─────────

router.patch(
  '/:id/guarantors/:gid/replace',
  [
    param('id').isUUID(),
    param('gid').isUUID(),
    body('newGuarantorId').isString().notEmpty(),
    body('newGuarantorName').isString().notEmpty(),
    body('newGuarantorPhone').isString().notEmpty(),
  ],
  validate,
  async (req, res) => {
    try {
      const rollover = await findRollover(req.params.id, req.user.id);
      if (!rollover) return res.status(404).json({ success: false, error: 'Rollover not found' });
      if (rollover.status !== 'pending') {
        return res.status(400).json({ success: false, error: 'Can only replace guarantors on pending rollovers' });
      }

      const guarantor = await findGuarantor(req.params.id, req.params.gid);
      if (!guarantor) return res.status(404).json({ success: false, error: 'Guarantor not found' });
      if (guarantor.status !== 'declined') {
        return res.status(400).json({ success: false, error: 'Can only replace a declined guarantor' });
      }

      const { newGuarantorId, newGuarantorName, newGuarantorPhone } = req.body;

      // Replace by updating the existing row
      const { data, error } = await supabase
        .from('rollover_guarantors')
        .update({
          guarantor_id: newGuarantorId,
          guarantor_name: newGuarantorName,
          guarantor_phone: newGuarantorPhone,
          status: 'invited',
          decline_reason: null,
          responded_at: null,
          invited_at: new Date().toISOString(),
        })
        .eq('id', req.params.gid)
        .select('*')
        .single();
      if (error) throw error;

      logger.info(`Guarantor ${req.params.gid} replaced on rollover ${req.params.id}`);
      res.json({ success: true, guarantor: data });
    } catch (err) {
      logger.error('replace guarantor error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// ── PATCH /:id/approve — admin approves rollover ──────────────────────────────

router.patch(
  '/:id/approve',
  [param('id').isUUID(), body('adminNotes').isString().optional()],
  validate,
  async (req, res) => {
    try {
      // Basic admin check — extend with your admin middleware as needed
      if (!req.user.is_admin) {
        return res.status(403).json({ success: false, error: 'Admin access required' });
      }

      const rollover = await findRollover(req.params.id);
      if (!rollover) return res.status(404).json({ success: false, error: 'Rollover not found' });
      if (rollover.status !== 'awaiting_admin_approval') {
        return res.status(400).json({ success: false, error: 'Rollover is not awaiting approval' });
      }

      const { data, error } = await supabase
        .from('rollovers')
        .update({
          status: 'approved',
          approved_at: new Date().toISOString(),
          admin_notes: req.body.adminNotes || null,
        })
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) throw error;

      logger.info(`Rollover ${req.params.id} approved by admin ${req.user.id}`);
      res.json({ success: true, rollover: data });
    } catch (err) {
      logger.error('approve rollover error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

// ── PATCH /:id/reject — admin rejects rollover ────────────────────────────────

router.patch(
  '/:id/reject',
  [
    param('id').isUUID(),
    body('rejectionReason').isString().notEmpty(),
  ],
  validate,
  async (req, res) => {
    try {
      if (!req.user.is_admin) {
        return res.status(403).json({ success: false, error: 'Admin access required' });
      }

      const rollover = await findRollover(req.params.id);
      if (!rollover) return res.status(404).json({ success: false, error: 'Rollover not found' });
      if (rollover.status !== 'awaiting_admin_approval') {
        return res.status(400).json({ success: false, error: 'Rollover is not awaiting approval' });
      }

      const { data, error } = await supabase
        .from('rollovers')
        .update({
          status: 'rejected',
          rejected_at: new Date().toISOString(),
          rejection_reason: req.body.rejectionReason,
        })
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) throw error;

      logger.info(`Rollover ${req.params.id} rejected by admin ${req.user.id}`);
      res.json({ success: true, rollover: data });
    } catch (err) {
      logger.error('reject rollover error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

module.exports = router;
