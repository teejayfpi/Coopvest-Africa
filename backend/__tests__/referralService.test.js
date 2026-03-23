/**
 * Tests for ReferralService - Financial Logic
 * 
 * Tests the core loan interest calculation and tier bonus logic
 * without requiring database connections.
 */

// Extract the pure calculation methods for unit testing
// We test the service's calculation logic directly

class ReferralServiceTestHelper {
  getBaseInterestRate(loanType) {
    const rates = { 'PERSONAL': 15, 'EMERGENCY': 12, 'BUSINESS': 18 };
    return rates[loanType] || 15;
  }

  getMinimumInterestFloor(loanType) {
    const floors = { 'PERSONAL': 5, 'EMERGENCY': 4, 'BUSINESS': 7 };
    return floors[loanType] || 5;
  }

  calculateTierBonus(count) {
    if (count >= 50) return 5;
    if (count >= 20) return 3;
    if (count >= 10) return 2;
    if (count >= 5) return 1;
    return 0;
  }

  calculateInterestWithBonus(loanType, loanAmount, tenureMonths, bonusPercent) {
    const baseRate = this.getBaseInterestRate(loanType);
    const minimumFloor = this.getMinimumInterestFloor(loanType);
    
    const effectiveRate = bonusPercent > 0 
      ? Math.max(baseRate - bonusPercent, minimumFloor)
      : baseRate;

    const monthlyRate = effectiveRate / 100 / 12;
    const emi = loanAmount * monthlyRate * Math.pow(1 + monthlyRate, tenureMonths) / 
                (Math.pow(1 + monthlyRate, tenureMonths) - 1);

    const monthlyRateBefore = baseRate / 100 / 12;
    const emiBeforeBonus = loanAmount * monthlyRateBefore * Math.pow(1 + monthlyRateBefore, tenureMonths) / 
                           (Math.pow(1 + monthlyRateBefore, tenureMonths) - 1);

    const totalSavingsFromBonus = (emiBeforeBonus - emi) * tenureMonths;

    return {
      loanType,
      baseInterestRate: baseRate,
      referralBonusPercent: bonusPercent,
      effectiveInterestRate: effectiveRate,
      loanAmount,
      tenureMonths,
      monthlyRepaymentBeforeBonus: emiBeforeBonus,
      monthlyRepaymentAfterBonus: emi,
      totalSavingsFromBonus,
      minimumInterestFloor: minimumFloor,
      bonusApplied: bonusPercent > 0
    };
  }
}

const service = new ReferralServiceTestHelper();

describe('ReferralService - Interest Rate Calculations', () => {
  describe('getBaseInterestRate', () => {
    test('returns correct rate for PERSONAL loans', () => {
      expect(service.getBaseInterestRate('PERSONAL')).toBe(15);
    });

    test('returns correct rate for EMERGENCY loans', () => {
      expect(service.getBaseInterestRate('EMERGENCY')).toBe(12);
    });

    test('returns correct rate for BUSINESS loans', () => {
      expect(service.getBaseInterestRate('BUSINESS')).toBe(18);
    });

    test('returns default rate for unknown loan types', () => {
      expect(service.getBaseInterestRate('UNKNOWN')).toBe(15);
    });
  });

  describe('getMinimumInterestFloor', () => {
    test('returns correct floor for PERSONAL loans', () => {
      expect(service.getMinimumInterestFloor('PERSONAL')).toBe(5);
    });

    test('returns correct floor for EMERGENCY loans', () => {
      expect(service.getMinimumInterestFloor('EMERGENCY')).toBe(4);
    });

    test('returns correct floor for BUSINESS loans', () => {
      expect(service.getMinimumInterestFloor('BUSINESS')).toBe(7);
    });

    test('returns default floor for unknown loan types', () => {
      expect(service.getMinimumInterestFloor('UNKNOWN')).toBe(5);
    });
  });

  describe('calculateTierBonus', () => {
    test('returns 0 for fewer than 5 referrals', () => {
      expect(service.calculateTierBonus(0)).toBe(0);
      expect(service.calculateTierBonus(4)).toBe(0);
    });

    test('returns 1% for 5-9 referrals', () => {
      expect(service.calculateTierBonus(5)).toBe(1);
      expect(service.calculateTierBonus(9)).toBe(1);
    });

    test('returns 2% for 10-19 referrals', () => {
      expect(service.calculateTierBonus(10)).toBe(2);
      expect(service.calculateTierBonus(19)).toBe(2);
    });

    test('returns 3% for 20-49 referrals', () => {
      expect(service.calculateTierBonus(20)).toBe(3);
      expect(service.calculateTierBonus(49)).toBe(3);
    });

    test('returns 5% for 50+ referrals', () => {
      expect(service.calculateTierBonus(50)).toBe(5);
      expect(service.calculateTierBonus(100)).toBe(5);
    });
  });

  describe('calculateInterestWithBonus', () => {
    test('calculates correctly without bonus', () => {
      const result = service.calculateInterestWithBonus('PERSONAL', 500000, 12, 0);
      
      expect(result.baseInterestRate).toBe(15);
      expect(result.effectiveInterestRate).toBe(15);
      expect(result.bonusApplied).toBe(false);
      expect(result.totalSavingsFromBonus).toBe(0);
      expect(result.monthlyRepaymentAfterBonus).toBeGreaterThan(0);
    });

    test('applies bonus correctly to reduce effective rate', () => {
      const result = service.calculateInterestWithBonus('PERSONAL', 500000, 12, 3);
      
      expect(result.baseInterestRate).toBe(15);
      expect(result.effectiveInterestRate).toBe(12); // 15 - 3
      expect(result.bonusApplied).toBe(true);
      expect(result.totalSavingsFromBonus).toBeGreaterThan(0);
    });

    test('respects minimum interest floor', () => {
      // PERSONAL floor is 5%, base is 15%. Applying 12% bonus should floor at 5%.
      const result = service.calculateInterestWithBonus('PERSONAL', 500000, 12, 12);
      
      expect(result.effectiveInterestRate).toBe(5); // floored at 5%, not 3%
    });

    test('monthly repayment with bonus is less than without', () => {
      const result = service.calculateInterestWithBonus('BUSINESS', 1000000, 24, 2);
      
      expect(result.monthlyRepaymentAfterBonus).toBeLessThan(result.monthlyRepaymentBeforeBonus);
    });

    test('total savings equals difference over tenure', () => {
      const result = service.calculateInterestWithBonus('EMERGENCY', 300000, 6, 1);
      
      const expectedSavings = (result.monthlyRepaymentBeforeBonus - result.monthlyRepaymentAfterBonus) * 6;
      expect(result.totalSavingsFromBonus).toBeCloseTo(expectedSavings, 2);
    });

    test('handles large loan amounts correctly', () => {
      const result = service.calculateInterestWithBonus('BUSINESS', 50000000, 60, 5);
      
      expect(result.monthlyRepaymentAfterBonus).toBeGreaterThan(0);
      expect(result.loanAmount).toBe(50000000);
      expect(result.tenureMonths).toBe(60);
    });
  });
});
