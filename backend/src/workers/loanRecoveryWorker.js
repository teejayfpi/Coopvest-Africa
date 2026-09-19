/**
 * Loan Recovery Worker — Coopvest Africa Loan Policy (Section 4.1)
 *
 * Runs daily to enforce the 3-stage loan recovery process:
 *
 *   Stage 1 — 1st missed month:
 *     Automated repayment reminders sent via email and in-app notifications.
 *
 *   Stage 2 — 2nd consecutive missed month:
 *     A ₦3,000 late repayment charge is applied to the outstanding balance.
 *     An escalation notice is issued to the borrower.
 *     Admin is notified of the default status.
 *
 *   Stage 3 — 3rd consecutive missed month:
 *     Guarantors are contacted. Loan recovery process is initiated.
 *     Admin dashboard is alerted. Additional recovery actions apply.
 *
 * NOTE: The ₦3,000 penalty is NOT applied on the first missed payment.
 * It is applied only after the 2nd consecutive missed month.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');

const POLL_INTERVAL_MS = 24 * 60 * 60 * 1000; // 24 hours
const LATE_REPAYMENT_PENALTY_NGN = 3000;

/**
 * Return how many consecutive months have been missed for a loan.
 * Looks at missed_months column on the loan record if available,
 * or falls back to counting unpaid installments past their due date.
 */
/**
 * How many consecutive monthly repayments this loan has missed.
 *
 * Counted from the repayments actually recorded against it, which is the only
 * source of truth that exists on this table. The previous implementation read
 * `loan.missed_months` and `loan.payments_made` — neither is a column on
 * `loans` (verified against production), so `payments_made` was always 0 and the
 * function returned every month elapsed since approval:
 *
 *   monthsSinceApproved - 0 = monthsSinceApproved
 *
 * That misfired in both directions:
 *   - A member in good standing who had repaid every month was still reported as
 *     having missed all of them, and escalated to a ₦3,000 penalty.
 *   - `next_due_date` is never written anywhere in the codebase, so the separate
 *     overdue queries could never match a loan either.
 *
 * Months are counted as the number of scheduled instalments that have come due
 * since approval and have no matching paid repayment.
 */
async function getConsecutiveMissedMonths(loan) {
  const startValue = loan.disbursed_at || loan.approved_at || loan.created_at;
  if (!startValue) return 0;

  const start = new Date(startValue);
  if (Number.isNaN(start.getTime())) return 0;

  const now = new Date();
  const monthsSinceStart =
    (now.getFullYear() - start.getFullYear()) * 12 + (now.getMonth() - start.getMonth());

  const tenure = Number(loan.tenure_months || loan.tenure || 0);
  const expectedPayments = tenure > 0 ? Math.min(monthsSinceStart, tenure) : monthsSinceStart;
  if (expectedPayments <= 0) return 0;

  // Count distinct calendar months in which a repayment was actually received.
  const { data: repayments, error } = await supabase
    .from('loan_repayments')
    .select('paid_at, created_at, status')
    .eq('loan_id', loan.id)
    .in('status', ['paid', 'completed', 'successful']);

  if (error) {
    // Do not guess. Escalating a member on a failed lookup is worse than
    // skipping this cycle — the next run will pick it up.
    logger.warn(
      `loanRecoveryWorker: repayment lookup failed for loan ${loan.loan_id || loan.id}: ${error.message}`,
    );
    return 0;
  }

  const paidMonths = new Set();
  for (const r of repayments || []) {
    const when = new Date(r.paid_at || r.created_at);
    if (Number.isNaN(when.getTime())) continue;
    paidMonths.add(`${when.getFullYear()}-${when.getMonth()}`);
  }

  // One instalment is expected per month; any month without a payment counts.
  const paidCount = Math.min(paidMonths.size, expectedPayments);
  return Math.max(0, expectedPayments - paidCount);
}

async function notifyAdminOfDefault(loan, stage) {
  try {
    // Find admin profiles
    const { data: admins } = await supabase
      .from('profiles')
      .select('id')
      .eq('role', 'admin');

    if (!admins || admins.length === 0) return;

    await notifyService.broadcast({
      profileIds: admins.map((a) => a.id),
      channels: ['in_app', 'email'],
      title: `⚠️ Loan Default Alert — Stage ${stage}`,
      body: `Loan ${loan.loan_id || loan.id} is in Stage ${stage} default. Borrower profile: ${loan.profile_id}. Amount overdue: ₦${(loan.amount || 0).toLocaleString()}.`,
    });
  } catch (err) {
    logger.warn('loanRecoveryWorker: admin notification failed:', err.message);
  }
}

async function notifyGuarantors(loan) {
  try {
    // Fetch guarantors for this loan
    const { data: guarantors } = await supabase
      .from('loan_guarantors')
      .select('guarantor_profile_id, guarantor_name')
      .eq('loan_id', loan.id)
      .eq('status', 'accepted');

    if (!guarantors || guarantors.length === 0) return;

    for (const g of guarantors) {
      await notifyService.sendInApp({
        profileId: g.guarantor_profile_id,
        title: '⚠️ Loan Recovery Notice',
        body: `A loan you guaranteed is now 3 months overdue. As a guarantor, you may be contacted as part of Coopvest Africa's loan recovery process in accordance with the loan policy you accepted.`,
        type: 'loan_recovery',
        category: 'warning',
        priority: 'high',
      });
    }

    logger.info(`loanRecoveryWorker: guarantors notified for loan ${loan.loan_id || loan.id}`);
  } catch (err) {
    logger.warn('loanRecoveryWorker: guarantor notification failed:', err.message);
  }
}

