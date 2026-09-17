/**
 * Manual deposit semantics, shared by the API and the SQL function.
 *
 * The Manual Deposits page offers six deposit types. The browser-side code that
 * this replaced credited the member's WALLET for all of them, which is wrong for
 * the two that are Coopvest income rather than member balance:
 *
 *   savings      Savings Contribution  → member's money      → credits wallet + savings
 *   special      Special Contribution  → member's money      → credits wallet + savings
 *   adjustment   Adjustment (Credit)   → admin correction    → credits wallet
 *   refund       Refund                → money to member     → credits wallet
 *   levy         Monthly Levy          → Coopvest income     → does NOT credit member
 *   entrance_fee Entrance Fee          → Coopvest income     → does NOT credit member,
 *                                                              settles registration fee
 *
 * Crediting a member for a levy or an entrance fee would conjure member balance
 * out of nothing while simultaneously recording the fee as received — the member
 * would appear to have been paid the very money they handed over.
 *
 * This mirrors `public.manual_deposit_credits_member_balance()` in migration 036;
 * keep the two in step.
 */

/** Deposit types that increase the member's balance. */
const MEMBER_CREDITING_TYPES = ['savings', 'special', 'adjustment', 'refund'];

/** Deposit types that settle the registration fee. */
const REGISTRATION_FEE_TYPES = ['entrance_fee'];

/** Deposit types mirrored into the `savings` aggregate. */
const SAVINGS_MIRROR_TYPES = ['savings', 'special'];

const ALL_DEPOSIT_TYPES = [
  'savings',
  'levy',
  'entrance_fee',
  'special',
  'adjustment',
  'refund',
];

/** True when recording this deposit should increase the member's balance. */
function creditsMemberBalance(depositType) {
  return MEMBER_CREDITING_TYPES.includes(depositType);
}

/** True when this deposit settles the member's registration fee. */
function settlesRegistrationFee(depositType) {
  return REGISTRATION_FEE_TYPES.includes(depositType);
}

/**
 * The ledger `allocation_type` for a deposit, which downstream reconciliation
 * and reporting group by.
 */
function allocationTypeFor(depositType) {
  if (settlesRegistrationFee(depositType)) return 'registration_fee';
  if (creditsMemberBalance(depositType) && depositType !== 'refund' && depositType !== 'adjustment') {
    return 'monthly_contribution';
  }
  return 'fee';
}

/**
 * The contribution month a deposit settles, or null when it is not a
 * contribution. Stored rather than derived from `created_at`, so a payment
 * recorded late still attributes to the month it covers.
 */
function contributionMonthFor(depositType, when = new Date()) {
  const allocation = allocationTypeFor(depositType);
  if (allocation !== 'monthly_contribution') return null;
  const d = when instanceof Date ? when : new Date(when);
  if (Number.isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

module.exports = {
  ALL_DEPOSIT_TYPES,
  MEMBER_CREDITING_TYPES,
  REGISTRATION_FEE_TYPES,
  SAVINGS_MIRROR_TYPES,
  creditsMemberBalance,
  settlesRegistrationFee,
  allocationTypeFor,
  contributionMonthFor,
};