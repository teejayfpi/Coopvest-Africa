/**
 * A fee is priced by the server, not by whoever is editing the split.
 *
 * The deposit screen lets a member edit how a "Pay Now" payment is divided.
 * Savings may be any amount, but a fee is fixed — and the settlement path marks
 * a member_fees row paid on any positive amount. A member who sent
 * { fee: 1 } against a NGN1,500 administrative fee therefore cleared the whole
 * charge for NGN1. Reproduced against the live API before this guard existed.
 */

const { feePriceFor, findUnderpaidFees } = require('../src/lib/feePricing');

const CATALOGUE = [
  { name: 'Administrative Fee', category: 'fee', amount: 1500 },
  { name: 'Late Loan Repayment Fine', category: 'fine', amount: 3000 },
  { name: 'Registration Fee', category: 'registration_fee', amount: 5000 },
];

const priceFor = (alloc) => feePriceFor({ catalogue: CATALOGUE, type: alloc.type });

describe('feePriceFor', () => {
  test('prices the administrative fee from the catalogue', () => {
    expect(feePriceFor({ catalogue: CATALOGUE, type: 'fee' })).toBe(1500);
  });

  test('prices a fine from the catalogue', () => {
    expect(feePriceFor({ catalogue: CATALOGUE, type: 'fine' })).toBe(3000);
  });

  test('an explicit fee_id row wins over the catalogue', () => {
    // The row shown to the member is what they owe, even if the catalogue has
    // since been repriced.
    const rows = [{ id: 'fee-row', amount: 2000 }];
    expect(feePriceFor({ rows, catalogue: CATALOGUE, type: 'fee' })).toBe(2000);
  });

  test('returns null when the fee cannot be priced', () => {
    expect(feePriceFor({ catalogue: [], type: 'fee' })).toBeNull();
    expect(feePriceFor({ catalogue: CATALOGUE, type: 'savings' })).toBeNull();
  });
});

describe('findUnderpaidFees', () => {
  const check = (allocations) => findUnderpaidFees({ allocations, priceFor });

  test('refuses the live exploit: NGN1 against a NGN1,500 fee', () => {
    const short = check([{ type: 'fee', amount: 1 }, { type: 'savings', amount: 99 }]);
    expect(short).toHaveLength(1);
    expect(short[0]).toMatchObject({ type: 'fee', sent: 1, required: 1500 });
  });

  test('accepts the fee paid in full', () => {
    expect(check([{ type: 'fee', amount: 1500 }])).toEqual([]);
  });

  test('accepts an overpayment', () => {
    expect(check([{ type: 'fee', amount: 2000 }])).toEqual([]);
  });

  test('refuses a short fine', () => {
    const short = check([{ type: 'fine', amount: 500 }]);
    expect(short[0]).toMatchObject({ type: 'fine', required: 3000 });
  });

  test('a savings leg of any size is never a fee shortfall', () => {
    // Savings is the member's own money, so a small contribution is legitimate.
    expect(check([{ type: 'savings', amount: 1 }])).toEqual([]);
  });

  test('float dust within one kobo is tolerated', () => {
    expect(check([{ type: 'fee', amount: 1499.995 }])).toEqual([]);
  });

  test('a fee that cannot be priced is not blocked', () => {
    const unknown = findUnderpaidFees({
      allocations: [{ type: 'fee', amount: 1 }],
      priceFor: () => null,
    });
    expect(unknown).toEqual([]);
  });

  test('an overpayment remainder leg is not treated as a price', () => {
    // allocateFeeAmount covers the row, then emits the excess with no fee_id.
    // Checking that excess against the catalogue would reject a valid payment.
    const short = check([
      { type: 'fee', amount: 1500, fee_id: 'row-1' },
      { type: 'fee', amount: 500 },
    ]);
    expect(short).toEqual([]);
  });

  test('a lone untargeted fee leg is still priced and checked', () => {
    expect(check([{ type: 'fee', amount: 1 }])[0]).toMatchObject({ required: 1500 });
  });

  test('reports every underpaid leg', () => {
    const short = check([
      { type: 'fee', amount: 1 },
      { type: 'fine', amount: 1 },
    ]);
    expect(short.map((s) => s.type).sort()).toEqual(['fee', 'fine']);
  });
});
