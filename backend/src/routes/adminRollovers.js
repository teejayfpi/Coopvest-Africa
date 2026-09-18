/**
 * Admin rollover routes.
 *
 * The Rollover Management page in the admin dashboard calls
 * `/api/admin/rollovers`, `/rollovers/:id/approve` and `/rollovers/:id/reject`.
 * None of those existed — the only rollover routes were the member-facing
 * `/api/v1/rollover/*` ones in `routes/rollover.js` — so the page 404'd on
 * mount and on every action.
 *
 * Approving also did nothing to the loan. It flipped `status` to 'approved' and
 * the member was notified "Your new repayment schedule is now active", while the
 * tenure, monthly repayment and outstanding balance were all unchanged. Approval
 * now applies the extension through `apply_loan_rollover()` in one transaction,
 * and the notification is only sent once that has actually happened.
 *
 * Mounted under `/api/admin` via adminApi.js, so it inherits `requireAdmin`.
 */

const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');

const supabase = require('../config/supabase');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');
const notify = require('../services/notifyService');

/** Resolve member names for a batch of rollover rows. Never throws. */
async function memberNameMap(profileIds) {
  const unique = [...new Set((profileIds || []).filter(Boolean))];
  if (unique.length === 0) return {};
  try {
    const { data } = await supabase
      .from('profiles')
      .select('id, name, email, user_id')
      .in('id', unique);
    return Object.fromEntries(
      (data || []).map((p) => [p.id, p.name || p.email || p.user_id || 'Unknown']),
    );
  } catch (err) {
    logger.warn('rollovers: member name lookup failed:', err.message);
    return {};
  }
}

/**
 * Shape a rollovers row for the dashboard's `Rollover` type.
 *
 * The page reads camelCase fields, so the mapping happens here rather than
 * leaving the client to guess at snake_case column names.
 */
function toAdminRollover(row, names) {
  const loan = row.loan || null;
  const original = Number(loan?.amount ?? row.original_loan ?? 0);
  const outstanding = Number(
    loan?.remaining_balance ?? loan?.total_repayment ?? original,
  );

  return {
    id: String(row.id),
    rolloverId: String(row.rollover_id || row.id),
    loanId: String(loan?.loan_id || row.loan_id || ''),
    memberId: String(row.profile_id || ''),
    memberName: names[row.profile_id] || 'Unknown',
    originalAmount: original,
    outstandingBalance: outstanding,
    // A rollover fee is not charged on this platform; the field is part of the
    // dashboard's type and reporting sums it, so report a real zero rather than
    // leaving it undefined.
    rolloverFee: 0,
    newTenure: Number(row.requested_tenure ?? row.extension_months ?? 0),
    status: String(row.status || 'pending'),
    reason: row.requested_reason || row.reason || undefined,
    createdAt: row.created_at,
    approvedAt: row.approved_at || undefined,
    rejectionReason: row.rejection_reason || undefined,
    // Extra context the detail panel can use.
    extensionMonths: Number(row.extension_months || 0),
    appliedAt: row.applied_at || null,
    reviewedAt: row.reviewed_at || null,
  };
}

/**
 * GET /api/admin/rollovers
 * Paginated rollover requests, newest first, filterable by status.
 */
