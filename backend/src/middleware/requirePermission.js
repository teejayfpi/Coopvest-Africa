/**
 * Server-side authorisation enforcement.
 *
 * `requirePermission` sits on the admin routers and decides, per request, which
 * permission a path needs. It exists because route-level guards were the only
 * thing protecting sensitive operations and 59 of 67 write endpoints had none —
 * a `staff` token could delete a contribution or reset a member password.
 *
 * Design rules, in priority order:
 *
 *   1. FAIL CLOSED. An unmatched write path requires the highest permission, not
 *      "allow". A new endpoint is therefore denied until it is classified.
 *   2. READS ARE PERMISSIVE. An unmatched GET needs only `dashboard.read`, so
 *      tightening writes cannot lock anyone out of a screen.
 *   3. FIRST MATCH WINS, so the most specific route is listed first.
 *   4. A ROUTE'S OWN GUARD STILL APPLIES. This runs before the route handlers,
 *      so existing `checkSuperAdmin` checks remain a second line of defence.
 *   5. An account with no resolvable role is rejected, not defaulted.
 *
 * There is deliberately an opt-out (`skipPermissionCheck`) for the handful of
 * endpoints that legitimately serve an authenticated non-admin (e.g. the
 * dashboard's own "who am I" probe). Those routes must still apply their own
 * authentication.
 */

const RBAC = require('../lib/permissions');

/**
 * Ordered path → permission table.
 *
 * Each entry: { method, pattern, permission }. `pattern` is matched against the
 * request path *within the router's mount point* (e.g. `/members/123`), so the
 * same table works for /api/admin, /api/v1/admin and /api/v2/admin.
 *
 * Order matters: put specific patterns above general ones.
 */
