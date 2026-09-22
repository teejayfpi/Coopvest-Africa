const rbac = require('../src/lib/permissions');
const { requirementFor, FALLBACK_WRITE_PERMISSION, FALLBACK_READ_PERMISSION } = require('../src/middleware/requirePermission');

/**
 * Server-side authorisation. Before this existed, admin access was effectively
 * binary: `requireAdmin` admitted admin/superadmin/staff alike and only 8 of 67
 * write endpoints had a further check, so a `staff` token could delete
 * contributions and reset member passwords.
 *
 * These tests pin the properties that make that safe to have changed.
 */

describe('role resolution', () => {
  test('every legacy spelling still resolves, so existing rows keep working', () => {
    expect(rbac.resolveRole('super_admin')).toBe('ceo');
    expect(rbac.resolveRole('superadmin')).toBe('ceo');
    expect(rbac.resolveRole('admin')).toBe('manager');
    expect(rbac.resolveRole('staff')).toBe('manager');
    expect(rbac.resolveRole('operator')).toBe('manager');
    expect(rbac.resolveRole('viewer')).toBe('system_analyst');
    expect(rbac.resolveRole('member')).toBe('member');
  });

  test('the six requested roles all exist', () => {
    const keys = rbac.listRoles().map((r) => r.key);
    for (const k of ['ceo', 'coo', 'legal_adviser', 'chief_system_analyst', 'manager', 'system_analyst']) {
      expect(keys).toContain(k);
    }
  });

  test('an unknown role resolves to null rather than a default with access', () => {
    expect(rbac.resolveRole('mystery')).toBeNull();
    expect(rbac.resolveRole('')).toBeNull();
    expect(rbac.resolveRole(null)).toBeNull();
    expect(rbac.resolveRole(undefined)).toBeNull();
  });

  test('resolution is case- and whitespace-insensitive', () => {
    expect(rbac.resolveRole('  STAFF  ')).toBe('manager');
    expect(rbac.resolveRole('Super_Admin')).toBe('ceo');
  });

  test('apex authority maps to the CEO, not to a lesser role', () => {
    // Mapping super_admin anywhere else would strip access from the only admin
    // account in production.
    expect(rbac.resolveRole('super_admin')).toBe('ceo');
  });
});

describe('safety: dangerous permissions are apex-only', () => {
  const APEX_ONLY = [
    'member.delete',
    'member.password_reset',
    'wallet.adjust',
    'ledger.post',
    'reversal.approve',
    'contribution.delete',
  ];

  test.each(APEX_ONLY)('%s is held by the CEO alone', (perm) => {
    const holders = rbac.listRoles().filter((r) => rbac.hasPermission(r.key, perm)).map((r) => r.key);
    expect(holders).toEqual(['ceo']);
  });

  test('a staff-level role cannot reach any of the sensitive operations', () => {
    for (const perm of APEX_ONLY) {
      expect(rbac.hasPermission('staff', perm)).toBe(false);
      expect(rbac.hasPermission('manager', perm)).toBe(false);
    }
  });

  test('system administration sits with the Chief System Analyst, not operations', () => {
    expect(rbac.hasPermission('chief_system_analyst', 'feature_flag.write')).toBe(true);
    expect(rbac.hasPermission('chief_system_analyst', 'settings.write')).toBe(true);
    // …but the CSA must not be able to move money.
    expect(rbac.hasPermission('chief_system_analyst', 'wallet.adjust')).toBe(false);
    expect(rbac.hasPermission('chief_system_analyst', 'loan.approve')).toBe(false);
  });

  test('legal oversight can approve compliance but never move money', () => {
    expect(rbac.hasPermission('legal_adviser', 'compliance.approve')).toBe(true);
    expect(rbac.hasPermission('legal_adviser', 'loan.approve')).toBe(false);
    expect(rbac.hasPermission('legal_adviser', 'wallet.adjust')).toBe(false);
  });

  test('a read-only role has no write permissions at all', () => {
    const writes = rbac.permissionsFor('system_analyst').filter((p) => !p.endsWith('.read'));
    // ticket.write is the one deliberate exception for support staff.
    expect(writes).toEqual(['ticket.write']);
  });

  test('a member has no admin permissions', () => {
    expect(rbac.permissionsFor('member')).toEqual([]);
  });
});

