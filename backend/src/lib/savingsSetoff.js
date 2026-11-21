/**
 * Planning the recovery of a defaulted loan from savings.
 *
 * `default_recovery_policy` clause 3 has always told the member that outstanding
 * balances "may be recovered from the member's contributions, savings, or
 * dividends", and `guarantor_requirement` clause 3 has always told a guarantor
 * they "accept joint responsibility for the repayment of the guaranteed loan in
 * the event of default". Neither sentence did anything: the recovery worker
 * notified and then stopped.
 *
 * This module decides *who pays, in what order, and how much*. It performs no
 * I/O, so the ordering rules can be read and tested without a database. The
 * executor in migration 068 applies the plan atomically.
 *
 * The order is not arbitrary. The borrower's own savings go first — it is their
 * debt, and `savings_move` already holds that money against the loan. Only the
 * remainder falls to guarantors, and only up to what each of them pledged at
 * consent, so nobody is asked for more than they agreed to when they signed.
 */

/**
 * Build the order in which savings should be applied to a defaulted loan.
 *
 * @param {object}   input
 * @param {number}   input.outstanding       what the loan still owes
 * @param {string}   input.borrowerProfileId profile whose savings go first
 * @param {number}   input.borrowerSavings   borrower's savings balance
 * @param {Array}    input.guarantors        [{ profileId, savings, pledged }]
 *                                           in consent order. `pledged` is the
 *                                           pledge still unused, not the
 *                                           original amount: a loan recovered
 *                                           in more than one pass must not
 *                                           charge the same pledge twice.
 * @returns {{steps: Array, recovered: number, shortfall: number, exhausted: boolean}}
 *   `steps` is the ordered list of debits to apply. `shortfall` is what remains
 *   uncovered once every source is exhausted — the part that has to go to
 *   collections, a credit bureau referral, or a write-off decision.
 */
function planSetOff({ outstanding, borrowerProfileId, borrowerSavings, guarantors }) {
  let remaining = round2(Math.max(Number(outstanding) || 0, 0));
  const steps = [];

  const take = (profileId, role, available, cap) => {
    if (remaining <= 0 || !profileId) return;
    const limit = Math.min(
      Math.max(Number(available) || 0, 0),
      cap == null ? Infinity : Math.max(Number(cap) || 0, 0),
    );
    if (limit <= 0) return;
    const amount = round2(Math.min(limit, remaining));
    if (amount <= 0) return;
    steps.push({ profileId, role, amount });
    remaining = round2(remaining - amount);
  };

  take(borrowerProfileId, 'borrower', borrowerSavings, null);

  for (const g of Array.isArray(guarantors) ? guarantors : []) {
    take(g && g.profileId, 'guarantor', g && g.savings, g && g.pledged);
  }

  return {
    steps,
    recovered: round2(steps.reduce((sum, s) => sum + s.amount, 0)),
    shortfall: remaining,
    exhausted: remaining > 0,
  };
}

function round2(n) {
  return Math.round((Number(n) || 0) * 100) / 100;
}

/**
 * Whether a loan is far enough gone to justify taking savings.
 *
 * Deliberately narrow. An `active` loan is being repaid and its savings are
 * already held by the lien — applying set-off there would punish a member who is
 * simply mid-term. Only the statuses that mean the member has stopped paying
 * qualify.
 */
const SET_OFF_STATUSES = ['overdue', 'defaulted', 'in_recovery'];

function isEligibleForSetOff(loan) {
  if (!loan) return false;
  return SET_OFF_STATUSES.includes(String(loan.status || '').toLowerCase());
}

/**
 * Member-facing notice before savings are taken.
 *
 * Sent ahead of the debit rather than after it. Taking money out of a member's
 * savings without telling them first is the kind of thing that turns a
 * recoverable arrears case into a complaint, and the policy commits only to
 * recovery being *possible*, not to it being silent.
 */
function setOffNotice({ amount, loanReference, daysUntil }) {
  return (
    `Your loan ${loanReference || ''} is in arrears and ${naira(amount)} will be recovered from your savings`
    + ` in ${daysUntil} days unless the balance is settled. This is provided for in the default and recovery`
    + ' policy you accepted. Contact the cooperative before then if you believe this is wrong.'
  );
}

function naira(amount) {
  return `₦${Number(amount || 0).toLocaleString('en-NG')}`;
}

module.exports = {
  SET_OFF_STATUSES,
  planSetOff,
  isEligibleForSetOff,
  setOffNotice,
};
