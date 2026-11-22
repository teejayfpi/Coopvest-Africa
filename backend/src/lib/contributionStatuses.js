/**
 * The contribution statuses that mean money actually arrived.
 *
 * This lived in three places — `loanPolicy`, `contributionConsistency` and
 * `wallet` — and they disagreed: only the wallet's copy accepted `confirmed`.
 * A member whose contribution was recorded as `confirmed` therefore had it
 * counted in their balance but not toward their loan eligibility, so their
 * savings grew while the app told them they had not been saving.
 *
 * One list, one meaning. `confirmed` is included because the wallet counts it;
 * excluding it anywhere makes the same row both paid and unpaid depending on
 * which screen reads it.
 */
const PAID_CONTRIBUTION_STATUSES = ['successful', 'completed', 'approved', 'confirmed', 'paid'];

const PAID_CONTRIBUTION_STATUS_SET = new Set(PAID_CONTRIBUTION_STATUSES);

/** True when a stored contribution status counts as settled. */
function isPaidContributionStatus(status) {
  return PAID_CONTRIBUTION_STATUS_SET.has(String(status || '').toLowerCase().trim());
}

module.exports = {
  PAID_CONTRIBUTION_STATUSES,
  PAID_CONTRIBUTION_STATUS_SET,
  isPaidContributionStatus,
};
