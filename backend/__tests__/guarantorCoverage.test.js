/**
 * Guarantor coverage rules.
 *
 * The numbers here come from the loan products in lib/loanPolicy.js: a 3x
 * product on ₦100,000 of savings allows a ₦300,000 principal. The interest
 * figure is the shape of total_repayment, not a specific product rate.
 */
const {
  outstandingFor,
  pledgePerGuarantor,
  pledgedAmount,
  assessCoverage,
  coverageMessage,
} = require('../src/lib/guarantorCoverage');

describe('outstandingFor', () => {
  test('prefers the live remaining balance', () => {
    expect(outstandingFor({ remaining_balance: 250000, total_repayment: 350000, amount: 300000 })).toBe(250000);
  });

  test('falls back to total repayment when no repayment has been made', () => {
    expect(outstandingFor({ remaining_balance: null, total_repayment: 350000, amount: 300000 })).toBe(350000);
  });

  test('falls back to the principal last', () => {
    expect(outstandingFor({ amount: 300000 })).toBe(300000);
  });

  test('treats a missing loan as zero rather than NaN', () => {
    expect(outstandingFor(null)).toBe(0);
  });
});

describe('pledgePerGuarantor', () => {
  test('splits the gap evenly', () => {
    expect(pledgePerGuarantor(250000, 3)).toBe(83333.34);
  });

  test('rounds up so three pledges always cover the gap', () => {
    const each = pledgePerGuarantor(250000, 3);
    expect(Math.round(each * 3 * 100)).toBeGreaterThanOrEqual(25000000);
  });

  test('refuses to divide by zero guarantors', () => {
    expect(pledgePerGuarantor(250000, 0)).toBe(0);
  });
});

describe('pledgedAmount', () => {
  test('holds a guarantor\'s share when they can afford it', () => {
    expect(pledgedAmount(250000, 3, 120000)).toBe(83333.34);
  });

  test('caps the pledge at what the guarantor actually holds', () => {
    expect(pledgedAmount(250000, 3, 40000)).toBe(40000);
  });

  test('pledges nothing for a guarantor with no savings', () => {
    expect(pledgedAmount(250000, 3, 0)).toBe(0);
  });
});

describe('assessCoverage', () => {
  const loanAmount = 350000;

  test('is covered when the borrower and guarantors together meet the loan', () => {
    const result = assessCoverage({
      loanAmount,
      borrowerSavings: 100000,
      guarantors: [{ savings: 90000 }, { savings: 90000 }, { savings: 90000 }],
    });
    expect(result.covered).toBe(true);
    expect(result.shortfall).toBe(0);
  });

  test('reports the shortfall when guarantors cannot cover the gap', () => {
    const result = assessCoverage({
      loanAmount,
      borrowerSavings: 100000,
      guarantors: [{ savings: 20000 }, { savings: 20000 }, { savings: 20000 }],
    });
    expect(result.covered).toBe(false);
    expect(result.shortfall).toBe(190000);
    expect(result.coveredAmount).toBe(160000);
  });

  test('does not count a guarantor with no savings as available', () => {
    const result = assessCoverage({
      loanAmount,
      borrowerSavings: 100000,
      guarantors: [{ savings: 250000 }, { savings: 0 }, { savings: 0 }],
    });
    expect(result.guarantorsAvailable).toBe(1);
  });

  test('treats a loan with no guarantors as uncovered', () => {
    const result = assessCoverage({ loanAmount, borrowerSavings: 100000, guarantors: [] });
    expect(result.covered).toBe(false);
    expect(result.shortfall).toBe(250000);
  });

  test('is covered when the borrower alone holds enough', () => {
    const result = assessCoverage({ loanAmount, borrowerSavings: 400000, guarantors: [] });
    expect(result.covered).toBe(true);
  });
});

describe('coverageMessage', () => {
  test('names the shortfall and both ways to close it', () => {
    const message = coverageMessage({
      shortfall: 190000,
      coveredAmount: 160000,
      requiredAmount: 350000,
    });
    expect(message).toContain('₦190,000');
    expect(message).toContain('smaller amount');
    expect(message).toContain('guarantors with more savings');
  });
});