describe('fail-closed behaviour', () => {
  test('an unknown permission name is denied even for the CEO', () => {
    expect(rbac.hasPermission('ceo', 'not.a.real.permission')).toBe(false);
    expect(rbac.hasPermission('ceo', '')).toBe(false);
    expect(rbac.hasPermission('ceo', null)).toBe(false);
  });

  test('an unknown role gains nothing from a custom grant of an unknown permission', () => {
    expect(rbac.hasPermission('mystery', 'member.read', { permissions: ['fake.perm'] })).toBe(false);
  });

  test('custom permission grants are additive and validated against the catalog', () => {
    const extra = { permissions: ['backup.write', 'not.real'] };
    expect(rbac.hasPermission('manager', 'backup.write', extra)).toBe(true);
    // The bogus entry is ignored rather than stored.
    expect(rbac.permissionsFor('manager', extra)).not.toContain('not.real');
  });

  test('a grant cannot be used to fabricate an unknown permission', () => {
    expect(rbac.hasPermission('manager', 'totally.made.up', { permissions: ['totally.made.up'] })).toBe(false);
  });
});

describe('path to permission mapping', () => {
  test('destructive and financial routes map to their real permission', () => {
    expect(requirementFor('DELETE', '/members/abc').permission).toBe('member.delete');
    expect(requirementFor('POST', '/members/abc/reset-password').permission).toBe('member.password_reset');
    expect(requirementFor('POST', '/members/abc/confirm-delete').permission).toBe('member.delete');
    expect(requirementFor('DELETE', '/contributions/x').permission).toBe('contribution.delete');
    expect(requirementFor('POST', '/loans/x/approve').permission).toBe('loan.approve');
    expect(requirementFor('POST', '/loans/x/disburse').permission).toBe('loan.disburse');
    expect(requirementFor('POST', '/wallets/x/adjust').permission).toBe('wallet.adjust');
    expect(requirementFor('POST', '/accounting/journal-entry').permission).toBe('ledger.post');
    expect(requirementFor('PATCH', '/admins/x/role').permission).toBe('role.write');
    expect(requirementFor('PUT', '/system-settings/x').permission).toBe('settings.write');
    expect(requirementFor('POST', '/emergency-controls/x').permission).toBe('emergency.use');
    expect(requirementFor('POST', '/organizations/assign').permission).toBe('organization.assign');
  });

  test('the more specific rule wins over the general one', () => {
    // /loans/x/disburse must not fall through to the general /loans POST rule.
    expect(requirementFor('POST', '/loans/x/disburse').permission).toBe('loan.disburse');
    expect(requirementFor('POST', '/loans/x/approve').permission).toBe('loan.approve');
    expect(requirementFor('POST', '/loans').permission).toBe('loan.write');
    // reset-password must beat the general /members POST rule.
    expect(requirementFor('POST', '/members/abc/reset-password').permission).toBe('member.password_reset');
    expect(requirementFor('POST', '/members').permission).toBe('member.write');
  });

  test('an unclassified WRITE fails closed to the highest authority', () => {
    const r = requirementFor('POST', '/some/brand/new/endpoint');
    expect(r.permission).toBe(FALLBACK_WRITE_PERMISSION);
    expect(r.matched).toBe(false);
    // And a middle-tier role therefore cannot reach it.
    expect(rbac.hasPermission('manager', FALLBACK_WRITE_PERMISSION)).toBe(false);
    expect(rbac.hasPermission('chief_system_analyst', FALLBACK_WRITE_PERMISSION)).toBe(true);
  });

  test('an unclassified READ stays permissive so tightening writes locks nobody out', () => {
    const r = requirementFor('GET', '/some/brand/new/read');
    expect(r.permission).toBe(FALLBACK_READ_PERMISSION);
    expect(rbac.hasPermission('system_analyst', FALLBACK_READ_PERMISSION)).toBe(true);
  });

  test('the dashboard identity probe is exempt from a permission check', () => {
    const r = requirementFor('GET', '/sessions/me');
    expect(r.skipPermissionCheck).toBe(true);
  });

  test('a trailing slash does not bypass the rules', () => {
    expect(requirementFor('DELETE', '/members/abc/').permission).toBe('member.delete');
  });

  test('every catalog permission is a real permission name', () => {
    const { ROUTE_PERMISSIONS } = require('../src/middleware/requirePermission');
    const unknown = ROUTE_PERMISSIONS
      .map((r) => r.permission)
      .filter(Boolean)
      .filter((p) => !rbac.ALL_PERMISSIONS.includes(p));
    expect(unknown).toEqual([]);
  });

  test('every role permission is a real permission name', () => {
    for (const role of Object.values(rbac.ROLES)) {
      for (const p of role.permissions) {
        expect(rbac.ALL_PERMISSIONS).toContain(p);
      }
    }
  });
});

describe('assignable roles', () => {
  test('the role-writing endpoint accepts every role including the new ones', () => {
    const values = rbac.assignableRoleValues();
    for (const v of ['ceo', 'coo', 'legal_adviser', 'chief_system_analyst', 'manager', 'system_analyst', 'staff', 'admin']) {
      expect(values).toContain(v);
    }
    // A member is not an admin assignment.
    expect(values).not.toContain('member');
  });
});
