/**
 * The monthly administrative fee must be part of the amount a member is asked
 * to pay, and a member must be able to settle the contribution and the fee in
 * one payment.
 *
 * The fee row is what `computeObligations` totals, so the obligation only
 * exists once the billing worker has created it. That worker used to skip
 * salary-deduction members on the premise that payroll recovers the fee. No
 * payroll path can — `payroll_batch_lines` carries `contribution_amount` and
 * `registration_fee_amount` and nothing else — so the fee was collected by
 * nobody. These tests pin the worker's decision directly.
 */

const { shouldBill } = require('../src/workers/monthlyAdministrativeFeeWorker');

const BASE = {
  id: 'p1',
  role: 'member',
  created_at: '2024-01-15T00:00:00Z',
  is_active: true,
  is_flagged: false,
};

describe('the administrative fee is billed to every member', () => {
  test('a salary-deduction member with a linked employer is billed', () => {
    expect(
      shouldBill({ ...BASE, contribution_method: 'payroll', organization_id: 'org-1' }, '2026-11'),
    ).toBe(true);
  });

  test('a salary-deduction member awaiting employer enrolment is billed', () => {
    // An unverified claim of a future payroll deduction is not a deduction.
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