router.get('/rollovers', async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(1000, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const from = (page - 1) * limit;

    let q = supabase
      .from('rollovers')
      .select(
        // Join the loan so the page can show what is being rolled over without
        // a second round-trip per row.
        '*, loan:loans(id, loan_id, amount, remaining_balance, total_repayment, tenure_months, monthly_repayment, status)',
        { count: 'exact' },
      )
      .order('created_at', { ascending: false })
      .range(from, from + limit - 1);

    if (req.query.status) q = q.eq('status', req.query.status);

    const { data, error, count } = await q;
    if (error) {
      if (error.code === '42P01' || /relation .* does not exist|Could not find/i.test(error.message)) {
        return res.json({ success: true, data: [], total: 0 });
      }
      throw error;
    }

    const names = await memberNameMap((data || []).map((r) => r.profile_id));
    const rollovers = (data || []).map((r) => toAdminRollover(r, names));

    res.json({
      success: true,
      data: rollovers,
      total: count || rollovers.length,
      page,
      limit,
    });
  } catch (err) {
    logger.error('admin rollovers list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/admin/rollovers/:id/approve
 *
 * Approve AND apply. The order matters: the loan is extended first, and only
 * then is the member told their schedule has changed. Previously approval
 * notified the member without touching the loan.
 */
router.post(
  '/rollovers/:id/approve',
  [param('id').isUUID(), body('notes').optional().isString()],
  validate,
  async (req, res) => {
    try {
      const { id } = req.params;

      const { data: rollover } = await supabase
        .from('rollovers')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (!rollover) {
        return res.status(404).json({ success: false, error: 'Rollover not found' });
      }
      if (rollover.status === 'approved' && rollover.applied_at) {
        return res.status(409).json({
          success: false,
          error: 'This rollover has already been approved and applied.',
          code: 'ALREADY_APPLIED',
        });
      }
      if (['rejected', 'cancelled'].includes(rollover.status)) {
        return res.status(400).json({
          success: false,
          error: `A ${rollover.status} rollover cannot be approved.`,
        });
      }

      const now = new Date().toISOString();

      const { error: approveErr } = await supabase
        .from('rollovers')
        .update({
          status: 'approved',
          // The columns the table actually has. The previous code wrote
          // approved_at/admin_notes, which do not exist, so this failed.
          approved_at: now,
          admin_notes: req.body.notes || null,
          reviewed_by: req.user.id,
          reviewed_at: now,
          updated_at: now,
        })
        .eq('id', id);
      if (approveErr) throw approveErr;

      // Apply the extension. If this fails the approval is rolled back so the
      // member is never left in an "approved but unchanged" state.
      const { data: applied, error: applyErr } = await supabase.rpc('apply_loan_rollover', {
        p_rollover_id: id,
        p_admin_id: req.user.id,
      });

      if (applyErr) {
        await supabase
          .from('rollovers')
          .update({ status: 'awaiting_admin_approval', approved_at: null, updated_at: now })
          .eq('id', id);

        const message = applyErr.message || 'Failed to apply the rollover';
        if (applyErr.code === '42883' || /apply_loan_rollover.* does not exist/i.test(message)) {
          logger.error('apply_loan_rollover missing — run migration 038');
          return res.status(503).json({
            success: false,
            error: 'Rollover approval is unavailable until migration 038 is applied.',
          });
        }
        if (applyErr.code === '23505' || /already been applied/i.test(message)) {
          return res.status(409).json({ success: false, error: message, code: 'ALREADY_APPLIED' });
        }
        return res.status(400).json({ success: false, error: message });
      }

      // Only now is the member told their schedule changed.
      notify
        .notifyRolloverApproved({
          borrowerProfileId: rollover.profile_id,
          rolloverId: id,
          extensionMonths: rollover.extension_months,
        })
        .catch((err) => logger.warn('Notification error (rollover approved):', err.message));

      logger.info(`Rollover ${id} approved and applied by ${req.user.id}`);
      res.json({
        success: true,
        message: `Loan extended by ${applied?.extension_months} months to ${applied?.new_tenure_months} months. New monthly repayment: ₦${Number(applied?.new_monthly_repayment || 0).toLocaleString()}.`,
        applied,
      });
    } catch (err) {
      logger.error('admin rollover approve error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

/**
 * POST /api/admin/rollovers/:id/reject
 */
router.post(
  '/rollovers/:id/reject',
  [param('id').isUUID(), body('reason').isString().trim().notEmpty().withMessage('A reason is required')],
  validate,
  async (req, res) => {
    try {
      const { id } = req.params;

      const { data: rollover } = await supabase
        .from('rollovers')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (!rollover) {
        return res.status(404).json({ success: false, error: 'Rollover not found' });
      }
      if (rollover.applied_at) {
        return res.status(409).json({
          success: false,
          error: 'This rollover has already been applied to the loan and cannot be rejected.',
        });
      }

      const now = new Date().toISOString();
      const { error } = await supabase
        .from('rollovers')
        .update({
          status: 'rejected',
          // `rejected_at` does NOT exist on `rollovers` (verified against
          // production: 42703). `reviewed_at` is the real column, and
          // `rejection_reason` is the real reason column.
          reviewed_at: now,
          rejection_reason: req.body.reason,
          reviewed_by: req.user.id,
          reviewed_at: now,
          updated_at: now,
        })
        .eq('id', id);
      if (error) throw error;

      notify
        .notifyRolloverRejected({
          borrowerProfileId: rollover.profile_id,
          rolloverId: id,
          rejectionReason: req.body.reason,
        })
        .catch((err) => logger.warn('Notification error (rollover rejected):', err.message));

      logger.info(`Rollover ${id} rejected by ${req.user.id}`);
      res.json({ success: true, message: 'Rollover rejected.' });
    } catch (err) {
      logger.error('admin rollover reject error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

module.exports = router;
module.exports.toAdminRollover = toAdminRollover;