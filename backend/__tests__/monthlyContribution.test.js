const { resolveMonthlyContribution } = require('../src/lib/monthlyContribution');

describe('resolveMonthlyContribution', () => {
  test('prefers the contribution plan over the savings mirror', () => {
    // A member who raised their contribution: plan is current, savings lags.
    expect(resolveMonthlyContribution({ planAmount: 20000, savingsAmount: 5000 })).toBe(20000);
  });

  test('falls back to savings when there is no plan row', () => {
    expect(resolveMonthlyContribution({ savingsAmount: 7500 })).toBe(7500);
  });

  test('treats zero and missing values as unset', () => {
    expect(resolveMonthlyContribution({ planAmount: 0, savingsAmount: 7500 })).toBe(7500);
    expect(resolveMonthlyContribution({ planAmount: null, savingsAmount: 0 })).toBe(0);
    expect(resolveMonthlyContribution()).toBe(0);
  });

  test('parses numeric strings coming back from PostgREST', () => {
    expect(resolveMonthlyContribution({ planAmount: '12000' })).toBe(12000);
  });

  test('ignores non-numeric and negative values', () => {
    expect(resolveMonthlyContribution({ planAmount: 'n/a', savingsAmount: -100 })).toBe(0);
  });
});
