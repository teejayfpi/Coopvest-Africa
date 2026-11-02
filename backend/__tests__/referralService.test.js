/**
 * Tests for ReferralService — financial logic.
 *
 * These exercise the REAL service, not a copy of it. The previous version of
 * this file defined its own `ReferralServiceTestHelper` with a different rate
 * table ('PERSONAL': 15, 'EMERGENCY': 12, 'BUSINESS': 18) and asserted against
 * that, so the loan maths that actually writes to production `loans` rows had
 * no coverage at all — which is how a reducing-balance instalment and a
 * simple-interest total shipped side by side and disagreed.
 */

const referralService = require('../src/services/referralService');

describe('ReferralService.calculateInterestWithBonus (real service)', () => {
  describe('base rates match the product table', () => {
    it.each([
      ['Quick Loan', 7.5],
      ['Flexi Loan', 7.0],
      ['Stable Loan (12 months)', 5.0],
      ['Stable Loan (18 months)', 7.0],
      ['Premium Loan', 14.0],
      ['Maxi Loan', 19.0],
    ])('%s carries a %s%% base rate', (loanType, rate) => {
      expect(referralService.getBaseInterestRate(loanType)).toBe(rate);
    });

    it('falls back to 7.5%% for an unknown product', () => {
      expect(referralService.getBaseInterestRate('Some Future Loan')).toBe(7.5);
    });
  });

  describe('instalment and total reconcile', () => {
    // The regression this file exists to prevent: the instalment was a
    // reducing-balance EMI while the total was simple interest, so
    // `monthly × tenure` did not equal `total` — short by ₦20,439 on a
    // ₦900,000 / 5% / 12-month loan, and over by ₦129,617 on a Maxi loan.
    const cases = [
      ['Quick Loan', 900000, 4],
      ['Flexi Loan', 500000, 6],
      ['Stable Loan (12 months)', 900000, 12],
      ['Stable Loan (18 months)', 750000, 18],
      ['Premium Loan', 2000000, 24],
      ['Maxi Loan', 1000000, 36],
    ];

    it.each(cases)(
      '%s: monthlyRepayment × tenure === totalRepayment (%i / %i months)',
      (loanType, amount, tenure) => {
        const r = referralService.calculateInterestWithBonus(loanType, amount, tenure, 0);
        expect(r.monthlyRepaymentAfterBonus * tenure).toBeCloseTo(r.totalRepayment, 2);
      },
    );

    it.each(cases)(
      '%s: the pre-bonus figures reconcile too',
      (loanType, amount, tenure) => {
        const r = referralService.calculateInterestWithBonus(loanType, amount, tenure, 0);
        expect(r.monthlyRepaymentBeforeBonus * tenure).toBeCloseTo(r.totalRepaymentBeforeBonus, 2);
      },
    );

    it('reconciles with a referral bonus applied', () => {
      const r = referralService.calculateInterestWithBonus('Stable Loan (12 months)', 900000, 12, 1);
      expect(r.monthlyRepaymentAfterBonus * 12).toBeCloseTo(r.totalRepayment, 2);
      expect(r.monthlyRepaymentBeforeBonus * 12).toBeCloseTo(r.totalRepaymentBeforeBonus, 2);
    });
  });

  describe('known figures', () => {
    it('prices ₦900,000 over 12 months at 5% as ₦945,000 total / ₦78,750 monthly', () => {
      const r = referralService.calculateInterestWithBonus('Stable Loan (12 months)', 900000, 12, 0);
      expect(r.totalRepayment).toBeCloseTo(945000, 2);
      expect(r.monthlyRepaymentAfterBonus).toBeCloseTo(78750, 2);
    });

    it('prices ₦900,000 over 4 months at 7.5% as ₦967,500 total / ₦241,875 monthly', () => {
      const r = referralService.calculateInterestWithBonus('Quick Loan', 900000, 4, 0);
      expect(r.totalRepayment).toBeCloseTo(967500, 2);
      expect(r.monthlyRepaymentAfterBonus).toBeCloseTo(241875, 2);
    });
  });

  describe('referral bonus', () => {
    it('lowers both the total and the instalment', () => {
      const withBonus = referralService.calculateInterestWithBonus('Quick Loan', 500000, 4, 2);
      const withoutBonus = referralService.calculateInterestWithBonus('Quick Loan', 500000, 4, 0);
      expect(withBonus.effectiveInterestRate).toBe(5.5);
      expect(withBonus.totalRepayment).toBeLessThan(withoutBonus.totalRepayment);
      expect(withBonus.monthlyRepaymentAfterBonus).toBeLessThan(withoutBonus.monthlyRepaymentAfterBonus);
    });

    it('never drops below the product floor (half the base rate)', () => {
      const r = referralService.calculateInterestWithBonus('Premium Loan', 1000000, 24, 12);
      expect(r.effectiveInterestRate).toBe(7); // floor, not 2
      expect(r.minimumInterestFloor).toBe(7);
    });

    it('reports totalSavingsFromBonus as the difference between the two totals', () => {
      const r = referralService.calculateInterestWithBonus('Flexi Loan', 600000, 6, 1);
      expect(r.totalSavingsFromBonus).toBeCloseTo(r.totalRepaymentBeforeBonus - r.totalRepayment, 2);
      expect(r.totalSavingsFromBonus).toBeGreaterThan(0);
    });

    it('marks bonusApplied only when a bonus was passed', () => {
      expect(referralService.calculateInterestWithBonus('Quick Loan', 100000, 4, 0).bonusApplied).toBe(false);
      expect(referralService.calculateInterestWithBonus('Quick Loan', 100000, 4, 1).bonusApplied).toBe(true);
    });
  });

  describe('defensive tenure handling', () => {
    it('does not divide by zero for a zero or missing tenure', () => {
      const zero = referralService.calculateInterestWithBonus('Quick Loan', 100000, 0, 0);
      expect(Number.isFinite(zero.monthlyRepaymentAfterBonus)).toBe(true);
      const missing = referralService.calculateInterestWithBonus('Quick Loan', 100000, undefined, 0);
      expect(Number.isFinite(missing.monthlyRepaymentAfterBonus)).toBe(true);
    });
  });
});
