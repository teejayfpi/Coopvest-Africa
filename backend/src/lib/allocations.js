/**
 * Allocation breakdowns for instant (Paystack) payments.
 *
 * A member's payment is split into obligations: `savings` credits the wallet,
 * `loan_repayment` reduces a loan, and `fine`/`fee`/`registration_fee` settle
 * fee records. Only an explicit `monthly_contribution` (or a `savings`
 * allocation) may ever credit the wallet — an unrecognised type must credit
 * nothing rather than defaulting to savings.
 */

const ALLOWED_PAYMENT_TYPES = new Set([
  'monthly_contribution',
  'loan_repayment',
  'registration_fee',
  'investment',
  'other',
  'fine',
  'fee',
  'mixed',
]);

// payment_proofs.payment_type CHECK-compatible storage type for a UI choice.
const DB_PAYMENT_TYPE = {
  monthly_contribution: 'monthly_contribution',
  loan_repayment: 'loan_repayment',
  registration_fee: 'registration_fee',
  investment: 'investment',
  other: 'other',
  fine: 'other',
  fee: 'other',
  mixed: 'other',
};

function normalizeAllocations(amount, allocationType, allocations) {
  const amt = Number(amount) || 0;
  const hasList = Array.isArray(allocations) && allocations.length > 0;
  if (hasList) {
    return allocations.map((a) => ({
      type: String(a.type || '').replace(/[^a-z_]/gi, '').toLowerCase(),
      amount: Number(a.amount) || 0,
      loan_id: a.loan_id || null,
      fee_id: a.fee_id || null,
    })).filter((a) => a.amount > 0);
  }
  // Callers must state the obligation explicitly. An omitted allocation_type is
  // ambiguous — the account-activation screen posts
  // { amount, payment_type: 'registration_fee' } with no allocation_type, and
  // defaulting it to `monthly_contribution` credited ₦5,000 registration fees
  // straight into member wallets as savings. Fail closed instead.
  const type = String(allocationType || '').toLowerCase();
  switch (type) {
    case 'monthly_contribution':
      return [{ type: 'savings', amount: amt }];
    case 'savings':
      return [{ type: 'savings', amount: amt }];
    case 'loan_repayment':
      return [{ type: 'loan_repayment', amount: amt }];
    case 'registration_fee':
      return [{ type: 'registration_fee', amount: amt }];
    case 'fine':
    case 'fee':
      return [{ type, amount: amt }];
    case 'investment':
      return [{ type: 'investment', amount: amt }];
    // A `mixed` payment without an explicit breakdown is NOT necessarily
    // savings, and an unknown/`other` type must never silently become a wallet
    // credit. An empty breakdown credits nothing.
    default:
      return [];
  }
}

module.exports = { ALLOWED_PAYMENT_TYPES, DB_PAYMENT_TYPE, normalizeAllocations };