/**
 * Loan Recovery Worker — Coopvest Africa Loan Policy (Section 4.1)
 *
 * Runs daily to enforce the 3-stage loan recovery process:
 *
 *   Stage 1 — 1st missed month:
 *     Automated repayment reminders sent via email and in-app notifications.
 *
 *   Stage 2 — 2nd consecutive missed month:
 *     A ₦3,000 late repayment fine is recorded as a separate obligation (a
 *     `member_fees` row). It is not added to the loan balance.
 *     An escalation notice is issued to the borrower.
 *     Admin is notified of the default status.
 *
 *   Stage 3 — 3rd consecutive missed month:
 *     Guarantors are contacted. Loan recovery process is initiated.
 *     Admin dashboard is alerted. Additional recovery actions apply.
 *
 * NOTE: The late repayment fine is NOT applied on the first missed payment.
 * It is applied only after the 2nd consecutive missed month. The amount lives
 * in `config/feeDisclosure.js`, which is also what the member-facing
 * disclosure quotes, so the two cannot drift.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');
const guarantorNotifications = require('../lib/guarantorNotifications');
const { LATE_REPAYMENT_FINE, naira } = require('../config/feeDisclosure');

const POLL_INTERVAL_MS = 24 * 60 * 60 * 1000;
// The amount and the wording the member sees both come from the one constant,
// so a change to the fine cannot leave the notification quoting the old figure.
const LATE_REPAYMENT_PENALTY_NGN = LATE_REPAYMENT_FINE;
const FINE_LABEL = naira(LATE_REPAYMENT_FINE);

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
 *     having missed all of them, and escalated to a late repayment fine.
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
  // Delegates to the shared notifier so the definition of a "bound guarantor"
  // is the same one the decision paths use. The previous version filtered the
  // query on status 'accepted', a value nothing in the codebase writes — consent
  // writes 'consented' — so it matched no row and no guarantor was ever told.
  try {
    await guarantorNotifications.notifyGuarantorsOfRecovery(loan);
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
            body: `Your loan repayment is overdue. Please make your payment to avoid late fees. Late loan repayments may attract a ${FINE_LABEL} penalty fee after repeated default notices.`,
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

        // ── STAGE 2: 2nd+ consecutive missed month — apply the late repayment fine ──
        //
        // `>= 2`, not `=== 2`. With an exact match a loan that reached 3 missed
        // months never matched this branch again and silently skipped the fine,
        // while a loan sitting at exactly 2 re-ran it every day (see the guard
        // below). Stage 3 no longer depends on this branch having been skipped.
        else if (missedMonths >= 2) {
          // The fine is charged once per loan, not once per worker tick. This
          // ran daily before, so a loan at 2 missed months accumulated a new
          // late-fee row every day — tens of thousands of naira of obligations
          // for a single policy fine. `penalty_applied` was written but never
          // read, so it could not prevent that.
          const alreadyFined = loan.penalty_applied === true
            || Number(loan.penalty_amount || 0) > 0
            || await hasOutstandingLateFine(loan.id);

          if (!alreadyFined) {
            // Fines are separate obligations — record a member_fees row.
            const { error: fineErr } = await supabase.from('member_fees').insert({
              profile_id: profileId,
              loan_id: loan.id,
              fee_type: 'fine',
              label: 'Late Loan Repayment Fine',
              amount: LATE_REPAYMENT_PENALTY_NGN,
              status: 'outstanding',
            });
            // A silent failure here charged the member in the notification but
            // not on their account, which is how a fee becomes invisible.
            if (fineErr) {
              logger.error(`loanRecoveryWorker: fine insert failed for loan ${loan.loan_id || loan.id}:`, fineErr.message);
              throw fineErr;
            }

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
              body: `A ${FINE_LABEL} late repayment fine has been added to your obligations as a separate fee due to 2 consecutive missed payments. Please arrange a repayment plan immediately.`,
            });

            logger.info(`loanRecoveryWorker: Stage 2 fine recorded — loan ${loan.loan_id || loan.id}`);
          }

          // Flag the account (Policy: Active Default Restriction). Idempotent:
          // the neq keeps it from re-writing on every tick.
          await flagAccountForDefault(profileId);

          // Notify admin. Only on the tick that actually charged the fine, so a
          // loan sitting in default does not mail the admins every morning.
          if (!alreadyFined) await notifyAdminOfDefault(loan, 2);
        }

        // ── STAGE 3: 3rd+ consecutive missed month — contact guarantors ───
        //
        // A separate `if`, not `else if`. Stage 2 now matches every month from
        // the 2nd onward, so chaining them would make stage 3 unreachable.
        if (missedMonths >= 3) {
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

/**
 * Has this loan already been charged the late repayment fine?
 *
 * The durable check is the `member_fees` row itself rather than only the
 * `loans.penalty_applied` flag: the flag can be reset by an admin restructure
 * while the fee obligation still exists, and charging twice is the failure that
 * actually costs a member money.
 */
async function hasOutstandingLateFine(loanId) {
  const { data, error } = await supabase
    .from('member_fees')
    .select('id')
    .eq('loan_id', loanId)
    .eq('fee_type', 'fine')
    .eq('label', 'Late Loan Repayment Fine')
    .limit(1);
  // On a read error assume it was already charged: skipping a fine is
  // recoverable, silently duplicating one is not.
  if (error) {
    logger.warn(`loanRecoveryWorker: fine lookup failed for loan ${loanId}:`, error.message);
    return true;
  }
  return (data || []).length > 0;
}

/**
 * Apply the Policy "Active Default Restriction" flag.
 *
 * `is_flagged` blocks login outright (see auth.js), so this is the most
 * consequential write the worker makes. Idempotent via `neq`, and it falls back
 * to the bare flag when `flag_reason` is absent.
 */
async function flagAccountForDefault(profileId) {
  const { error: flagErr } = await supabase
    .from('profiles')
    .update({ is_flagged: true, flag_reason: 'loan_default' })
    .eq('id', profileId)
    .neq('is_flagged', true);
  if (!flagErr) return;
  // flag_reason requires migration 019 — fall back to the bare flag
  if (/Could not find the .* column|column .* does not exist/i.test(flagErr.message || '')) {
    await supabase.from('profiles').update({ is_flagged: true }).eq('id', profileId).neq('is_flagged', true);
    return;
  }
  logger.warn('loanRecoveryWorker: account flag failed:', flagErr.message);
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
