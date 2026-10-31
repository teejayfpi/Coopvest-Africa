const loanPolicy = require('../src/lib/loanPolicy');

describe('loanPolicy', () => {
  describe('multiplierFor', () => {
    it('returns 3 for Quick/Flexi/Stable loans', () => {
      expect(loanPolicy.multiplierFor('Quick Loan')).toBe(3);
      expect(loanPolicy.multiplierFor('Flexi Loan')).toBe(3);
      expect(loanPolicy.multiplierFor('Stable Loan (12 months)')).toBe(3);
      expect(loanPolicy.multiplierFor('Stable Loan (18 months)')).toBe(3);
    });

    it('returns 4 for Premium Loan and 5 for Maxi Loan', () => {
      expect(loanPolicy.multiplierFor('Premium Loan')).toBe(4);
      expect(loanPolicy.multiplierFor('Maxi Loan')).toBe(5);
    });

    it('falls back to 3 for unknown types', () => {
      expect(loanPolicy.multiplierFor('Some Future Loan')).toBe(3);
      expect(loanPolicy.multiplierFor(undefined)).toBe(3);
    });
  });

  describe('maxLoanAmount', () => {
    it('caps Quick Loan at 3x savings', () => {
      expect(loanPolicy.maxLoanAmount('Quick Loan', 100000)).toBe(300000);
    });

    it('caps Premium Loan at 4x savings', () => {
      expect(loanPolicy.maxLoanAmount('Premium Loan', 100000)).toBe(400000);
    });

    it('caps Maxi Loan at 5x savings', () => {
      expect(loanPolicy.maxLoanAmount('Maxi Loan', 100000)).toBe(500000);
    });

    it('returns 0 when the member has no savings', () => {
      expect(loanPolicy.maxLoanAmount('Maxi Loan', 0)).toBe(0);
      expect(loanPolicy.maxLoanAmount('Quick Loan', null)).toBe(0);
    });
  });

  describe('status sets', () => {
    it('blocks new applications for overdue, defaulted and in_recovery loans', () => {
      expect(loanPolicy.DEFAULT_BLOCKING_STATUSES).toEqual(
        expect.arrayContaining(['overdue', 'defaulted', 'in_recovery']),
      );
    });

    it('counts approved/active/repaying/overdue/in_recovery as active for the reduction guard', () => {
      expect(loanPolicy.ACTIVE_LOAN_STATUSES).toEqual(
        expect.arrayContaining(['approved', 'active', 'repaying', 'overdue', 'in_recovery']),
      );
      expect(loanPolicy.ACTIVE_LOAN_STATUSES).not.toContain('completed');
      expect(loanPolicy.ACTIVE_LOAN_STATUSES).not.toContain('rejected');
    });
  });

  describe('monthsBetween', () => {
    it('counts whole months between two dates', () => {
      expect(loanPolicy.monthsBetween('2026-01-15', new Date('2026-07-15'))).toBe(6);
      expect(loanPolicy.monthsBetween('2026-01-15', new Date('2026-07-14'))).toBe(5);
      expect(loanPolicy.monthsBetween('2026-01-15', new Date('2026-01-15'))).toBe(0);
    });

    it('treats a missing or invalid date as zero months', () => {
      expect(loanPolicy.monthsBetween(null)).toBe(0);
      expect(loanPolicy.monthsBetween('not-a-date')).toBe(0);
    });

    it('never returns a negative count for a future date', () => {
      expect(loanPolicy.monthsBetween('2030-01-01', new Date('2026-01-01'))).toBe(0);
    });
  });

  describe('countContributionMonths', () => {
    it('counts distinct months with a successful contribution', () => {
      const months = loanPolicy.countContributionMonths([
        { status: 'successful', contribution_month: '2026-01' },
        { status: 'successful', contribution_month: '2026-01' },
        { status: 'successful', contribution_month: '2026-02' },
      ]);
      expect(months).toBe(2);
    });

    it('ignores pending, failed and rejected contributions', () => {
      const months = loanPolicy.countContributionMonths([
        { status: 'pending', contribution_month: '2026-01' },
        { status: 'failed', contribution_month: '2026-02' },
        { status: 'rejected', contribution_month: '2026-03' },
      ]);
      expect(months).toBe(0);
    });

    it('falls back to the created_at month when contribution_month is absent', () => {
      const months = loanPolicy.countContributionMonths([
        { status: 'successful', contribution_month: null, created_at: '2026-04-09T10:00:00Z' },
      ]);
      expect(months).toBe(1);
    });

    it('is zero for an empty or missing list', () => {
      expect(loanPolicy.countContributionMonths([])).toBe(0);
      expect(loanPolicy.countContributionMonths(undefined)).toBe(0);
    });
  });

  describe('minEligibilityDisabled', () => {
    const original = process.env.LOAN_MIN_ELIGIBILITY_DISABLED;
    afterEach(() => {
      if (original === undefined) delete process.env.LOAN_MIN_ELIGIBILITY_DISABLED;
      else process.env.LOAN_MIN_ELIGIBILITY_DISABLED = original;
    });

    it('is off by default, so the rule is enforced', () => {
      delete process.env.LOAN_MIN_ELIGIBILITY_DISABLED;
      expect(loanPolicy.minEligibilityDisabled()).toBe(false);
    });

    it('is only disabled by the exact string "true"', () => {
      process.env.LOAN_MIN_ELIGIBILITY_DISABLED = 'true';
      expect(loanPolicy.minEligibilityDisabled()).toBe(true);
      process.env.LOAN_MIN_ELIGIBILITY_DISABLED = '1';
      expect(loanPolicy.minEligibilityDisabled()).toBe(false);
    });
  });
});
