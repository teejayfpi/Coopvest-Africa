/**
 * Shared loan policy rules — Coopvest Africa Loan Policy.
 *
 * Single source of truth for:
 *   - Savings-based loan multipliers per product (Premium 4×, Maxi 5×, others 3×)
 *   - Statuses that block new applications (Active Default Restriction)
 *   - Statuses that count as an "active loan" for the contribution-reduction guard
 *   - Minimum membership and contribution history for a new loan
 */

const LOAN_MULTIPLIERS = {
  'Quick Loan': 3,
  'Flexi Loan': 3,
  'Stable Loan (12 months)': 3,
  'Stable Loan (18 months)': 3,
  'Premium Loan': 4,
  'Maxi Loan': 5,
  // Legacy products
  'Micro Loan': 3,
  'Business Loan': 3,
  'Emergency Loan': 3,
};
const DEFAULT_MULTIPLIER = 3;

// A member with a loan in any of these statuses cannot take a new loan.
const DEFAULT_BLOCKING_STATUSES = ['overdue', 'defaulted', 'in_recovery'];

// Loans in these statuses count as "active" for the rule that forbids
// reducing the monthly contribution below the level used for eligibility.
const ACTIVE_LOAN_STATUSES = ['approved', 'active', 'repaying', 'overdue', 'in_recovery'];

/**
 * Minimum months of membership and of *successful* contribution history a
 * member needs before a new loan is accepted.
 *
 * These were previously enforced only in the app, and the app's copy was
 * disabled with a `TESTING ONLY` flag, so no layer checked them. They now live
 * here, on the server, because eligibility is a lending decision.
 *
 * The check is on by default (secure default). It can be relaxed per
 * environment — staging, demos — by setting LOAN_MIN_ELIGIBILITY_DISABLED=true,
 * which is explicit and auditable rather than a commented-out line in the app.
 */
const MIN_MEMBERSHIP_MONTHS = 6;
const MIN_CONTRIBUTION_MONTHS = 6;

function minEligibilityDisabled() {
  return process.env.LOAN_MIN_ELIGIBILITY_DISABLED === 'true';
}

function monthsBetween(from, to = new Date()) {
  if (!from) return 0;
  const start = new Date(from);
  if (Number.isNaN(start.getTime())) return 0;
  let months = (to.getFullYear() - start.getFullYear()) * 12 + (to.getMonth() - start.getMonth());
  // Not yet a whole month into the current one.
  if (to.getDate() < start.getDate()) months -= 1;
  return Math.max(0, months);
}

/**
 * Count distinct months in which the member made a *successful* contribution.
 *
 * Only 'successful' counts, matching how the app's own summary treats
 * contributions: pending, failed and rejected rows are not history.
 */
function countContributionMonths(contributions) {
  const months = new Set();
  for (const c of contributions || []) {
    if (c.status !== 'successful') continue;
    const key = (c.contribution_month || '').slice(0, 7)
      || (c.created_at ? String(c.created_at).slice(0, 7) : '');
    if (key) months.add(key);
  }
  return months.size;
}

function multiplierFor(loanType) {
  return LOAN_MULTIPLIERS[loanType] || DEFAULT_MULTIPLIER;
}

function maxLoanAmount(loanType, totalSavings) {
  return (Number(totalSavings) || 0) * multiplierFor(loanType);
}

module.exports = {
  LOAN_MULTIPLIERS,
  DEFAULT_MULTIPLIER,
  DEFAULT_BLOCKING_STATUSES,
  ACTIVE_LOAN_STATUSES,
  MIN_MEMBERSHIP_MONTHS,
  MIN_CONTRIBUTION_MONTHS,
  minEligibilityDisabled,
  monthsBetween,
  countContributionMonths,
  multiplierFor,
  maxLoanAmount,
};
