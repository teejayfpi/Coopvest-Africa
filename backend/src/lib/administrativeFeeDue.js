/**
 * The monthly administrative fee as part of *this* month's obligation.
 *
 * The billing worker only creates a `member_fees` row once a day, for the month
 * it is in. Between the start of a month and the worker's first tick there is
 * no row, so anything that summed only outstanding rows priced the month
 * without the fee: the member was shown a total that excluded a charge they
 * owe, and a direct-deposit member who paid that total still owed the fee.
 *
 * The fee is therefore priced from the catalogue for the current month, and
 * added only when no row already covers that month. The row is authoritative
 * once it exists — it carries the amount actually billed, which may differ from
 * today's catalogue if the fee changed mid-month.
 *
 * Pure, so the rule is testable without a database.
 */

const { ADMINISTRATIVE_FEE } = require('../config/feeDisclosure');

/**
 * @param {object} args
 * @param {boolean} args.exempt      Employer withholds the fee; it is not owed in-app.
 * @param {string|null} args.month    Current 'YYYY-MM'.
 * @param {Array<{billing_month?: string|null, amount?: number, status?: string}>} args.memberFeeRows
 *   Existing administrative-fee rows for this member, in any status.
 * @returns {number} The amount still to add to this month's total, 0 when none.
 */
function administrativeFeeDue({ exempt, month, memberFeeRows = [] } = {}) {
  if (exempt) return 0;
  if (!month) return 0;
  const alreadyCovered = memberFeeRows.some((row) => {
    if (!row) return false;
    // A row dated to this month covers it whether it is outstanding or paid.
    if (row.billing_month === month) return true;
    // Rows raised before `billing_month` existed carry no month. An unsettled
    // one is already counted in the member's fee total, so pricing the
    // catalogue amount as well would ask for the same charge twice.
    return !row.billing_month && row.status === 'outstanding';
  });
  if (alreadyCovered) return 0;
  return Number(ADMINISTRATIVE_FEE.total) || 0;
}

module.exports = { administrativeFeeDue };
