const { resolveMonthlyContribution, resolveSeedAmount } = require('../src/lib/monthlyContribution');

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

describe('resolveSeedAmount', () => {
  // A new plan used to be seeded with the bare ₦5,000 minimum, so a member who
  // pledged more saw the minimum in "Your obligations this month".
  test('seeds a new plan from the amount chosen at sign-up', () => {
    expect(resolveSeedAmount({ kycAmount: 20000, minimum: 5000 })).toBe(20000);
    expect(resolveSeedAmount({ kycAmount: '10000', minimum: 5000 })).toBe(10000);
  });

  test('never seeds below the platform minimum', () => {
    expect(resolveSeedAmount({ kycAmount: 1000, minimum: 5000 })).toBe(5000);
  });

  test('falls back to the minimum when no choice was recorded', () => {
    expect(resolveSeedAmount({ minimum: 5000 })).toBe(5000);
    expect(resolveSeedAmount({ kycAmount: null, minimum: 5000 })).toBe(5000);
    expect(resolveSeedAmount({ kycAmount: 'n/a', minimum: 5000 })).toBe(5000);
    expect(resolveSeedAmount({ kycAmount: 0, minimum: 5000 })).toBe(5000);
  });
});
