/**
 * Paying next month in advance.
 *
 * A contribution is recorded against a billing month, not the instant it was
 * paid. Before this, the month was always taken from the payment date, so an
 * early payment credited the current month — the member paid twice for one
 * month and still owed the next.
 */

const {
  resolveTargetMonth,
  monthKey,
  nextMonthKey,
  monthKeyOffset,
  isValidMonthKey,
  maxAdvanceMonths,
} = require('../src/lib/billingMonth');
const { applyPaidMonthRule } = require('../src/routes/wallet');

const NOW = new Date(2026, 10, 20); // 20 Nov 2026

describe('resolving the month a payment settles', () => {
  test('an absent month means the current month', () => {
    expect(resolveTargetMonth(undefined, NOW)).toEqual({ ok: true, month: '2026-11' });
    expect(resolveTargetMonth(null, NOW)).toEqual({ ok: true, month: '2026-11' });
    expect(resolveTargetMonth('', NOW)).toEqual({ ok: true, month: '2026-11' });
  });

  test('the next month is accepted', () => {
    expect(resolveTargetMonth('2026-12', NOW)).toEqual({ ok: true, month: '2026-12' });
  });

  test('a past month is rejected', () => {
    // Arrears are settled through the outstanding balance, not by back-dating a
    // fresh payment onto a month that is already in default.
    const r = resolveTargetMonth('2026-10', NOW);
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/past/);
  });

  test('a malformed month is rejected', () => {
    for (const bad of ['2026-13', '2026-1', '26-01', 'December', '2026-00']) {
      expect(resolveTargetMonth(bad, NOW).ok).toBe(false);
    }
  });

  test('a month beyond the advance limit is rejected', () => {
    const tooFar = monthKeyOffset(NOW, maxAdvanceMonths() + 1);
    const r = resolveTargetMonth(tooFar, NOW);
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/months ahead/);
  });

  test('the furthest allowed month is accepted', () => {
    const limit = monthKeyOffset(NOW, maxAdvanceMonths());
    expect(resolveTargetMonth(limit, NOW)).toEqual({ ok: true, month: limit });
  });

  test('month keys roll over the year boundary', () => {
    expect(nextMonthKey(new Date(2026, 11, 5))).toBe('2027-01');
    expect(monthKeyOffset(new Date(2026, 0, 31), -1)).toBe('2025-12');
  });

  test('only YYYY-MM is a valid key', () => {
    expect(isValidMonthKey('2026-12')).toBe(true);
    expect(isValidMonthKey('2026-12-01')).toBe(false);
    expect(isValidMonthKey(202612)).toBe(false);
  });
});

describe('the advance offer targets the first unpaid month', () => {
  const base = {
    monthly_savings: 5000,
    monthly_administrative_fee: 1500,
    loans: [],
    fines: [],
    fees: [],
  };

  test('offers next month and prices the fee with it', () => {
    const o = applyPaidMonthRule({ ...base }, { paidThisMonth: true, now: NOW });
    expect(o.advance.month).toBe('2026-12');
    expect(o.advance.savings).toBe(5000);
    expect(o.advance.administrative_fee).toBe(1500);
    // The member pays the contribution and the fee together.
    expect(o.advance.total).toBe(6500);
  });

  test('skips months that are already paid', () => {
    const o = applyPaidMonthRule(
      { ...base },
      { paidThisMonth: true, paidMonths: ['2026-12', '2027-01'], now: NOW },
    );
    expect(o.advance.month).toBe('2027-02');
  });

  test('reports whether the current month is already settled', () => {
    const unpaid = applyPaidMonthRule({ ...base }, { paidThisMonth: false, now: NOW });
    expect(unpaid.advance.current_month_paid).toBe(false);

    const paid = applyPaidMonthRule({ ...base }, { paidThisMonth: true, now: NOW });
    expect(paid.advance.current_month_paid).toBe(true);
  });

  test('the current month is never offered as an advance month', () => {
    const o = applyPaidMonthRule(
      { ...base },
      { paidThisMonth: false, paidMonths: ['2026-11'], now: NOW },
    );
    expect(o.advance.month).toBe('2026-12');
  });
});

describe('the fee is part of what is due now', () => {
  test('total due includes outstanding fees', () => {
    const o = applyPaidMonthRule(
      {
        monthly_savings: 5000,
        monthly_administrative_fee: 1500,
        loans: [],
        fines: [],
        fees: [{ id: 'mf1', label: 'Administrative Fee', amount: 1500 }],
      },
      { paidThisMonth: false, now: NOW },
    );
    expect(o.total_due).toBe(6500);
  });

  test('month keys agree with the wallet current month', () => {
    const o = applyPaidMonthRule(
      { monthly_savings: 5000, monthly_administrative_fee: 1500, loans: [], fines: [], fees: [] },
      { paidThisMonth: false, now: NOW },
    );
    expect(o.current_month).toBe(monthKey(NOW));
  });
});
