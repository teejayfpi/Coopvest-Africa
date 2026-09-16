const {
  isRegistrationFeeSettled,
  isRegistrationFeeExempt,
  gateStatusFor,
} = require('../src/lib/activationGate');

/**
 * A salary-deduction member's registration fee is recovered from their salary
 * and remitted with their contributions, so it must not gate their account the
 * way an unpaid in-app fee does. These tests pin that rule in both directions:
 * the exemption applies, and it does not leak to members it should not cover.
 */
describe('registration fee settlement and exemption', () => {
  const base = {
    kyc_verified: true,
    registration_fee_paid: false,
    is_active: true,
    is_flagged: false,
    organization_id: null,
    contribution_method: null,
    contribution_type: null,
  };

  describe('exemption applies to salary-deduction members with an employer', () => {
    test('contribution_method = payroll with an organisation', () => {
      const p = { ...base, contribution_method: 'payroll', organization_id: 'org-1' };
      expect(isRegistrationFeeSettled(p)).toBe(true);
      expect(isRegistrationFeeExempt(p)).toBe(true);
      expect(gateStatusFor(p).activated).toBe(true);
    });

    test('contribution_type = salary_deduction with an organisation', () => {
      // The KYC flow writes `contribution_type`; the settings flow writes
      // `contribution_method`. Either must identify the member.
      const p = { ...base, contribution_type: 'salary_deduction', organization_id: 'org-1' };
      expect(isRegistrationFeeSettled(p)).toBe(true);
      expect(gateStatusFor(p).activated).toBe(true);
    });

    test('the legacy salary-based spelling is honoured', () => {
      const p = { ...base, contribution_method: 'salary-based', organization_id: 'org-1' };
      expect(isRegistrationFeeSettled(p)).toBe(true);
    });

    test('exempt is reported separately from paid', () => {
      const p = { ...base, contribution_method: 'payroll', organization_id: 'org-1' };
      const gate = gateStatusFor(p);
      expect(gate.registration_fee_paid).toBe(false);
      expect(gate.registration_fee_exempt).toBe(true);
      expect(gate.registration_fee_settled).toBe(true);
    });
  });

  describe('exemption does not leak', () => {
    test('payroll member with no organisation on file is not exempt', () => {
      // Without an employer we have no mechanism to recover the fee, so the
      // member must still settle it. This is the guard against the exemption
      // being granted on the strength of the method alone.
      const p = { ...base, contribution_method: 'payroll', organization_id: null };
      expect(isRegistrationFeeSettled(p)).toBe(false);
      expect(gateStatusFor(p).activated).toBe(false);
    });

    test('self-paying member with an organisation is not exempt', () => {
      const p = { ...base, contribution_method: 'manual', organization_id: 'org-1' };
      expect(isRegistrationFeeSettled(p)).toBe(false);
      expect(gateStatusFor(p).activated).toBe(false);
    });
  });

  describe('a settled fee always satisfies the gate', () => {
    test('an explicitly paid fee activates a self-paying member', () => {
      const p = { ...base, registration_fee_paid: true, contribution_method: 'manual' };
      expect(gateStatusFor(p).activated).toBe(true);
      // Paid, not exempt — the member-facing copy must not claim a waiver.
      expect(gateStatusFor(p).registration_fee_exempt).toBe(false);
    });

    test('paid takes precedence over the exemption for reporting', () => {
      const p = {
        ...base,
        registration_fee_paid: true,
        contribution_method: 'payroll',
        organization_id: 'org-1',
      };
      expect(isRegistrationFeeExempt(p)).toBe(false);
      expect(isRegistrationFeeSettled(p)).toBe(true);
    });
  });

  describe('KYC and blocking still gate access', () => {
    test('unverified KYC keeps an exempt member out', () => {
      const p = {
        ...base,
        kyc_verified: false,
        contribution_method: 'payroll',
        organization_id: 'org-1',
      };
      const gate = gateStatusFor(p);
      expect(gate.registration_fee_settled).toBe(true);
      expect(gate.activated).toBe(false);
    });

    test('a flagged member is blocked even with the fee settled', () => {
      const p = { ...base, registration_fee_paid: true, is_flagged: true };
      const gate = gateStatusFor(p);
      expect(gate.blocked).toBe(true);
      expect(gate.activated).toBe(false);
    });

    test('an inactive member is blocked', () => {
      const p = { ...base, registration_fee_paid: true, is_active: false };
      expect(gateStatusFor(p).activated).toBe(false);
    });
  });

  describe('defensive handling of missing data', () => {
    test('a null profile is treated as unactivated', () => {
      expect(isRegistrationFeeSettled(null)).toBe(false);
      expect(isRegistrationFeeExempt(null)).toBe(false);
      expect(gateStatusFor(null).activated).toBe(false);
    });

    test('an empty profile is treated as unactivated', () => {
      expect(gateStatusFor({}).activated).toBe(false);
    });
  });
});