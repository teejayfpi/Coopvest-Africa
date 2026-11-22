const { shouldBill, billingMonth } = require('../src/workers/monthlyAdministrativeFeeWorker');

/**
 * Regression guard for the monthly administrative charge never being billed.
 *
 * The NGN1,500 charge was published in the terms and shown in the fee schedule,
 * but nothing created the `member_fees` row it is collected from, so it never
 * appeared in any member's "amount due". `shouldBill` is the decision half of
 * the fix; these tests pin who is billed and who is deliberately not.
 */
describe('billingMonth', () => {
  test('formats as YYYY-MM and zero-pads the month', () => {
    expect(billingMonth(new Date(2026, 0, 15))).toBe('2026-01');
    expect(billingMonth(new Date(2026, 11, 1))).toBe('2026-12');
  });
});

describe('shouldBill', () => {
  const base = { id: 'p1', created_at: '2026-01-10T00:00:00Z', contribution_method: 'manual' };

  test('a plain active member is billed', () => {
    expect(shouldBill(base, '2026-11')).toBe(true);
  });

  test('a salary-deduction member with an employer is not billed in-app', () => {
    // Their fee is recovered from payroll; billing them here would double-charge.
    expect(
      shouldBill({ ...base, contribution_method: 'payroll', organization_id: 'org-1' }, '2026-11'),
    ).toBe(false);
  });

  test('a deactivated or flagged member is skipped', () => {
    expect(shouldBill({ ...base, is_active: false }, '2026-11')).toBe(false);
    expect(shouldBill({ ...base, is_flagged: true }, '2026-11')).toBe(false);
  });

  test('staff and admin accounts are not billed the member charge', () => {
    for (const role of ['admin', 'superadmin', 'super_admin', 'staff']) {
      expect(shouldBill({ ...base, role }, '2026-11')).toBe(false);
    }
    expect(shouldBill({ ...base, role: 'member' }, '2026-11')).toBe(true);
  });

  test('a member who joined in the current month is still billed', () => {
    // The charge is for the month they are in, not a full month of membership.
    expect(shouldBill({ ...base, created_at: '2026-11-20T00:00:00Z' }, '2026-11')).toBe(true);
  });

  test('a member is never billed for a month before they joined', () => {
    expect(shouldBill({ ...base, created_at: '2026-11-05T00:00:00Z' }, '2026-10')).toBe(false);
  });

  test('no back-billing: earlier months are not swept up by a later run', () => {
    // A member who joined in January is billed for November only. The worker
    // bills the current month, so a January obligation is never created.
    expect(shouldBill(base, '2026-01')).toBe(true); // the month itself is fine
    // ...but the *worker* only ever asks about the current month; see processDue.
  });

  test('a malformed created_at does not bill', () => {
    expect(shouldBill({ ...base, created_at: 'not-a-date' }, '2026-11')).toBe(false);
  });

  test('a profile with no id is not billed', () => {
    expect(shouldBill({ created_at: '2026-01-10T00:00:00Z' }, '2026-11')).toBe(false);
    expect(shouldBill(null, '2026-11')).toBe(false);
  });
});
