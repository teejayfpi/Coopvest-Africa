/**
 * Who pays the monthly administrative fee.
 *
 * Salary-deduction members do not: their employer withholds the charge from
 * pay, so billing them in-app as well would take it twice. Direct-deposit
 * members do. These tests pin the worker's decision directly.
 */

const { shouldBill } = require('../src/workers/monthlyAdministrativeFeeWorker');

const BASE = {
  id: 'p1',
  role: 'member',
  created_at: '2024-01-15T00:00:00Z',
  is_active: true,
  is_flagged: false,
};

describe('who the administrative fee is billed to', () => {
  test('a salary-deduction member with a linked employer is not billed', () => {
    expect(
      shouldBill({ ...BASE, contribution_method: 'payroll', organization_id: 'org-1' }, '2026-11'),
    ).toBe(false);
  });

  test('the KYC spelling salary_deduction is exempt too', () => {
    expect(
      shouldBill(
        { ...BASE, contribution_type: 'salary_deduction', organization_id: 'org-1' },
        '2026-11',
      ),
    ).toBe(false);
  });

  test('a salary member awaiting employer enrolment is not billed', () => {
    // The employer is on file and inside its deferral window, so a deduction is
    // expected. Billing here would charge the month twice once it lands.
    expect(
      shouldBill(
        {
          ...BASE,
          contribution_method: 'payroll',
          pending_organization_name: 'Bowen University, Iwo',
          pending_organization_requested_at: new Date().toISOString(),
        },
        '2026-11',
      ),
    ).toBe(false);
  });

  test('a salary member whose employer claim has lapsed is billed', () => {
    // A stale self-declared employer is not a deduction. Without this the fee
    // would be hidden forever by a name nobody ever verified.
    const longAgo = new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString();
    expect(
      shouldBill(
        {
          ...BASE,
          contribution_method: 'payroll',
          pending_organization_name: 'Bowen University, Iwo',
          pending_organization_requested_at: longAgo,
        },
        '2026-11',
      ),
    ).toBe(true);
  });

  test('a direct-deposit member is billed', () => {
    expect(shouldBill({ ...BASE, contribution_method: 'manual' }, '2026-11')).toBe(true);
  });

  test('staff accounts are not billed the member charge', () => {
    for (const role of ['admin', 'super_admin', 'staff']) {
      expect(shouldBill({ ...BASE, role }, '2026-11')).toBe(false);
    }
  });

  test('an inactive or flagged member is not billed', () => {
    expect(shouldBill({ ...BASE, is_active: false }, '2026-11')).toBe(false);
    expect(shouldBill({ ...BASE, is_flagged: true }, '2026-11')).toBe(false);
  });
});
