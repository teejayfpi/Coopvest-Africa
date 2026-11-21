/**
 * Tell a loan's guarantors how the application was decided.
 *
 * WHY THIS IS SHARED
 * ------------------
 * A loan can be decided in several places, and only one of them used to tell
 * the guarantors anything:
 *
 *   POST /admin/loans/:id/approve   -> told guarantors on approval
 *   POST /admin/loans/:id/reject    -> told nobody but the borrower
 *   POST /admin/loans/:id/decision  -> told nobody but the borrower
 *   Approval Center (governance)    -> told nobody but the borrower
 *
 * So a guarantor was told when a loan they had backed went through, but heard
 * nothing when it was refused, and heard nothing at all if the decision was
 * made through the Approval Center. That is the same missing fact, which is why
 * this lives in one module rather than being copied per route.
 *
 * A guarantor consented on the understanding that they would be liable if the
 * borrower defaulted. Being told the loan was declined matters as much as being
 * told it was approved: it is the moment that liability ends.
 *
 * Best-effort throughout. A notification failure must never fail the decision
 * itself, which the caller has already written to the database.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');

/** Guarantor states that mean the member is actually on the hook. */
const BOUND_STATUSES = new Set(['consented', 'accepted']);

/**
 * Resolve the member account behind each guarantor row.
 *
 * Two id columns exist: `guarantor_profile_id` (the member account) and
 * `guarantor_id` (a legacy reference). Prefer the former, fall back to the
 * latter, and drop anything unset so a malformed row cannot throw.
 */
function recipientIds(rows) {
  return [...new Set(
    (rows || [])
      .map((g) => g.guarantor_profile_id || g.guarantor_id)
      .filter((id) => typeof id === 'string' && id.length > 0),
  )];
}

/**
 * The guarantors who are actually on the hook.
 *
 * A row with no status at all is included: older rows predate the column being
 * populated, and excluding them would leave the earliest guarantees permanently
 * silent. A row with a status that is not a consent (declined, withdrawn,
 * replaced) is excluded — there is no "if none matched, use them all" fallback,
 * because that would resurrect a guarantor who explicitly refused.
 */
function boundGuarantors(rows) {
  return (rows || []).filter(
    (g) => !g.status || BOUND_STATUSES.has(String(g.status).toLowerCase()),
  );
}

function formatAmount(amount) {
  const value = Number(amount || 0);
  return value ? `₦${value.toLocaleString()}` : 'a loan';
}

async function loadGuarantors(loanId) {
  const { data, error } = await supabase
    .from('loan_guarantors')
    .select('guarantor_profile_id, guarantor_id, guarantor_name, status')
    .eq('loan_id', loanId);
  if (error) {
    logger.warn(`guarantorNotifications: could not load guarantors for loan ${loanId}: ${error.message}`);
    return [];
  }
  return data || [];
}

/**
 * The profile ids of a loan's bound guarantors.
 *
 * Filtering happens here, in JavaScript, rather than in the query. The status
 * vocabulary is not enforced by the schema and the two readers disagreed:
 * consent writes 'consented', but loanRecoveryWorker asked the database for
 * 'accepted', a value nothing ever writes. That filter matched no row, so
 * guarantors were never told a loan had gone into recovery — the one moment
 * their liability becomes real. Matching in one place keeps the readers honest.
 */
async function boundGuarantorIds(loanId) {
  const rows = await loadGuarantors(loanId);
  return recipientIds(boundGuarantors(rows));
}

/**
 * Notify every guarantor of a loan decision.
 *
 * @param {object} loan     row carrying at least `id` and `amount`
 * @param {boolean} approve
 * @param {string|null} [reason] borrower-facing rejection reason, if any
 * @returns {Promise<number>} how many guarantors were notified
 */
async function notifyGuarantorsOfDecision(loan, approve, reason = null) {
  try {
    const loanId = loan && loan.id;
    if (!loanId) return 0;

    const guarantors = await loadGuarantors(loanId);
    if (guarantors.length === 0) return 0;

    const amount = formatAmount(loan.amount);

    // Only consenting guarantors are on the hook, so only they are told. The
    // rejection wording deliberately does not repeat the borrower's reason:
    // that is between the borrower and the cooperative.
    const title = approve
      ? 'Loan you guaranteed was approved'
      : 'Loan you guaranteed was declined';
    const body = approve
      ? `A loan of ${amount} that you guaranteed has been approved. `
        + 'As guarantor, you may be contacted as part of loan recovery if it falls into arrears.'
      : `A loan of ${amount} that you guaranteed was declined, so it will not be disbursed. `
        + 'You are no longer liable for it.';

    // In-app alone is not enough. A guarantor has no reason to open the app on
    // the day someone else's loan is decided, so a stored row would sit unread
    // until they happened to look. Push reaches the device; the in-app row is
    // still written so the decision is in their history.
    const targets = recipientIds(boundGuarantors(guarantors));
    for (const profileId of targets) {
      await notifyService.broadcast({
        profileIds: [profileId],
        channels: ['in_app', 'push'],
        title,
        body,
        type: 'loan',
        category: approve ? 'info' : 'warning',
        data: { loanId, decision: approve ? 'approved' : 'rejected' },
      });
    }

    logger.info(
      `guarantorNotifications: told ${targets.length} guarantor(s) that loan ${loanId} was `
      + `${approve ? 'approved' : 'rejected'}`,
    );
    return targets.length;
  } catch (e) {
    logger.warn('notifyGuarantorsOfDecision failed:', e.message);
    return 0;
  }
}

/**
 * Tell a loan's guarantors that recovery has begun.
 *
 * Sent when a loan is three consecutive months overdue. It states what happens
 * next rather than asserting a debt: no pledge is collected at this point, so
 * telling a guarantor they owe money now would be untrue.
 *
 * @param {object} loan row carrying at least `id`
 * @returns {Promise<number>} how many guarantors were notified
 */
async function notifyGuarantorsOfRecovery(loan) {
  try {
    const loanId = loan && loan.id;
    if (!loanId) return 0;

    const targets = await boundGuarantorIds(loanId);
    for (const profileId of targets) {
      await notifyService.broadcast({
        profileIds: [profileId],
        channels: ['in_app', 'push'],
        title: 'Loan Recovery Notice',
        body: 'A loan you guaranteed is now 3 months overdue. As a guarantor, you may be '
          + "contacted as part of Coopvest Africa's loan recovery process in accordance with "
          + 'the loan policy you accepted.',
        type: 'loan_recovery',
        category: 'warning',
        priority: 'high',
        data: { loanId, stage: 'recovery' },
      });
    }

    logger.info(`guarantorNotifications: told ${targets.length} guarantor(s) that loan ${loanId} entered recovery`);
    return targets.length;
  } catch (e) {
    logger.warn('notifyGuarantorsOfRecovery failed:', e.message);
    return 0;
  }
}

module.exports = {
  BOUND_STATUSES,
  boundGuarantorIds,
  notifyGuarantorsOfDecision,
  notifyGuarantorsOfRecovery,
};
