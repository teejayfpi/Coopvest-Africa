const { normalizeAllocations } = require('../src/lib/allocations');

describe('normalizeAllocations', () => {
  describe('explicit breakdowns win', () => {
    it('keeps a caller-supplied allocation list', () => {
      const out = normalizeAllocations(5000, 'registration_fee', [
        { type: 'registration_fee', amount: 5000 },
      ]);
      expect(out).toEqual([
        { type: 'registration_fee', amount: 5000, loan_id: null, fee_id: null },
      ]);
    });

    it('carries a targeted loan through', () => {
      const out = normalizeAllocations(100000, 'loan_repayment', [
        { type: 'loan_repayment', amount: 100000, loan_id: 'loan-1' },
      ]);
      expect(out[0].type).toBe('loan_repayment');
      expect(out[0].loan_id).toBe('loan-1');
    });

    it('drops zero-value entries', () => {
      expect(normalizeAllocations(100, 'mixed', [
        { type: 'savings', amount: 0 },
        { type: 'fee', amount: 100 },
      ])).toHaveLength(1);
    });
  });

  describe('allocation_type is translated to the right obligation', () => {
    it('monthly_contribution becomes a savings credit', () => {
      expect(normalizeAllocations(20000, 'monthly_contribution')).toEqual([
        { type: 'savings', amount: 20000 },
      ]);
    });

    it('loan_repayment stays a loan repayment, never savings', () => {
      const out = normalizeAllocations(100000, 'loan_repayment');
      expect(out).toEqual([{ type: 'loan_repayment', amount: 100000 }]);
      expect(out.some((a) => a.type === 'savings')).toBe(false);
    });

    it('registration_fee settles a registration fee, never savings', () => {
      const out = normalizeAllocations(5000, 'registration_fee');
      expect(out).toEqual([{ type: 'registration_fee', amount: 5000 }]);
      expect(out.some((a) => a.type === 'savings')).toBe(false);
    });

    it('fine and fee keep their own type', () => {
      expect(normalizeAllocations(1500, 'fine')).toEqual([{ type: 'fine', amount: 1500 }]);
      expect(normalizeAllocations(1500, 'fee')).toEqual([{ type: 'fee', amount: 1500 }]);
    });
  });

  describe('ambiguous payments never credit the wallet', () => {
    // Regression: an activation-screen payment posted only
    // { amount, payment_type: 'registration_fee' } with no allocation_type.
    // The old default credited ₦5,000 to the member's wallet as "savings".
    it('an unknown allocation_type credits nothing', () => {
      expect(normalizeAllocations(5000, 'some_future_type')).toEqual([]);
      expect(normalizeAllocations(5000, 'other')).toEqual([]);
    });

    it('mixed without a breakdown credits nothing', () => {
      expect(normalizeAllocations(5000, 'mixed')).toEqual([]);
    });

    it('a missing allocation_type credits nothing (fail closed)', () => {
      expect(normalizeAllocations(5000)).toEqual([]);
      expect(normalizeAllocations(5000, null)).toEqual([]);
      expect(normalizeAllocations(5000, '')).toEqual([]);
    });

    it('a registration_fee payment is never savings', () => {
      const out = normalizeAllocations(5000, 'registration_fee');
      expect(out.some((a) => a.type === 'savings')).toBe(false);
    });
  });
});