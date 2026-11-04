/**
 * Single-device login, and who it applies to.
 *
 * `middleware/auth.js` rejects a token whose session_id does not match
 * `profiles.active_session_id`. That is right for a member with one phone, but
 * it made the admin dashboard unusable from two devices and produced silent
 * evictions: the losing device re-claims on its next request and signs the
 * other one out with no message.
 *
 * Staff are now exempt. These tests pin the boundary, because the obvious
 * implementation ("is this a known role?") is wrong: `member` is itself a
 * catalog role, so that check exempts everyone and disables the feature.
 */

const fs = require('fs');
const path = require('path');
const rbac = require('../src/lib/permissions');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
const middleware = read('src/middleware/auth.js');
const authRoutes = read('src/routes/auth.js');

describe('isStaffRole', () => {
  test('every administrative role counts as staff', () => {
    for (const role of [
      'ceo', 'coo', 'chief_system_analyst', 'legal_adviser', 'manager', 'system_analyst',
    ]) {
      expect(rbac.isStaffRole(role)).toBe(true);
    }
  });

  test('the legacy spellings still count as staff', () => {
    expect(rbac.isStaffRole('superadmin')).toBe(true);
    expect(rbac.isStaffRole('super_admin')).toBe(true);
    expect(rbac.isStaffRole('admin')).toBe(true);
    expect(rbac.isStaffRole('staff')).toBe(true);
  });

  test('a member is NOT staff — this is the whole point', () => {
    // `member` is a catalog role, so a check written as "resolves to a known
    // role" would return true here and exempt every member.
    expect(rbac.resolveRole('member')).toBe('member');
    expect(rbac.isStaffRole('member')).toBe(false);
  });

  test('an unknown or missing role is not staff, so a bad value grants nothing', () => {
    expect(rbac.isStaffRole('mystery')).toBe(false);
    expect(rbac.isStaffRole('')).toBe(false);
    expect(rbac.isStaffRole(null)).toBe(false);
    expect(rbac.isStaffRole(undefined)).toBe(false);
  });

  test('role spelling and case do not change the answer', () => {
    expect(rbac.isStaffRole('  Admin  ')).toBe(true);
    expect(rbac.isStaffRole('CEO')).toBe(true);
    expect(rbac.isStaffRole(' Member ')).toBe(false);
  });
});

describe('the middleware applies the exemption', () => {
  test('the session check consults isStaffRole', () => {
    expect(middleware).toContain('isStaffRole(profile.role)');
  });

  test('members are still subject to the check', () => {
    // The guard must still reject a mismatched session for a non-staff role.
    const guard = middleware.slice(middleware.indexOf('tokenSessionId'));
    expect(guard).toContain('profile.active_session_id !== tokenSessionId');
    expect(guard).toContain('SESSION_REPLACED');
  });

  test('the claim endpoint still bypasses the check, so a fresh login works', () => {
    expect(middleware).toContain('req.skipSingleSessionCheck');
    expect(authRoutes).toContain('req.skipSingleSessionCheck = true');
  });
});

describe('logout does not sign out the other device', () => {
  test('logout is scoped to the current session, not every session', () => {
    // The SDK default is `global`, which revokes every refresh token for the
    // account. That would defeat the staff exemption: signing out on a laptop
    // would still kill a phone that was in use.
    const logout = authRoutes.slice(authRoutes.indexOf("router.post('/logout'"));
    expect(logout).toContain("signOut(req.token, 'local')");
    expect(logout).not.toContain('signOut(req.token);');
  });

  test('ending other devices remains a separate, deliberate action', () => {
    const adminApi = read('src/routes/adminApi.js');
    expect(adminApi).toContain("'/sessions/user/:userId'");
  });
});
