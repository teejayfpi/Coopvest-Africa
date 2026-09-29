const {
  applyPaidMonthRule,
  monthKey,
  nextMonthKey,
} = require('../src/routes/wallet');

/**
 * A member who has paid this month's contribution must stop seeing it as
 * "Total due this month". The standing amount moves to the next-month
 * expectation instead. This rule is pure so it can be pinned without a DB.
 */
describe('obligations paid-month rule', () => {
  const base = () => ({
    monthly_savings: 5000,
    loans: [],
    fines: [],
    fees: [],
  });

  test('unpaid month keeps the savings due and total as before', () => {
    const out = applyPaidMonthRule(base(), { paidThisMonth: false });
    expect(out.month_paid_savings).toBe(false);
    expect(out.savings_due).toBe(5000);
    expect(out.next_month_savings).toBe(0);
    expect(out.total_due).toBe(5000);
  });

  test('paid month zeroes the savings due and moves it to next month', () => {
    const out = applyPaidMonthRule(base(), { paidThisMonth: true });
    expect(out.month_paid_savings).toBe(true);
    expect(out.savings_due).toBe(0);
    expect(out.next_month_savings).toBe(5000);
    // Nothing else is owed, so the member is square for this month.
    expect(out.total_due).toBe(0);
  });

  test('a paid member still owes fines, fees and loan repayments', () => {
    const out = applyPaidMonthRule(
      {
        monthly_savings: 5000,
        loans: [{ monthly_repayment: 12000 }],
        fines: [{ amount: 500 }],
        fees: [{ amount: 250 }],
      },
      { paidThisMonth: true }
    );
    expect(out.savings_due).toBe(0);
    expect(out.total_due).toBe(12000 + 500 + 250);
    expect(out.next_month_savings).toBe(5000);
  });

  test('an unpaid member owes savings plus everything else', () => {
    const out = applyPaidMonthRule(
      {
        monthly_savings: 5000,
        loans: [{ monthly_repayment: 12000 }],
        fines: [],
        fees: [],
      },
      { paidThisMonth: false }
    );
    expect(out.total_due).toBe(17000);
  });

  test('month keys are zero-padded and roll over the year', () => {
    expect(monthKey(new Date(2026, 0, 15))).toBe('2026-01');
    expect(monthKey(new Date(2026, 8, 29))).toBe('2026-09');
    expect(nextMonthKey(new Date(2026, 8, 29))).toBe('2026-10');
    expect(nextMonthKey(new Date(2026, 11, 31))).toBe('2027-01');
  });

  test('string amounts are coerced, not concatenated', () => {
    const out = applyPaidMonthRule(
      {
        monthly_savings: 5000,
        loans: [{ monthly_repayment: '12000' }],
        fines: [{ amount: '500' }],
        fees: [],
      },
      { paidThisMonth: false }
    );
    expect(out.total_due).toBe(17500);
  });
});
