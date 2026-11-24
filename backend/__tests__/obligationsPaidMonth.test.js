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
  // A direct-deposit member, so the monthly administrative fee is theirs to pay
  // in the app. `memberFeeRows` empty means the billing worker has not yet
  // written this month's row - the fee is still owed, which is the point of
  // `administrative_fee_due`.
  const base = () => ({
    monthly_savings: 5000,
    monthly_administrative_fee: 1500,
    loans: [],
    fines: [],
    fees: [],
    memberFeeRows: [],
  });

  test('unpaid month keeps the savings due and total as before', () => {
    const out = applyPaidMonthRule(base(), { paidThisMonth: false });
    expect(out.month_paid_savings).toBe(false);
    expect(out.savings_due).toBe(5000);
    expect(out.next_month_savings).toBe(0);
    // Savings plus the monthly administrative fee, which is owed whether or not
    // the billing worker has written a row for it yet.
    expect(out.total_due).toBe(6500);
  });

  test('paid month zeroes the savings due and moves it to next month', () => {
    const out = applyPaidMonthRule(base(), { paidThisMonth: true });
    expect(out.month_paid_savings).toBe(true);
    expect(out.savings_due).toBe(0);
    expect(out.next_month_savings).toBe(5000);
    // The savings is settled but this month's administrative fee is not: the
    // two are billed separately and paying one does not clear the other.
    expect(out.total_due).toBe(1500);
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
    expect(out.total_due).toBe(12000 + 500 + 250 + 1500);
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
    expect(out.total_due).toBe(17000 + 1500);
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
    expect(out.total_due).toBe(17500 + 1500);
  });

  test('a member who joined this month is not yet due', () => {
    const out = applyPaidMonthRule(base(), {
      paidThisMonth: false,
      joinedThisMonth: true,
    });
    expect(out.joined_this_month).toBe(true);
    expect(out.month_paid_savings).toBe(false);
    expect(out.savings_due).toBe(0);
    // The contribution is not yet due, but the monthly fee for the month they
    // joined in is - the billing worker bills a joiner for their join month.
    expect(out.total_due).toBe(1500);
    // The standing amount is not "next month's" either — they simply haven't
    // started yet, so the app should show the neutral all-caught-up copy.
    expect(out.next_month_savings).toBe(0);
  });

  test('a new member still owes fines and fees already on their account', () => {
    const out = applyPaidMonthRule(
      {
        monthly_savings: 5000,
        loans: [],
        fines: [{ amount: 500 }],
        fees: [{ amount: 250 }],
      },
      { paidThisMonth: false, joinedThisMonth: true }
    );
    expect(out.savings_due).toBe(0);
    expect(out.total_due).toBe(750 + 1500);
  });

  test('paid status wins over a join date in the same month', () => {
    const out = applyPaidMonthRule(base(), {
      paidThisMonth: true,
      joinedThisMonth: true,
    });
    expect(out.month_paid_savings).toBe(true);
    expect(out.next_month_savings).toBe(5000);
    expect(out.total_due).toBe(1500);
  });

  test('an exempt member owes no administrative fee', () => {
    const out = applyPaidMonthRule(
      { ...base(), administrative_fee_exempt: true },
      { paidThisMonth: false },
    );
    expect(out.administrative_fee_due).toBe(0);
    expect(out.total_due).toBe(5000);
  });

  test('the fee is not counted twice once this month is billed', () => {
    const out = applyPaidMonthRule(
      {
        ...base(),
        fees: [{ id: 'mf1', label: 'Administrative Fee', amount: 1500 }],
        administrative_fee_rows: [{ billing_month: '2026-11', amount: 1500 }],
      },
      { paidThisMonth: false, now: new Date(2026, 10, 20) },
    );
    expect(out.administrative_fee_due).toBe(0);
    // 5000 savings + the one billed fee row, which is already in `fees`.
    expect(out.total_due).toBe(6500);
  });
});

describe('savings-month comparison', () => {
  const { isSameMonth } = require('../src/routes/wallet');

  test('treats two dates in the same calendar month as paid', () => {
    expect(isSameMonth('2026-09-13T00:00:00Z', new Date(2026, 8, 29))).toBe(true);
    expect(isSameMonth(new Date(2026, 8, 1), new Date(2026, 8, 30))).toBe(true);
  });

  test('a last deposit from a previous month is not this month', () => {
    expect(isSameMonth('2026-08-31T23:59:59Z', new Date(2026, 8, 1))).toBe(false);
    expect(isSameMonth(new Date(2026, 8, 29), new Date(2026, 9, 1))).toBe(false);
  });

  test('a missing or unparseable date never counts as paid', () => {
    expect(isSameMonth(null, new Date(2026, 8, 29))).toBe(false);
    expect(isSameMonth(undefined, new Date(2026, 8, 29))).toBe(false);
    expect(isSameMonth('not-a-date', new Date(2026, 8, 29))).toBe(false);
  });
});