const ROUTE_PERMISSIONS = [
  // ── Identity / self-service (no admin permission needed) ──────────────────
  // The dashboard asks "who am I" on boot, and a non-admin must get an answer
  // rather than a 403 so the UI can render "no access" instead of an error.
  { method: 'GET', pattern: /^\/sessions\/me$/, skipPermissionCheck: true },
  { method: 'GET', pattern: /^\/roles$/, permission: 'role.read' },

  // ── Roles and permissions ─────────────────────────────────────────────────
  // Legacy governance `/permissions` (display-only catalogue) and the
  // authoritative `/rbac/catalog` are both reads.
  { method: 'GET', pattern: /^\/rbac\/catalog$/, permission: 'role.read' },
  { method: 'GET', pattern: /^\/permissions/, permission: 'role.read' },
  { method: 'PATCH', pattern: /^\/admins\/[^/]+\/role$/, permission: 'role.write' },
  { method: 'PATCH', pattern: /^\/admins\/[^/]+\/status$/, permission: 'role.write' },
  { method: 'DELETE', pattern: /^\/admins/, permission: 'role.write' },
  { method: 'GET', pattern: /^\/admins/, permission: 'role.read' },

  // ── Members ───────────────────────────────────────────────────────────────
  { method: 'POST', pattern: /^\/members\/[^/]+\/reset-password$/, permission: 'member.password_reset' },
  { method: 'POST', pattern: /^\/members\/[^/]+\/verify$/, permission: 'member.verify' },
  { method: 'POST', pattern: /^\/members\/[^/]+\/confirm-delete$/, permission: 'member.delete' },
  { method: 'DELETE', pattern: /^\/members/, permission: 'member.delete' },
  { method: 'POST', pattern: /^\/members\/[^/]+\/contributions$/, permission: 'contribution.write' },
  { method: 'POST', pattern: /^\/members/, permission: 'member.write' },
  { method: 'PATCH', pattern: /^\/members/, permission: 'member.write' },
  { method: 'PUT', pattern: /^\/members/, permission: 'member.write' },
  { method: 'GET', pattern: /^\/members/, permission: 'member.read' },
  { method: 'GET', pattern: /^\/verification/, permission: 'member.read' },
  { method: 'POST', pattern: /^\/verification/, permission: 'member.verify' },

  // Bulk import is a heavier operation than an ordinary edit.
  { method: 'POST', pattern: /^\/bulk\/import-members/, permission: 'member.import' },
  { method: 'POST', pattern: /^\/bulk\/import-contributions/, permission: 'member.import' },
  { method: 'POST', pattern: /^\/bulk\//, permission: 'member.write' },
  { method: 'GET', pattern: /^\/bulk\//, permission: 'member.read' },

  // ── Money in ──────────────────────────────────────────────────────────────
  { method: 'POST', pattern: /^\/deposits\/[^/]+\/(verify|reject)/, permission: 'deposit.verify' },
  { method: 'GET', pattern: /^\/deposits/, permission: 'deposit.read' },
  { method: 'POST', pattern: /^\/manual-deposits/, permission: 'deposit.verify' },
  { method: 'GET', pattern: /^\/manual-deposits/, permission: 'deposit.read' },
  { method: 'POST', pattern: /^\/payment-proofs/, permission: 'payment_proof.approve' },
  { method: 'GET', pattern: /^\/payment-proofs/, permission: 'payment_proof.read' },

  { method: 'DELETE', pattern: /^\/contributions/, permission: 'contribution.delete' },
  { method: 'POST', pattern: /^\/contributions/, permission: 'contribution.write' },
  { method: 'PATCH', pattern: /^\/contributions/, permission: 'contribution.write' },
  { method: 'PUT', pattern: /^\/contributions/, permission: 'contribution.write' },
  { method: 'GET', pattern: /^\/contributions/, permission: 'contribution.read' },
  { method: 'GET', pattern: /^\/member-contributions/, permission: 'contribution.read' },

  // ── Money out / balances ──────────────────────────────────────────────────
  { method: 'POST', pattern: /^\/withdrawals/, permission: 'withdrawal.approve' },
  { method: 'PATCH', pattern: /^\/withdrawals/, permission: 'withdrawal.approve' },
  { method: 'DELETE', pattern: /^\/withdrawals/, permission: 'withdrawal.approve' },
  { method: 'GET', pattern: /^\/withdrawals/, permission: 'withdrawal.read' },
  { method: 'POST', pattern: /^\/wallets?\/[^/]+\/adjust/, permission: 'wallet.adjust' },
  { method: 'POST', pattern: /^\/wallet-adjustments/, permission: 'wallet.adjust' },
  { method: 'GET', pattern: /^\/wallets?/, permission: 'wallet.read' },
  { method: 'GET', pattern: /^\/wallet-management/, permission: 'wallet.read' },

  // Ledger / accounting. Posting and reversal are the highest-risk money writes.
  { method: 'POST', pattern: /^\/ledger\/adjust/, permission: 'reversal.approve' },
  { method: 'POST', pattern: /^\/accounting\/journal-entry/, permission: 'ledger.post' },
  { method: 'POST', pattern: /^\/accounting\/reversal/, permission: 'reversal.approve' },
  { method: 'POST', pattern: /^\/accounting/, permission: 'ledger.post' },
  { method: 'POST', pattern: /^\/ledger/, permission: 'ledger.post' },
  { method: 'GET', pattern: /^\/ledger/, permission: 'ledger.read' },
  { method: 'GET', pattern: /^\/accounting/, permission: 'ledger.read' },
  { method: 'GET', pattern: /^\/trial-balance/, permission: 'ledger.read' },
  { method: 'GET', pattern: /^\/balance-sheet/, permission: 'ledger.read' },
  { method: 'GET', pattern: /^\/profit-loss/, permission: 'ledger.read' },
  { method: 'POST', pattern: /^\/reconciliation/, permission: 'remittance.write' },
  { method: 'GET', pattern: /^\/reconciliation/, permission: 'remittance.read' },

  // ── Loans ─────────────────────────────────────────────────────────────────
  { method: 'POST', pattern: /^\/loans\/[^/]+\/approve/, permission: 'loan.approve' },
  { method: 'POST', pattern: /^\/loans\/[^/]+\/reject/, permission: 'loan.approve' },
  { method: 'POST', pattern: /^\/loans\/[^/]+\/disburse/, permission: 'loan.disburse' },
  { method: 'POST', pattern: /^\/loans/, permission: 'loan.write' },
  { method: 'PATCH', pattern: /^\/loans/, permission: 'loan.write' },
  { method: 'PUT', pattern: /^\/loans/, permission: 'loan.write' },
  { method: 'DELETE', pattern: /^\/loans/, permission: 'loan.approve' },
  { method: 'GET', pattern: /^\/loans/, permission: 'loan.read' },
  { method: 'GET', pattern: /^\/loan-approval-matrix/, permission: 'loan.read' },
  { method: 'POST', pattern: /^\/loan-approval-matrix/, permission: 'settings.write' },
  { method: 'POST', pattern: /^\/rollover/, permission: 'rollover.approve' },
  { method: 'PATCH', pattern: /^\/rollover/, permission: 'rollover.approve' },
  { method: 'GET', pattern: /^\/rollover/, permission: 'rollover.read' },
  { method: 'POST', pattern: /^\/guarantors/, permission: 'guarantor.manage' },
  { method: 'PUT', pattern: /^\/guarantors/, permission: 'guarantor.manage' },
  { method: 'DELETE', pattern: /^\/guarantors/, permission: 'guarantor.manage' },
  { method: 'GET', pattern: /^\/guarantors/, permission: 'guarantor.read' },

  // ── Fees / levies ─────────────────────────────────────────────────────────
  { method: 'POST', pattern: /^\/fee-types/, permission: 'fee.configure' },
  { method: 'PATCH', pattern: /^\/fee-types/, permission: 'fee.configure' },
  { method: 'DELETE', pattern: /^\/fee-types/, permission: 'fee.configure' },
  { method: 'GET', pattern: /^\/fee-types/, permission: 'fee.read' },
  { method: 'POST', pattern: /^\/member-fees/, permission: 'fee.write' },
  { method: 'PATCH', pattern: /^\/member-fees/, permission: 'fee.write' },
  { method: 'PUT', pattern: /^\/member-fees/, permission: 'fee.write' },
  { method: 'DELETE', pattern: /^\/member-fees/, permission: 'fee.write' },
  { method: 'GET', pattern: /^\/member-fees/, permission: 'fee.read' },

  // ── Configuration ─────────────────────────────────────────────────────────
  { method: 'POST', pattern: /^\/feature-flags/, permission: 'feature_flag.write' },
  { method: 'PATCH', pattern: /^\/feature-flags/, permission: 'feature_flag.write' },
  { method: 'PUT', pattern: /^\/feature-flags/, permission: 'feature_flag.write' },
  { method: 'GET', pattern: /^\/feature-flags/, permission: 'settings.read' },
  { method: 'POST', pattern: /^\/mobile-features/, permission: 'feature_flag.write' },
  { method: 'PATCH', pattern: /^\/mobile-features/, permission: 'feature_flag.write' },
  { method: 'PUT', pattern: /^\/mobile-features/, permission: 'feature_flag.write' },
  { method: 'GET', pattern: /^\/mobile-features/, permission: 'settings.read' },
  { method: 'POST', pattern: /^\/system-settings/, permission: 'settings.write' },
  { method: 'PATCH', pattern: /^\/system-settings/, permission: 'settings.write' },
  { method: 'PUT', pattern: /^\/system-settings/, permission: 'settings.write' },
  { method: 'DELETE', pattern: /^\/system-settings/, permission: 'settings.write' },
  { method: 'GET', pattern: /^\/system-settings/, permission: 'settings.read' },
  { method: 'POST', pattern: /^\/interest-rates/, permission: 'settings.write' },
  { method: 'PATCH', pattern: /^\/interest-rates/, permission: 'settings.write' },
  { method: 'GET', pattern: /^\/interest-rates/, permission: 'settings.read' },

  // ── Organisations and remittances ─────────────────────────────────────────
  { method: 'POST', pattern: /^\/organizations\/(assign|unassign)/, permission: 'organization.assign' },
  { method: 'POST', pattern: /^\/organizations\/pending-requests/, permission: 'organization.assign' },
  { method: 'POST', pattern: /^\/organizations/, permission: 'organization.write' },
  { method: 'PATCH', pattern: /^\/organizations/, permission: 'organization.write' },
  { method: 'PUT', pattern: /^\/organizations/, permission: 'organization.write' },
  { method: 'DELETE', pattern: /^\/organizations/, permission: 'organization.write' },
  { method: 'GET', pattern: /^\/organizations/, permission: 'organization.read' },
  { method: 'GET', pattern: /^\/payroll/, permission: 'remittance.read' },
  { method: 'POST', pattern: /^\/payroll/, permission: 'remittance.write' },

  // ── Support / communication ───────────────────────────────────────────────
  { method: 'POST', pattern: /^\/notifications/, permission: 'notification.send' },
  { method: 'PATCH', pattern: /^\/notifications/, permission: 'notification.read' },
  { method: 'DELETE', pattern: /^\/scheduled-notifications/, permission: 'notification.send' },
  { method: 'POST', pattern: /^\/scheduled-notifications/, permission: 'notification.send' },
  { method: 'GET', pattern: /^\/scheduled-notifications/, permission: 'notification.read' },
  { method: 'GET', pattern: /^\/notification-templates/, permission: 'notification.read' },
  { method: 'POST', pattern: /^\/notification-templates/, permission: 'notification.send' },

  // Announcements: publishing is a communication action; reading the catalogue
  // to review past announcements is a read.
  { method: 'POST', pattern: /^\/announcements/, permission: 'notification.send' },
  { method: 'PATCH', pattern: /^\/announcements/, permission: 'notification.send' },
  { method: 'PUT', pattern: /^\/announcements/, permission: 'notification.send' },
  { method: 'DELETE', pattern: /^\/announcements/, permission: 'notification.send' },
  { method: 'GET', pattern: /^\/announcements/, permission: 'notification.read' },

  // Direct messages to a single member. Sending is the same authority as any
  // other outbound communication; the thread view is a read.
  { method: 'POST', pattern: /^\/direct-messages/, permission: 'notification.send' },
  { method: 'GET', pattern: /^\/direct-messages/, permission: 'notification.read' },
  { method: 'GET', pattern: /^\/notifications/, permission: 'notification.read' },
  { method: 'POST', pattern: /^\/support/, permission: 'ticket.write' },
  { method: 'PATCH', pattern: /^\/support/, permission: 'ticket.write' },
  { method: 'GET', pattern: /^\/support/, permission: 'ticket.read' },
  { method: 'POST', pattern: /^\/tickets/, permission: 'ticket.write' },
  { method: 'PATCH', pattern: /^\/tickets/, permission: 'ticket.write' },
  { method: 'GET', pattern: /^\/tickets/, permission: 'ticket.read' },
  { method: 'PUT', pattern: /^\/referrals/, permission: 'referral.manage' },
  { method: 'POST', pattern: /^\/referrals/, permission: 'referral.manage' },
  { method: 'GET', pattern: /^\/referrals/, permission: 'referral.read' },

  // ── Compliance / risk / audit ─────────────────────────────────────────────
  { method: 'POST', pattern: /^\/compliance/, permission: 'compliance.approve' },
  { method: 'PATCH', pattern: /^\/compliance/, permission: 'compliance.approve' },
  { method: 'GET', pattern: /^\/compliance/, permission: 'compliance.read' },
  { method: 'GET', pattern: /^\/risk-scoring/, permission: 'risk.read' },
  { method: 'GET', pattern: /^\/analytics/, permission: 'dashboard.read' },
  { method: 'GET', pattern: /^\/audit-logs/, permission: 'audit.read' },
  { method: 'GET', pattern: /^\/login-history/, permission: 'audit.read' },
  { method: 'POST', pattern: /^\/security/, permission: 'fraud.manage' },
  { method: 'PATCH', pattern: /^\/security/, permission: 'fraud.manage' },
  { method: 'GET', pattern: /^\/security/, permission: 'fraud.read' },
  { method: 'DELETE', pattern: /^\/fraud-detection/, permission: 'fraud.manage' },
  { method: 'PATCH', pattern: /^\/fraud-detection/, permission: 'fraud.manage' },
  { method: 'GET', pattern: /^\/fraud-detection/, permission: 'fraud.read' },
  { method: 'DELETE', pattern: /^\/sessions/, permission: 'session.manage' },
  { method: 'POST', pattern: /^\/sessions/, permission: 'session.manage' },
  { method: 'GET', pattern: /^\/sessions/, permission: 'session.manage' },
  { method: 'POST', pattern: /^\/logout-events/, permission: 'session.manage' },

  // ── Reporting ─────────────────────────────────────────────────────────────
  { method: 'POST', pattern: /^\/reports\/scheduled/, permission: 'report.manage' },
  { method: 'DELETE', pattern: /^\/reports\/scheduled/, permission: 'report.manage' },
  // The reporting router is mounted at /reports, so its own paths arrive here
  // as /catalog, /run/:id, /export/:id — all reads.
  { method: 'GET', pattern: /^\/catalog/, permission: 'report.read' },
  { method: 'GET', pattern: /^\/run\//, permission: 'report.read' },
  { method: 'GET', pattern: /^\/export\//, permission: 'report.read' },
  { method: 'GET', pattern: /^\/reports/, permission: 'report.read' },
  { method: 'POST', pattern: /^\/comparative/, permission: 'report.read' },
  { method: 'GET', pattern: /^\/comparative/, permission: 'report.read' },
  // Comparative router mounted at /comparative → /compare, /options, /drilldown
  { method: 'GET', pattern: /^\/compare/, permission: 'report.read' },
  { method: 'GET', pattern: /^\/options/, permission: 'report.read' },
  { method: 'GET', pattern: /^\/drilldown/, permission: 'report.read' },
  // Organization-finance router mounted at /organizations → /finance, /pending-requests
  { method: 'GET', pattern: /^\/finance/, permission: 'organization.read' },
  { method: 'GET', pattern: /^\/pending-requests/, permission: 'organization.read' },
  { method: 'POST', pattern: /^\/pending-requests/, permission: 'organization.assign' },
  { method: 'POST', pattern: /^\/assign/, permission: 'organization.assign' },
  { method: 'POST', pattern: /^\/unassign/, permission: 'organization.assign' },
  { method: 'GET', pattern: /^\/[^/]+\/finance$/, permission: 'organization.read' },
  { method: 'GET', pattern: /^\/[^/]+\/trend$/, permission: 'organization.read' },

  // ── Platform administration ───────────────────────────────────────────────
  { method: 'POST', pattern: /^\/backups?/, permission: 'backup.write' },
  { method: 'DELETE', pattern: /^\/backups?/, permission: 'backup.write' },
  { method: 'GET', pattern: /^\/backups?/, permission: 'backup.read' },
  { method: 'POST', pattern: /^\/emergency-controls/, permission: 'emergency.use' },
  { method: 'GET', pattern: /^\/emergency-controls/, permission: 'emergency.use' },
  { method: 'POST', pattern: /^\/excel-uploads/, permission: 'member.import' },
  { method: 'GET', pattern: /^\/excel-uploads/, permission: 'member.read' },
  { method: 'GET', pattern: /^\/documents/, permission: 'member.read' },
  { method: 'POST', pattern: /^\/documents/, permission: 'member.write' },
  { method: 'GET', pattern: /^\/overview/, permission: 'dashboard.read' },
  { method: 'GET', pattern: /^\/dashboard/, permission: 'dashboard.read' },
  { method: 'GET', pattern: /^\/attention/, permission: 'dashboard.read' },
  { method: 'GET', pattern: /^\/search/, permission: 'dashboard.read' },
  { method: 'GET', pattern: /^\/investments/, permission: 'report.read' },
  { method: 'DELETE', pattern: /^\/investments/, permission: 'reversal.approve' },
  { method: 'GET', pattern: /^\/savings/, permission: 'report.read' },
  { method: 'GET', pattern: /^\/transactions/, permission: 'ledger.read' },
  { method: 'GET', pattern: /^\/platform-analytics/, permission: 'dashboard.read' },
  { method: 'GET', pattern: /^\/terminations/, permission: 'member.read' },
  { method: 'POST', pattern: /^\/terminations/, permission: 'member.write' },
  { method: 'POST', pattern: /^\/backfill/, permission: 'system.debug' },
  { method: 'POST', pattern: /^\/governance/, permission: 'system.debug' },
];

// Permission required when a write path is not classified above. Deliberately
// the highest authority: an unclassified new endpoint is denied until someone
// classifies it, rather than silently being open.
const FALLBACK_WRITE_PERMISSION = 'settings.write';
// Permission required for an unclassified read. Kept low so tightening writes
// never locks a role out of a screen.
const FALLBACK_READ_PERMISSION = 'dashboard.read';

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

/**
 * Find the permission requirement for a request.
 *
 * @param {string} method  HTTP method
 * @param {string} path    path relative to the admin mount (e.g. '/members/1')
 * @returns {{permission: string|null, skipPermissionCheck: boolean, matched: boolean}}
 */
function requirementFor(method, path) {
  const m = String(method || '').toUpperCase();
  // Normalise a trailing slash so '/members/' matches '/members'.
  const p = path && path.length > 1 ? path.replace(/\/+$/, '') : path || '/';

  for (const rule of ROUTE_PERMISSIONS) {
    if (rule.method !== m) continue;
    if (rule.pattern.test(p)) {
      return {
        permission: rule.permission || null,
        skipPermissionCheck: Boolean(rule.skipPermissionCheck),
        matched: true,
      };
    }
  }

  return {
    permission: SAFE_METHODS.has(m) ? FALLBACK_READ_PERMISSION : FALLBACK_WRITE_PERMISSION,
    skipPermissionCheck: false,
    matched: false,
  };
}

/**
 * Express middleware: authenticate, resolve the role, and require the
 * permission the path maps to.
 */
function requirePermission(req, res, next) {
  const { authenticate } = require('./auth');

  return authenticate(req, res, () => {
    const roleKey = RBAC.resolveRole(req.user?.role);
    if (!roleKey) {
      // No resolvable role — reject rather than assume anything.
      return res.status(403).json({
        success: false,
        error: 'Your account has no recognised role. Contact the system administrator.',
        code: 'NO_ROLE',
      });
    }

    // A member must never reach the admin surface, whatever the path.
    if (roleKey === 'member') {
      return res.status(403).json({
        success: false,
        error: 'Admin access required',
        code: 'MEMBER_ACCOUNT',
      });
    }

    const requirement = requirementFor(req.method, req.path);
    if (requirement.skipPermissionCheck) return next();

    const extra = {
      permissions: req.user.permissions,
      custom_permissions: req.user.custom_permissions,
    };

    if (requirement.permission && RBAC.hasPermission(req.user.role, requirement.permission, extra)) {
      // Expose the resolved authority so handlers and logs do not re-derive it.
      req.rbac = {
        role: roleKey,
        permission: requirement.permission,
        unmatched: !requirement.matched,
      };
      return next();
    }

    return res.status(403).json({
      success: false,
      error: `Your role (${RBAC.roleDefinition(req.user.role)?.label || roleKey}) is not permitted to perform this action.`,
      code: 'INSUFFICIENT_PERMISSION',
      required: requirement.permission,
    });
  });
}

module.exports = {
  ROUTE_PERMISSIONS,
  FALLBACK_WRITE_PERMISSION,
  FALLBACK_READ_PERMISSION,
  requirementFor,
  requirePermission,
};