async function processDue() {
  try {
    // Fetch all active/repaying loans
    // NOTE: `disbursed_at` does not exist on the loans table (only
    // `disbursed_by` does) — filtering on it caused PostgREST to 400 on
    // every run. `approved_at` is the actual populated timestamp marking
    // when a loan started, and the status filter already restricts us to
    // live loans, so we use that instead.
    const { data: activeLoans, error } = await supabase
      .from('loans')
      .select('*')
      .in('status', ['active', 'repaying', 'overdue'])
      .not('approved_at', 'is', null);

    if (error) throw error;
    if (!activeLoans || activeLoans.length === 0) return;

    for (const loan of activeLoans) {
      try {
        const missedMonths = await getConsecutiveMissedMonths(loan);

        if (missedMonths <= 0) continue; // No missed payments — nothing to do

        const profileId = loan.profile_id;

        // ── STAGE 1: 1st missed month — send reminder ─────────────────────
        if (missedMonths === 1) {
          await notifyService.broadcast({
            profileIds: [profileId],
            channels: ['in_app', 'email'],
            title: 'Loan Repayment Reminder',
            body: `Your loan repayment is overdue. Please make your payment to avoid late fees. Late loan repayments may attract a ₦3,000 penalty fee after repeated default notices.`,
          });

          // Mark status as overdue if not already
          if (loan.status !== 'overdue') {
            await supabase
              .from('loans')
              .update({ status: 'overdue', updated_at: new Date().toISOString() })
              .eq('id', loan.id);
          }

          logger.info(`loanRecoveryWorker: Stage 1 reminder sent — loan ${loan.loan_id || loan.id}`);
        }

        // ── STAGE 2: 2nd consecutive missed month — apply ₦3,000 penalty ──
        else if (missedMonths === 2) {
          // Fines are separate obligations — record a member_fees row.
          await supabase.from('member_fees').insert({
            profile_id: profileId,
            loan_id: loan.id,
            fee_type: 'fine',
            label: 'Late Loan Repayment Fine',
            amount: LATE_REPAYMENT_PENALTY_NGN,
            status: 'outstanding',
          });

          await supabase
            .from('loans')
            .update({
              penalty_applied: true,
              penalty_amount: (loan.penalty_amount || 0) + LATE_REPAYMENT_PENALTY_NGN,
              status: 'overdue',
              updated_at: new Date().toISOString(),
            })
            .eq('id', loan.id);

          // Notify borrower of penalty
          await notifyService.broadcast({
            profileIds: [profileId],
            channels: ['in_app', 'email'],
            title: '⚠️ Late Repayment Penalty Applied',
            body: `A ₦3,000 late repayment fine has been added to your obligations as a separate fee due to 2 consecutive missed payments. Please arrange a repayment plan immediately.`,
          });

          // Flag the account (Policy: Active Default Restriction). The flag is
          // cleared automatically once no overdue/defaulted loans remain.
          const { error: flagErr } = await supabase
            .from('profiles')
            .update({ is_flagged: true, flag_reason: 'loan_default' })
            .eq('id', profileId)
            .neq('is_flagged', true);
          if (flagErr) {
            // flag_reason requires migration 019 — fall back to the bare flag
            if (/Could not find the .* column|column .* does not exist/i.test(flagErr.message || '')) {
              await supabase.from('profiles').update({ is_flagged: true }).eq('id', profileId).neq('is_flagged', true);
            } else {
              logger.warn('loanRecoveryWorker: account flag failed:', flagErr.message);
            }
          }

          // Notify admin
          await notifyAdminOfDefault(loan, 2);

          logger.info(`loanRecoveryWorker: Stage 2 fine recorded — loan ${loan.loan_id || loan.id}`);
        }

        // ── STAGE 3: 3rd+ consecutive missed month — contact guarantors ───
        else if (missedMonths >= 3) {
          // Contact guarantors
          await notifyGuarantors(loan);

          // Mark loan as in recovery
          await supabase
            .from('loans')
            .update({
              status: 'in_recovery',
              recovery_initiated_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq('id', loan.id)
            .neq('status', 'in_recovery'); // Only update once

          // Notify borrower
          await notifyService.broadcast({
            profileIds: [profileId],
            channels: ['in_app', 'email'],
            title: '🚨 Loan Recovery Initiated',
            body: `Your loan has been overdue for 3 consecutive months. The loan recovery process has been initiated and your guarantors have been contacted in accordance with Coopvest Africa's loan policy. Please contact us immediately to resolve this.`,
          });

          // Notify admin
          await notifyAdminOfDefault(loan, 3);

          logger.info(`loanRecoveryWorker: Stage 3 recovery initiated — loan ${loan.loan_id || loan.id}`);
        }
      } catch (loanErr) {
        logger.warn(`loanRecoveryWorker: failed to process loan ${loan.id}:`, loanErr.message);
      }
    }
  } catch (err) {
    logger.warn('loanRecoveryWorker: tick failed:', err.message);
  }
}

function start() {
  if (process.env.LOAN_RECOVERY_DISABLED === '1') {
    logger.info('loanRecoveryWorker: disabled via env');
    return null;
  }
  logger.info('loanRecoveryWorker: started (poll every 24h)');
  const handle = setInterval(processDue, POLL_INTERVAL_MS);
  // Run once shortly after startup (5 min delay to let server fully initialize)
  setTimeout(() => processDue().catch(() => {}), 5 * 60 * 1000);
  return handle;
}

module.exports = { start, processDue };
