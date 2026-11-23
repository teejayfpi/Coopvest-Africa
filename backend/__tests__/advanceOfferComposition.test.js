const { applyPaidMonthRule } = require('../src/routes/wallet');

/**
 * What the "pay a month in advance" offer is made of.
 *
 * The contribution recurs, so it is always part of the price. The administrative
 * fee recurs too, but a salary-deduction member has it withheld from pay, so
 * including it would charge them twice. Fines are owed now whatever month is
 * being paid for, so they belong in the same payment.
 */
describe('advance offer composition', () => {
  const base = (overrides = {}) => ({
    monthly_savings: 5000,
    monthly_administrative_fee: 1500,
    administrative_fee_exempt: false,
    loans: [],
    fines: [],
    fees: [],
    ...overrides,
  });

  test('includes the contribution and the administrative fee', () => {
    const out = applyPaidMonthRule(base(), { paidThisMonth: true });
    expect(out.advance.savings).toBe(5000);
    expect(out.advance.administrative_fee).toBe(1500);
    expect(out.advance.fines).toEqual([]);
    expect(out.advance.total).toBe(6500);
  });

  test('includes outstanding fines', () => {
    const out = applyPaidMonthRule(
      base({
        fines: [
          { id: 'f1', label: 'Late Loan Repayment Fine', amount: 3000 },
          { id: 'f2', label: 'Missed Contribution Fine', amount: 500 },
        ],
      }),
      { paidThisMonth: true },
    );
    expect(out.advance.fines).toHaveLength(2);
    expect(out.advance.fines_total).toBe(3500);
    // ₦5,000 contribution + ₦1,500 fee + ₦3,500 fines.
    expect(out.advance.total).toBe(10000);
  });

  test('keeps each fine id so the payment can settle the exact rows', () => {
    const out = applyPaidMonthRule(
      base({ fines: [{ id: 'f1', label: 'Fine', amount: 3000 }] }),
      { paidThisMonth: true },
    );
    expect(out.advance.fines[0].id).toBe('f1');
  });

  test('omits the fee for a salary-deduction member', () => {
    // The employer withholds it, so the offer must not ask for it as well.
    const out = applyPaidMonthRule(
      base({ administrative_fee_exempt: true }),
      { paidThisMonth: true },
    );
    expect(out.advance.administrative_fee).toBe(0);
    expect(out.advance.total).toBe(5000);
  });

  test('a salary-deduction member still owes fines in the advance', () => {
    const out = applyPaidMonthRule(
      base({
        administrative_fee_exempt: true,
        fines: [{ id: 'f1', label: 'Late Loan Repayment Fine', amount: 3000 }],
      }),
      { paidThisMonth: true },
    );
    expect(out.advance.administrative_fee).toBe(0);
    expect(out.advance.total).toBe(8000);
  });

  test('prices the first unpaid month, not blindly the next one', () => {
    const out = applyPaidMonthRule(base(), {
      paidThisMonth: true,
      paidMonths: ['2026-12', '2027-01'],
      now: new Date('2026-11-15T00:00:00Z'),
    });
    expect(out.advance.month).toBe('2027-02');
  });
});
