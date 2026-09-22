const { maxApprovableAmount, SUPER_ADMIN_ROLES, DEFAULT_THRESHOLDS } = require('../src/lib/approvalMatrix');

const thresholds = {
  levels: [
    { level: 1, maxAmount: 100000, role: 'staff' },
    { level: 2, maxAmount: 1000000, role: 'admin' },
    { level: 3, maxAmount: null, role: 'super_admin' }, // unlimited
  ],
};

describe('approvalMatrix.maxApprovableAmount', () => {
  it('staff are capped at their level max', () => {
    expect(maxApprovableAmount('staff', thresholds)).toBe(100000);
  });

  it('admins are capped at their level max', () => {
    expect(maxApprovableAmount('admin', thresholds)).toBe(1000000);
  });

  it('super admin roles are always unlimited', () => {
    SUPER_ADMIN_ROLES.forEach((role) => {
      expect(maxApprovableAmount(role, thresholds)).toBe(Infinity);
    });
  });

  it('values above the unlimited sentinel are treated as unlimited', () => {
    expect(maxApprovableAmount('admin', { levels: [{ maxAmount: 2e12, role: 'admin' }] })).toBe(Infinity);
  });

  it('unknown roles get zero (can never approve outright)', () => {
    expect(maxApprovableAmount('member', thresholds)).toBe(0);
    expect(maxApprovableAmount(undefined, thresholds)).toBe(0);
  });

  it('takes the highest matching level when a role appears more than once', () => {
    const dup = { levels: [{ maxAmount: 50000, role: 'staff' }, { maxAmount: 75000, role: 'staff' }] };
    expect(maxApprovableAmount('staff', dup)).toBe(75000);
  });
});

/**
 * Canonical role names, added with the six-role taxonomy. The stored thresholds
 * still use historical spellings, so resolving a role must not gate the apex
 * account or widen a collapsed tier.
 */
describe('approvalMatrix with canonical role names', () => {
  const rbac = require('../src/lib/permissions');

  it('a CEO named canonically is still unlimited', () => {
    // Otherwise the apex account would be forced to route its own loans to the
    // Approval Center, since the settings say `super_admin`.
    expect(maxApprovableAmount('ceo', thresholds)).toBe(Infinity);
  });

  it('the new name for a collapsed tier inherits the MOST RESTRICTIVE limit', () => {
    // staff and admin both resolve to `manager`. Inheriting admin's 1,000,000
    // would have loosened the guard for every existing staff approver.
    expect(maxApprovableAmount('manager', thresholds)).toBe(100000);
  });

  it('an exact spelling match still wins over the collapsed fallback', () => {
    // Preserves admin's own level while staff keeps its lower one.
    expect(maxApprovableAmount('admin', thresholds)).toBe(1000000);
    expect(maxApprovableAmount('staff', thresholds)).toBe(100000);
  });

  it('a role with no configured level cannot approve outright', () => {
    for (const role of ['coo', 'legal_adviser', 'system_analyst', 'chief_system_analyst']) {
      expect(maxApprovableAmount(role, thresholds)).toBe(0);
    }
  });

  it('every role that can approve loans has a usable limit in the shipped defaults', () => {
    // A loan approver with limit 0 would be routed to the Approval Center for
    // every loan, including trivial ones — a silent operational break. The
    // shipped defaults must therefore cover every approving role.
    const approvers = rbac.listRoles()
      .filter((r) => rbac.hasPermission(r.key, 'loan.approve'))
      .map((r) => r.key);
    expect(approvers.length).toBeGreaterThan(0);
    for (const role of approvers) {
      const limit = maxApprovableAmount(role, DEFAULT_THRESHOLDS);
      if (role === 'ceo') expect(limit).toBe(Infinity);
      else expect(limit).toBeGreaterThan(0);
    }
  });
});
