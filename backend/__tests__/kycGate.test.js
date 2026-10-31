const { kycGateFor, KYC_PENDING_STATUSES } = require('../src/lib/kycGate');

describe('kycGateFor', () => {
  test('allows a member whose profile is verified', () => {
    expect(kycGateFor({ kyc_verified: true }, null)).toEqual({
      allowed: true,
      reason: 'verified',
      message: null,
    });
  });

  test('verified wins even if the kyc row is stale or missing', () => {
    expect(kycGateFor({ kyc_verified: true }, { status: 'pending' }).allowed).toBe(true);
    expect(kycGateFor({ kyc_verified: true }, undefined).allowed).toBe(true);
  });

  test('rejects a member whose KYC was rejected', () => {
    // The regression: the app counted 'rejected' as submitted, so a rejected
    // member reached loan submission. The server must not agree.
    const result = kycGateFor({ kyc_verified: false }, { status: 'rejected' });
    expect(result.allowed).toBe(false);
    expect(result.reason).toBe('rejected');
    expect(result.message).toMatch(/not approved/i);
  });

  test.each(KYC_PENDING_STATUSES)(
    'blocks a member awaiting review (status %s) as pending',
    (status) => {
      const result = kycGateFor({ kyc_verified: false }, { status });
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe('pending');
    }
  );

  test('blocks a member who has not started KYC', () => {
    expect(kycGateFor({ kyc_verified: false }, null).reason).toBe('not_started');
    expect(kycGateFor({ kyc_verified: false }, { status: 'pending' }).reason).toBe(
      'not_started'
    );
    expect(kycGateFor(null, null).allowed).toBe(false);
  });

  test('a missing/null flag is never treated as verified', () => {
    // `=== true`, not truthy: an absent column must not open the gate.
    expect(kycGateFor({}, { status: 'submitted' }).allowed).toBe(false);
    expect(kycGateFor({ kyc_verified: undefined }, {}).allowed).toBe(false);
    expect(kycGateFor({ kyc_verified: 'true' }, {}).allowed).toBe(false);
  });
});
