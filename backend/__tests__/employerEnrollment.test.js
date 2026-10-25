const { employerEnrollmentStatus } = require('../src/lib/employerEnrollment');

describe('employerEnrollmentStatus', () => {
  test('a pending employer blocks guarantors and names the employer', () => {
    const status = employerEnrollmentStatus(
      { pending_organization_name: 'Acme Ltd', pending_organization_requested_at: '2026-01-02T00:00:00Z' },
      null,
    );
    expect(status.pending).toBe(true);
    expect(status.blocksGuarantors).toBe(true);
    expect(status.employerName).toBe('Acme Ltd');
    expect(status.requestedAt).toBe('2026-01-02T00:00:00Z');
    expect(status.message).toContain('Acme Ltd');
  });

  test('once the employer is enrolled nothing is pending', () => {
    const status = employerEnrollmentStatus(
      { pending_organization_name: 'Acme Ltd' },
      { id: 'org-1', name: 'Acme Ltd' },
    );
    expect(status.pending).toBe(false);
    expect(status.blocksGuarantors).toBe(false);
    expect(status.message).toBeNull();
  });

  test('a member with no employer at all is not "pending"', () => {
    const status = employerEnrollmentStatus({}, null);
    expect(status.pending).toBe(false);
    expect(status.blocksGuarantors).toBe(false);
    expect(status.message).toBeNull();
    expect(status.employerName).toBeNull();
  });

  test('a null profile is handled', () => {
    const status = employerEnrollmentStatus(null, null);
    expect(status.pending).toBe(false);
    expect(status.message).toBeNull();
  });
});
