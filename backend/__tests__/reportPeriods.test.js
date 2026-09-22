const p = require('../src/lib/reportPeriods');

/**
 * Period resolution underpins every comparison. A wrong boundary silently
 * shifts money between periods, so the edges (month/quarter ends, ISO week 1
 * straddling New Year, leap days) are pinned explicitly here.
 */
describe('period resolution', () => {
  test('month spans the whole month', () => {
    expect(p.resolvePeriod({ type: 'month', year: 2026, month: 1 })).toMatchObject({
      start: '2026-01-01', end: '2026-01-31',
    });
  });

  test('February length follows the leap year', () => {
    expect(p.resolvePeriod({ type: 'month', year: 2026, month: 2 }).end).toBe('2026-02-28');
    expect(p.resolvePeriod({ type: 'month', year: 2028, month: 2 }).end).toBe('2028-02-29');
  });

  test('quarter spans three months', () => {
    expect(p.resolvePeriod({ type: 'quarter', year: 2026, quarter: 1 })).toMatchObject({
      start: '2026-01-01', end: '2026-03-31',
    });
    expect(p.resolvePeriod({ type: 'quarter', year: 2026, quarter: 4 })).toMatchObject({
      start: '2026-10-01', end: '2026-12-31',
    });
  });

  test('year spans 1 Jan to 31 Dec', () => {
    expect(p.resolvePeriod({ type: 'year', year: 2025 })).toMatchObject({
      start: '2025-01-01', end: '2025-12-31',
    });
  });

  test('weeks are Monday to Sunday', () => {
    const w3 = p.resolvePeriod({ type: 'week', year: 2026, week: 3 });
    expect(w3.start).toBe('2026-01-12');
    expect(w3.end).toBe('2026-01-18');
    // 2026-01-12 really is a Monday in UTC.
    expect(new Date(`${w3.start}T00:00:00Z`).getUTCDay()).toBe(1);
  });

  test('ISO week 1 may start in the previous calendar year', () => {
    // This is the case that makes naive week enumeration return nothing.
    const w1 = p.resolvePeriod({ type: 'week', year: 2026, week: 1 });
    expect(w1.start).toBe('2025-12-29');
    expect(w1.end).toBe('2026-01-04');
  });

  test('custom periods accept any inclusive range', () => {
    const c = p.resolvePeriod({ type: 'custom', start: '2026-03-01', end: '2026-03-15' });
    expect(c).toMatchObject({ start: '2026-03-01', end: '2026-03-15', days: 15 });
  });

  test('shorthands parse', () => {
    expect(p.resolvePeriod({ type: 'month', from: '2026-01' }).start).toBe('2026-01-01');
    expect(p.resolvePeriod({ type: 'quarter', from: '2026-Q1' }).start).toBe('2026-01-01');
    expect(p.resolvePeriod({ type: 'year', from: '2025' }).start).toBe('2025-01-01');
    expect(p.resolvePeriod({ type: 'week', from: '2026-W03' }).start).toBe('2026-01-12');
  });

  test('invalid input is rejected rather than guessed at', () => {
    expect(() => p.resolvePeriod({ type: 'fortnight', year: 2026 })).toThrow(p.PeriodError);
    expect(() => p.resolvePeriod({ type: 'month', year: 2026, month: 13 })).toThrow(p.PeriodError);
    expect(() => p.resolvePeriod({ type: 'quarter', year: 2026, quarter: 5 })).toThrow(p.PeriodError);
    expect(() => p.resolvePeriod({ type: 'week', year: 2026, week: 0 })).toThrow(p.PeriodError);
    expect(() => p.resolvePeriod({ type: 'custom', start: '2026-03-15', end: '2026-03-01' })).toThrow(p.PeriodError);
    expect(() => p.resolvePeriod({ type: 'month', from: 'nonsense' })).toThrow(p.PeriodError);
  });
});

describe('adjacent periods', () => {
  test('previous month crosses the year boundary', () => {
    const prev = p.previousPeriod(p.resolvePeriod({ type: 'month', year: 2026, month: 1 }));
    expect(prev.label).toBe('December 2025');
    expect(prev.start).toBe('2025-12-01');
  });

  test('previous quarter crosses the year boundary', () => {
    const prev = p.previousPeriod(p.resolvePeriod({ type: 'quarter', year: 2026, quarter: 1 }));
    expect(prev.label).toBe('Q4 2025');
    expect(prev.start).toBe('2025-10-01');
  });

  test('previous week is exactly seven days earlier', () => {
    const w3 = p.resolvePeriod({ type: 'week', year: 2026, week: 3 });
    const prev = p.previousPeriod(w3);
    expect(prev.start).toBe('2026-01-05');
    expect(prev.end).toBe('2026-01-11');
  });

  test('previous custom window keeps its own length and abuts the original', () => {
    // 1-15 March is 15 days, so the previous window is 13-27 February.
    const c = p.resolvePeriod({ type: 'custom', start: '2026-03-01', end: '2026-03-15' });
    const prev = p.previousPeriod(c);
    expect(prev.end).toBe('2026-02-28');
    expect(prev.start).toBe('2026-02-14');
    expect(p.rangeDays(prev)).toBe(15);
  });

  test('year-on-year maps to the same window a year earlier', () => {
    const yoy = p.previousYearPeriod(p.resolvePeriod({ type: 'quarter', year: 2026, quarter: 1 }));
    expect(yoy.start).toBe('2025-01-01');
    expect(yoy.end).toBe('2025-03-31');
  });

  test('year-on-year clamps 29 February instead of overflowing to 1 March', () => {
    const feb29 = p.resolvePeriod({ type: 'custom', start: '2028-02-29', end: '2028-02-29' });
    const yoy = p.previousYearPeriod(feb29);
    expect(yoy.start).toBe('2027-02-28');
  });
});

describe('period enumeration', () => {
  test('lists 12 months and 4 quarters', () => {
    expect(p.enumeratePeriods('month', 2026)).toHaveLength(12);
    expect(p.enumeratePeriods('quarter', 2026)).toHaveLength(4);
  });

  test('lists 52 or 53 ISO weeks, never zero', () => {
    // Regression: comparing calendar year instead of ISO week-year made this
    // return an empty list for any year whose week 1 starts in December.
    expect(p.enumeratePeriods('week', 2026).length).toBe(53);
    expect(p.enumeratePeriods('week', 2025).length).toBe(52);
    expect(p.enumeratePeriods('week', 2024).length).toBeGreaterThanOrEqual(52);
  });

  test('week 1 of the listed year is included and correctly labelled', () => {
    const weeks = p.enumeratePeriods('week', 2026);
    expect(weeks[0].label).toBe('2026 Week 1');
    expect(weeks[0].start).toBe('2025-12-29');
  });
});

describe('range membership', () => {
  const jan = p.resolvePeriod({ type: 'month', year: 2026, month: 1 });

  test('includes both boundary days inclusive', () => {
    expect(p.inRange('2026-01-01T00:00:00Z', jan)).toBe(true);
    expect(p.inRange('2026-01-31T23:59:00Z', jan)).toBe(true);
  });

  test('excludes the days either side', () => {
    expect(p.inRange('2025-12-31T23:59:59Z', jan)).toBe(false);
    expect(p.inRange('2026-02-01T00:00:00Z', jan)).toBe(false);
  });

  test('a missing or invalid date is not counted', () => {
    expect(p.inRange(null, jan)).toBe(false);
    expect(p.inRange('not-a-date', jan)).toBe(false);
  });
});
