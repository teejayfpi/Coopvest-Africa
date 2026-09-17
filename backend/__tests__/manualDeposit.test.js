const {
  ALL_DEPOSIT_TYPES,
  creditsMemberBalance,
  settlesRegistrationFee,
  allocationTypeFor,
  contributionMonthFor,
} = require('../src/lib/manualDeposit');

/**
 * Manual deposits move member money, so which deposit type does what is worth
 * pinning down. The code this replaced credited the wallet for every type,
 * including the two that are Coopvest income — that would have created member
 * balance out of nothing.
 */
describe('manual deposit semantics', () => {
  describe('which types increase the member balance', () => {
    test('savings and special contributions credit the member', () => {
      expect(creditsMemberBalance('savings')).toBe(true);
      expect(creditsMemberBalance('special')).toBe(true);
    });

    test('adjustments and refunds credit the member', () => {
      expect(creditsMemberBalance('adjustment')).toBe(true);
      expect(creditsMemberBalance('refund')).toBe(true);
    });

    test('a levy does NOT credit the member', () => {
      // A levy is Coopvest income. Crediting it would mean the member's balance
      // rises by money they paid us.
      expect(creditsMemberBalance('levy')).toBe(false);
    });

    test('an entrance fee does NOT credit the member', () => {
      expect(creditsMemberBalance('entrance_fee')).toBe(false);
    });

    test('every offered type is classified one way or the other', () => {
      for (const t of ALL_DEPOSIT_TYPES) {
        expect(typeof creditsMemberBalance(t)).toBe('boolean');
      }
    });

    test('an unknown type is not treated as member money', () => {
      // Fail closed: an unrecognised type must not credit a balance.
      expect(creditsMemberBalance('nonsense')).toBe(false);
      expect(creditsMemberBalance(undefined)).toBe(false);
    });
  });

  describe('registration fee settlement', () => {
    test('only the entrance fee settles the registration fee', () => {
      expect(settlesRegistrationFee('entrance_fee')).toBe(true);
      for (const t of ALL_DEPOSIT_TYPES.filter((x) => x !== 'entrance_fee')) {
        expect(settlesRegistrationFee(t)).toBe(false);
      }
    });
  });

  describe('allocation type used by reconciliation', () => {
    test('an entrance fee allocates to registration_fee', () => {
      expect(allocationTypeFor('entrance_fee')).toBe('registration_fee');
    });

    test('savings and special allocate to monthly_contribution', () => {
      expect(allocationTypeFor('savings')).toBe('monthly_contribution');
      expect(allocationTypeFor('special')).toBe('monthly_contribution');
    });

    test('a levy allocates to fee', () => {
      expect(allocationTypeFor('levy')).toBe('fee');
    });

    test('refunds and adjustments are not contributions', () => {
      // They credit the wallet but are corrections, not savings for a month.
      expect(allocationTypeFor('refund')).toBe('fee');
      expect(allocationTypeFor('adjustment')).toBe('fee');
    });
  });

  describe('contribution month attribution', () => {
    test('a savings deposit is attributed to the month it was recorded', () => {
      expect(contributionMonthFor('savings', new Date('2026-09-16T10:00:00Z'))).toBe('2026-09');
    });

    test('the month is stored, so a late-recorded payment keeps its month', () => {
      // A September payroll run recorded in October must still read as September.
      expect(contributionMonthFor('savings', new Date('2026-10-03T00:00:00Z'))).toBe('2026-10');
    });

    test('fee and correction types carry no contribution month', () => {
      expect(contributionMonthFor('levy', new Date('2026-09-16'))).toBeNull();
      expect(contributionMonthFor('entrance_fee', new Date('2026-09-16'))).toBeNull();
      expect(contributionMonthFor('refund', new Date('2026-09-16'))).toBeNull();
      expect(contributionMonthFor('adjustment', new Date('2026-09-16'))).toBeNull();
    });

    test('an invalid date yields no month rather than throwing', () => {
      expect(contributionMonthFor('savings', 'not-a-date')).toBeNull();
    });

    test('single-digit months are zero-padded', () => {
      expect(contributionMonthFor('savings', new Date('2026-01-05T00:00:00Z'))).toBe('2026-01');
    });
  });
});