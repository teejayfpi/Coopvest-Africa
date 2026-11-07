/**
 * The cooperative's charges, in one place.
 *
 * Members are entitled to see every charge before they incur it, and the
 * figure we publish has to be the figure we levy. Those two facts pull in
 * opposite directions the moment an amount is written down twice: a leaflet
 * that says ₦3,000 while the code charges ₦3,500 is worse than no leaflet,
 * because the member relied on it.
 *
 * So the amounts live here once. The routes that levy a charge read the
 * constant, and the member-facing disclosure (`config/terms.json`) is checked
 * against the same constant by `__tests__/feeDisclosure.test.js`. If someone
 * changes the penalty in the recovery worker without changing this file, or
 * changes this file without changing the published text, a test fails.
 *
 * Scope: charges the member bears. Cooperative income that never touches a
 * member's balance (an employer remittance, say) is not a member charge and
 * does not belong here.
 */

/** Late-repayment fine, applied on the 2nd consecutive missed instalment. */
const LATE_REPAYMENT_FINE = 3000;

/** One-time, non-refundable registration (entrance) fee, added to the first contribution. */
const REGISTRATION_FEE = 5000;

/** Minimum monthly contribution. Not a charge, but a recurring member obligation. */
const MIN_MONTHLY_CONTRIBUTION = 5000;

/**
 * The monthly administrative charge, itemised so the member can see what it
 * is made of rather than only the total.
 */
const ADMINISTRATIVE_FEE = {
  total: 1500,
  components: [
    { name: 'AGM levy', amount: 1000 },
    { name: 'Development levy', amount: 500 },
  ],
};

/**
 * Loan interest, simple, per product. Keyed by the loan type the app sends.
 * Mirrors `referralService.BASE_RATES`; a test asserts the two agree.
 */
const LOAN_INTEREST_RATES = {
  'Quick Loan': 7.5,
  'Flexi Loan': 7.0,
  'Stable Loan (12 months)': 5.0,
  'Stable Loan (18 months)': 7.0,
  'Premium Loan': 14.0,
  'Maxi Loan': 19.0,
};

/** Format a naira amount the way the disclosure text writes it. */
function naira(amount) {
  return `₦${Number(amount).toLocaleString('en-NG')}`;
}

module.exports = {
  LATE_REPAYMENT_FINE,
  REGISTRATION_FEE,
  MIN_MONTHLY_CONTRIBUTION,
  ADMINISTRATIVE_FEE,
  LOAN_INTEREST_RATES,
  naira,
};
