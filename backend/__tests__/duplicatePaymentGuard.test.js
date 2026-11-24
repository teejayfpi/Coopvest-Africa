/**
 * A double-tap must not become a double charge.
 *
 * The member paid the NGN1,500 fee twice six minutes apart and the NGN5,000
 * contribution twice two minutes apart: each tap called `/payments/initialize`,
 * which mints a fresh reference, so Paystack saw two unrelated payments.
 *
 * The guard has to be right in both directions. Blocking a genuine retry after a
 * failed payment is a new bug in place of the old one, so the "must not block"
 * cases below matter as much as the blocking ones.
 */

const { findDuplicatePayment } = require('../src/lib/duplicatePaymentGuard');

const NOW = new Date('2026-11-24T19:05:00Z').getTime();
const minutesAgo = (m) => new Date(NOW - m * 60 * 1000).toISOString();

const proof = (overrides = {}) => ({
  id: 'proof-1',
  status: 'approved',
  amount: 1500,
  payment_type: 'other',
  created_at: minutesAgo(6),
  deleted_at: null,
  transaction_reference: 'CVP-abc-1',
  metadata: {
    target_month: '2026-11',
    allocations: [{ type: 'fee', amount: 1500 }],
  },
  ...overrides,
});

const check = (proofs, overrides = {}) =>
  findDuplicatePayment({
    proofs,
    paymentType: 'other',
    allocations: [{ type: 'fee', amount: 1500 }],
    targetMonth: '2026-11',
    nowMs: NOW,
    ...overrides,
  });

describe('duplicate payment guard', () => {
  test('refuses a second charge minutes after the first was approved', () => {
    // The exact fee-bug shape: paid at 18:57, tried again at 19:03.
    const out = check([proof({ created_at: minutesAgo(6) })]);
    expect(out).not.toBeNull();
    expect(out.code).toBe('ALREADY_PAID');
    expect(out.status).toBe('approved');
  });

  test('refuses while a checkout is still open', () => {
    const out = check([proof({ status: 'pending', created_at: minutesAgo(1) })]);
    expect(out).not.toBeNull();
    expect(out.code).toBe('PAYMENT_IN_PROGRESS');
    expect(out.status).toBe('pending');
  });

  test('surfaces the open reference so the app can resume it', () => {
    const out = check([proof({ status: 'pending', created_at: minutesAgo(1) })]);
    expect(out.proof.transaction_reference).toBe('CVP-abc-1');
  });

  test('allows a retry after an abandoned checkout', () => {
    // A pending row that never resolved must not lock the member out.
    expect(check([proof({ status: 'pending', created_at: minutesAgo(10) })])).toBeNull();
  });

  test('allows a retry once the settled window has passed', () => {
    // Next month's fee is the same amount, and it is legitimately payable again.
    expect(check([proof({ created_at: minutesAgo(30) })])).toBeNull();
  });

  test('allows the same amount for a different month', () => {
    const out = check([
      proof({ metadata: { target_month: '2026-12', allocations: [{ type: 'fee', amount: 1500 }] } }),
    ]);
    expect(out).toBeNull();
  });

  test('blocks a legacy proof that predates target_month', () => {
    // Real rows from before the column existed carry null. Treating null as a
    // mismatch would let the original double-charge straight through.
    const out = check([proof({ metadata: { allocations: [{ type: 'fee', amount: 1500 }] } })]);
    expect(out).not.toBeNull();
    expect(out.code).toBe('ALREADY_PAID');
  });

  test('allows a different amount', () => {
    expect(check([proof({
      amount: 5000,
      metadata: { target_month: '2026-11', allocations: [{ type: 'fee', amount: 5000 }] },
    })])).toBeNull();
  });

  test('allows a fine of the same amount as a fee', () => {
    // fine, fee and mixed all persist as 'other'. Matching on type and amount
    // alone would refuse a legitimate fine because a fee of equal size was paid.
    const out = check([proof({
      metadata: { target_month: '2026-11', allocations: [{ type: 'fine', amount: 1500 }] },
    })]);
    expect(out).toBeNull();
  });

  test('distinguishes a mixed payment from a single leg', () => {
    const out = check([proof({
      metadata: {
        target_month: '2026-11',
        allocations: [
          { type: 'fee', amount: 1000 },
          { type: 'savings', amount: 500 },
        ],
      },
    })]);
    expect(out).toBeNull();
  });

  test('allows a different payment type', () => {
    expect(check([proof({ payment_type: 'monthly_contribution' })])).toBeNull();
  });

  test('ignores deleted proofs', () => {
    expect(check([proof({ deleted_at: minutesAgo(6) })])).toBeNull();
  });

  test('ignores a failed attempt', () => {
    expect(check([proof({ status: 'rejected', created_at: minutesAgo(1) })])).toBeNull();
  });

  test('compares amounts in kobo, so float dust does not defeat it', () => {
    const out = check([
      proof({ metadata: { target_month: '2026-11', allocations: [{ type: 'fee', amount: '1500.00' }] } }),
    ]);
    expect(out).not.toBeNull();
  });

  test('returns null when there is nothing recent', () => {
    expect(check([])).toBeNull();
  });
});
