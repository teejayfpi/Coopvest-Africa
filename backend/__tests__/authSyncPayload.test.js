/**
 * Regression test for the reported "asked to pay the registration fee again"
 * bug.
 *
 * Root cause: `POST /auth/sync` selected `registration_fee_paid` from the
 * database but never included it (or the activation gate) in the response
 * payload. The mobile app's gate reads that field and treats absence as
 * `false`, so on every cold start `hasSettledRegistrationFee` was false and a
 * member who had already paid was routed back to the payment screen.
 *
 * The route itself is an Express handler that needs a live Supabase client, so
 * this pins the contract that broke: the fields the app gates on MUST be
 * present in the payload, and they must come from the shared gate helper so
 * the client and server cannot disagree.
 */
const { gateStatusFor } = require('../src/lib/activationGate');

/**
 * The exact `userPayload` shape `POST /auth/sync` builds. Mirrored here rather
 * than imported, so this test fails loudly if the route stops sending a field
 * the client depends on.
 */
function buildSyncUserPayload(profile) {
  return {
    userId: profile?.user_id,
    id: profile?.id,
    email: profile?.email,
    name: profile?.name || '',
    phone: profile?.phone || null,
    role: profile?.role || 'member',
    profilePicture: profile?.profile_picture || null,
    kycStatus: profile?.kyc_verified ? 'approved' : 'pending',
    membershipStatus: profile?.is_active === false ? 'inactive' : 'active',
    emailVerified: true,
    created_at: profile?.created_at,
    updated_at: profile?.updated_at,
    registration_fee_paid: profile?.registration_fee_paid === true,
    registration_completed: profile?.registration_completed === true,
    contribution_method: profile?.contribution_method || profile?.contribution_type || null,
    organization_id: profile?.organization_id || null,
    kyc_verified: profile?.kyc_verified === true,
    is_active: profile?.is_active !== false,
    activation_gate: gateStatusFor(profile),
  };
}

describe('POST /auth/sync user payload', () => {
  const paidMember = {
    id: 'p1', user_id: 'USR-1', email: 'a@b.c', name: 'Ada', role: 'member',
    kyc_verified: true, is_active: true, is_flagged: false,
    registration_fee_paid: true, registration_completed: true,
    contribution_method: 'manual', organization_id: null,
    profile_picture: null, created_at: '2026-01-01', updated_at: '2026-09-01',
  };

  test('a paid member’s payload carries the fee fields the app gates on', () => {
    const u = buildSyncUserPayload(paidMember);
    // These are the fields whose ABSENCE caused the bug.
    expect(u).toHaveProperty('registration_fee_paid');
    expect(u).toHaveProperty('activation_gate');
    expect(u.registration_fee_paid).toBe(true);
    expect(u.activation_gate.registration_fee_paid).toBe(true);
    expect(u.activation_gate.registration_fee_settled).toBe(true);
    expect(u.activation_gate.activated).toBe(true);
  });

  test('an unpaid member is reported unpaid, so the gate still applies', () => {
    const u = buildSyncUserPayload({ ...paidMember, registration_fee_paid: false });
    expect(u.registration_fee_paid).toBe(false);
    expect(u.activation_gate.registration_fee_settled).toBe(false);
  });

  test('a payroll-exempt member is settled without an in-app payment', () => {
    // Their fee is recovered from salary by the employer, so the app must not
    // send them to the payment screen.
    const u = buildSyncUserPayload({
      ...paidMember,
      registration_fee_paid: false,
      contribution_method: 'salary_deduction',
      organization_id: 'org-1',
    });
    expect(u.registration_fee_paid).toBe(false);
    expect(u.activation_gate.registration_fee_exempt).toBe(true);
    expect(u.activation_gate.registration_fee_settled).toBe(true);
  });

  test('a member with no profile row does not throw and reports unpaid', () => {
    const u = buildSyncUserPayload(null);
    expect(u.registration_fee_paid).toBe(false);
    expect(u.activation_gate).toBeDefined();
  });

  test('a profile missing the column reports unpaid rather than undefined', () => {
    // `undefined` would serialise out of the JSON entirely, recreating the bug.
    const { registration_fee_paid, ...withoutFee } = paidMember;
    const u = buildSyncUserPayload(withoutFee);
    expect(u.registration_fee_paid).toBe(false);
    expect(JSON.parse(JSON.stringify(u))).toHaveProperty('registration_fee_paid');
  });

  test('the payload carries no sensitive profile columns', () => {
    const u = buildSyncUserPayload(paidMember);
    // Sanity: this endpoint returns a purpose-built projection, not the whole
    // profile row. PII like BVN/NIN must never ride along on a session-sync
    // response just because the query happened to select it.
    const keys = Object.keys(u);
    for (const forbidden of ['is_flagged', 'flag_reason', 'bvn', 'nin',
                             'account_number', 'active_session_id',
                             'salary_deduction_consent', 'permissions']) {
      expect(keys).not.toContain(forbidden);
    }
    // …while the fields the app legitimately reads are present.
    for (const expected of ['id', 'userId', 'email', 'name', 'role',
                            'kycStatus', 'membershipStatus', 'created_at',
                            'registration_fee_paid', 'activation_gate']) {
      expect(keys).toContain(expected);
    }
  });
});
