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
 * Count distinct months in which the member made a *settled* contribution.
 *
 * Only settled contributions are history; pending, failed and rejected rows
 * are not. The settled set must match the other layers or a member is told
 * they are eligible by one and refused by another: the app's own eligibility
 * check counts 'successful' and 'completed', and the wallet balance counts
 * 'completed', 'successful' and 'approved'. This check used to accept only
 * 'successful', so a member whose contributions were recorded as 'completed'
 * (which the admin bulk import and several payment paths write) saw
 * "You are eligible" in the app and then a 403 from the server.
 */
const SETTLED_CONTRIBUTION_STATUSES = new Set(['successful', 'completed', 'approved', 'paid']);

function countContributionMonths(contributions) {
  const months = new Set();
  for (const c of contributions || []) {
    const status = String(c.status || '').toLowerCase();
    if (!SETTLED_CONTRIBUTION_STATUSES.has(status)) continue;
    const key = (c.contribution_month || '').slice(0, 7)
      || (c.created_at ? String(c.created_at).slice(0, 7) : '');
    if (key) months.add(key);
  }
  return months.size;
}

function multiplierFor(loanType) {
  return LOAN_MULTIPLIERS[loanType] || DEFAULT_MULTIPLIER;
}

/**
 * Fixed tenure, in months, for each product. The app sends exactly this value
 * for the selected product; the server previously accepted any 1–60, so a
 * crafted or stale client could take a 36-month tenure on a 4-month product
 * and get the wrong interest rate. Legacy products have no fixed tenure and
 * accept the general range.
 */
const LOAN_TENURES = {
  'Quick Loan': 4,
  'Flexi Loan': 6,
  'Stable Loan (12 months)': 12,
  'Stable Loan (18 months)': 18,
  'Premium Loan': 24,
  'Maxi Loan': 36,
};

function isTenureAllowed(loanType, tenureMonths) {
  const tenure = Number(tenureMonths);
  if (!Number.isInteger(tenure) || tenure < 1 || tenure > 60) return false;
  const fixed = LOAN_TENURES[loanType];
  if (fixed == null) return true;
  return tenure === fixed;
}

function maxLoanAmount(loanType, totalSavings) {
  return (Number(totalSavings) || 0) * multiplierFor(loanType);
}

module.exports = {
  LOAN_MULTIPLIERS,
  DEFAULT_MULTIPLIER,
  LOAN_TENURES,
  DEFAULT_BLOCKING_STATUSES,
  ACTIVE_LOAN_STATUSES,
  MIN_MEMBERSHIP_MONTHS,
  MIN_CONTRIBUTION_MONTHS,
  SETTLED_CONTRIBUTION_STATUSES,
  minEligibilityDisabled,
  monthsBetween,
  countContributionMonths,
  multiplierFor,
  isTenureAllowed,
  maxLoanAmount,
};
