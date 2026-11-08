const {
  isRegistrationFeeSettled,
  isRegistrationFeeExempt,
  isAdministrativeFeeExempt,
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
    pending_organization_name: null,
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

    test('a pending employer request defers the fee inside its window', () => {
      // The employer is not enrolled yet, but the member has committed to
      // payroll deduction and named them, and the fee is recovered once that
      // employer is enrolled and payroll runs. Blocking until an admin approves
      // the request would lock the member out over admin latency, so the
      // request defers the fee for a bounded window.
      const p = {
        ...base,
        contribution_type: 'salary_deduction',
        pending_organization_name: 'Lagos State Ministry of Finance',
        pending_organization_requested_at: '2026-01-01T00:00:00Z',
      };
      const now = Date.parse('2026-01-10T00:00:00Z'); // 9 days later
      expect(isRegistrationFeeSettled(p, now)).toBe(true);
      expect(isRegistrationFeeExempt(p, now)).toBe(true);
      expect(gateStatusFor(p, now).activated).toBe(true);
      expect(gateStatusFor(p, now).registration_fee_deferred).toBe(true);
    });

    test('a linked employer exempts indefinitely, unlike a pending one', () => {
      // organization_id is admin-approved, so there is no window to lapse.
      const p = {
        ...base,
        contribution_type: 'salary_deduction',
        organization_id: 'org-1',
      };
      const farFuture = Date.parse('2030-01-01T00:00:00Z');
      expect(isRegistrationFeeSettled(p, farFuture)).toBe(true);
      expect(gateStatusFor(p, farFuture).activated).toBe(true);
      // A linked employer is a genuine exemption, not a deferral.
      expect(gateStatusFor(p, farFuture).registration_fee_deferred).toBe(false);
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
    test('payroll member with no employer at all is not exempt', () => {
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

    test('a pending employer does not exempt a self-paying member', () => {
      // The employer on file is only half the rule; the channel must also be
      // payroll. Otherwise a direct-deposit member who once requested an
      // employer would be exempt without any deduction in place.
      const p = {
        ...base,
        contribution_type: 'direct_deposit',
        pending_organization_name: 'Some Employer',
      };
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

  describe('a self-declared employer cannot evade the fee forever', () => {
    // The evasion this pins: register as salary deduction, type any employer
    // name, and never pay the registration fee — while no payroll batch can ever
    // recover it, because the named employer is never enrolled.
    const evader = {
      kyc_verified: true,
      registration_fee_paid: false,
      is_active: true,
      is_flagged: false,
      contribution_method: 'payroll',
      contribution_type: 'salary_deduction',
      organization_id: null,
      pending_organization_name: 'Totally Real Ltd',
      pending_organization_requested_at: '2026-01-01T00:00:00Z',
    };

    test('the fee is deferred while the window is open', () => {
      const now = Date.parse('2026-01-20T00:00:00Z'); // 19 days later
      expect(isRegistrationFeeSettled(evader, now)).toBe(true);
      expect(gateStatusFor(evader, now).activated).toBe(true);
    });

    test('once the window lapses the fee is payable again', () => {
      const now = Date.parse('2026-04-01T00:00:00Z'); // ~90 days later
      expect(isRegistrationFeeSettled(evader, now)).toBe(false);
      expect(isRegistrationFeeExempt(evader, now)).toBe(false);
      const gate = gateStatusFor(evader, now);
      expect(gate.activated).toBe(false);
      expect(gate.registration_fee_deferred).toBe(false);
    });

    test('a named employer with no anchor never defers anything', () => {
      // Without the anchor there is no window to be inside, so an
      // unverifiable claim cannot grant the exemption at all.
      const p = { ...evader, pending_organization_requested_at: null };
      expect(isRegistrationFeeSettled(p)).toBe(false);
      expect(gateStatusFor(p).activated).toBe(false);
    });

    test('a future-dated anchor does not defer the fee', () => {
      // The anchor is a member-writable column (migration 063 revokes that, but
      // this must hold regardless). A far-future value would make the elapsed
      // time negative, pass the window check, and defer the fee permanently.
      const p = { ...evader, pending_organization_requested_at: '3000-01-01T00:00:00Z' };
      const now = Date.parse('2026-06-01T00:00:00Z');
      expect(isRegistrationFeeSettled(p, now)).toBe(false);
      expect(isRegistrationFeeExempt(p, now)).toBe(false);
      expect(gateStatusFor(p, now).activated).toBe(false);
      expect(isAdministrativeFeeExempt(p, now)).toBe(false);
    });

    test('small clock skew on the anchor is tolerated', () => {
      const now = Date.parse('2026-06-01T00:00:00Z');
      const p = {
        ...evader,
        pending_organization_requested_at: new Date(now + 60 * 1000).toISOString(),
      };
      expect(isRegistrationFeeSettled(p, now)).toBe(true);
    });

    test('the monthly administrative fee also returns when the window lapses', () => {
      const open = Date.parse('2026-01-20T00:00:00Z');
      const lapsed = Date.parse('2026-04-01T00:00:00Z');
      expect(isAdministrativeFeeExempt(evader, open)).toBe(true);
      expect(isAdministrativeFeeExempt(evader, lapsed)).toBe(false);
    });

    test('the grace window is configurable', () => {
      const prev = process.env.PENDING_EMPLOYER_FEE_GRACE_DAYS;
      process.env.PENDING_EMPLOYER_FEE_GRACE_DAYS = '1';
      try {
        const twoDays = Date.parse('2026-01-03T00:00:00Z');
        expect(isRegistrationFeeSettled(evader, twoDays)).toBe(false);
      } finally {
        if (prev === undefined) delete process.env.PENDING_EMPLOYER_FEE_GRACE_DAYS;
        else process.env.PENDING_EMPLOYER_FEE_GRACE_DAYS = prev;
      }
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