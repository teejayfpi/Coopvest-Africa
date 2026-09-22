/**
 * Role-based access control — the server-side source of truth.
 *
 * BEFORE THIS FILE, admin authorisation was effectively binary: `requireAdmin`
 * admitted any of admin / superadmin / staff, and only 8 of the 67 write
 * endpoints in adminApi carried an additional inline role check. A `staff` user
 * could therefore delete contributions, approve loans, verify deposits, run
 * bulk member imports, and reset member passwords — all with no extra
 * authority. The dashboard's own permission map is frontend-only and cannot
 * prevent a direct API call.
 *
 * Two design decisions:
 *
 *   1. The catalog below is the SINGLE source of truth, consumed both by the
 *      enforcement middleware and by `GET /admin/permissions` for the UI, so the
 *      two cannot drift.
 *
 *   2. Unknown roles and unknown permissions fail CLOSED. A role the catalog has
 *      never heard of gets only the permissions explicitly listed for it, never
 *      a wildcard; an unrecognised permission name is denied rather than allowed.
 *
 * Role taxonomy (the six the business asked for, mapped onto the pre-existing
 * `superadmin`/`admin`/`staff` spellings so existing rows stay valid):
 *
 *   ceo                  Apex authority. Everything.
 *   coo                  Operations across the platform, but not role/system
 *                        administration or financial reversal.
 *   legal_adviser        Read-everything plus compliance/KYC decisions, so legal
 *                        can discharge oversight without moving money.
 *   chief_system_analyst System/technical administration: feature flags, system
 *                        settings, roles, backups, audit.
 *   manager              Operational member management: members, loans,
 *                        contributions, approvals within limits.
 *   system_analyst       Technical/support, read-mostly: tickets, lookups,
 *                        operational reporting. No financial writes.
 */

// ── permission catalog ───────────────────────────────────────────────────────
// Names are `<domain>.<action>`. `*.read` grants visibility; `*.write` mutates.

const PERMISSIONS = {
  // Dashboards and reporting
  'dashboard.read': 'View dashboards and headline figures',
  'report.read': 'View and export reports',
  'report.manage': 'Create and schedule reports',

  // Members
  'member.read': 'View member records',
  'member.write': 'Edit member details',
  'member.verify': 'Verify KYC and member identity',
  'member.delete': 'Delete a member and their records',
  'member.password_reset': 'Reset a member password',
  'member.import': 'Bulk import members',

  // Money in
  'deposit.read': 'View deposits',
  'deposit.verify': 'Verify or reject deposits',
  'contribution.read': 'View contributions',
  'contribution.write': 'Edit contributions',
  'contribution.delete': 'Delete a contribution',
  'payment_proof.read': 'View payment proofs',
  'payment_proof.approve': 'Approve or reject payment proofs',

  // Money out / balances
  'withdrawal.read': 'View withdrawals',
  'withdrawal.approve': 'Approve or reject withdrawals',
  'wallet.read': 'View wallets and balances',
  'wallet.adjust': 'Adjust a wallet balance',
  'ledger.read': 'View the ledger and accounting reports',
  'ledger.post': 'Post manual journal entries',
  'reversal.approve': 'Reverse or void a posted transaction',

  // Loans
  'loan.read': 'View loans',
  'loan.approve': 'Approve or reject loan applications',
  'loan.disburse': 'Disburse loans',
  'loan.write': 'Edit loan records',
  'rollover.read': 'View rollovers',
  'rollover.approve': 'Approve rollovers',
  'guarantor.read': 'View guarantors',
  'guarantor.manage': 'Manage guarantor settings and requests',

  // Fees / levies / configuration
  'fee.read': 'View fees and levies',
  'fee.write': 'Assign or waive fees',
  'fee.configure': 'Configure fee types and amounts',
  'settings.read': 'View system settings',
  'settings.write': 'Change system settings and business parameters',
  'feature_flag.write': 'Enable or disable app features',

  // Organisations
  'organization.read': 'View organizations',
  'organization.write': 'Create or edit organizations',
  'organization.assign': 'Link members to organizations',
  'remittance.read': 'View remittances',
  'remittance.write': 'Record or reconcile remittances',

  // Support and communication
  'notification.read': 'View notifications',
  'notification.send': 'Send notifications to members',
  'ticket.read': 'View support tickets',
  'ticket.write': 'Resolve support tickets',
  'referral.read': 'View referrals',
  'referral.manage': 'Manage referral settings',

  // Risk / compliance / audit
  'compliance.read': 'View compliance records',
  'compliance.approve': 'Approve or reject compliance cases',
  'audit.read': 'View audit logs',
  'fraud.read': 'View fraud/security flags',
  'fraud.manage': 'Resolve fraud/security flags',
  'session.manage': 'Manage sessions and terminate logins',

  // Platform administration
  'role.read': 'View roles and permissions',
  'role.write': 'Assign roles and change permissions',
  'backup.read': 'View backups',
  'backup.write': 'Create or restore backups',
  'emergency.use': 'Use emergency controls',
  'system.debug': 'Run diagnostic and maintenance endpoints',
};

const ALL_PERMISSIONS = Object.keys(PERMISSIONS);

// Read-only permissions, derived from the catalog rather than listed twice, so
// adding a `.read` permission automatically makes it visible to read-only roles
// that are defined as "every read".
const READ_ONLY_PERMISSIONS = ALL_PERMISSIONS.filter((p) => p.endsWith('.read'));

// ── roles ────────────────────────────────────────────────────────────────────

/**
 * Role definitions.
 *
 * `legacy` lists the `profiles.role` spellings this role is stored as, so
 * `staff` continues to resolve to `manager` and existing rows keep working.
 */
const ROLES = {
  ceo: {
    key: 'ceo',
    label: 'CEO',
    description: 'Apex authority. Full access to everything.',
    rank: 100,
    // `superadmin` / `super_admin` are the pre-existing spellings of apex
    // authority and MUST map here. Mapping them to a lesser role would strip
    // access from the only admin account in production.
    legacy: ['ceo', 'superadmin', 'super_admin'],
    permissions: ALL_PERMISSIONS,
  },

  coo: {
    key: 'coo',
    label: 'COO',
    description: 'Operations across the platform. No role administration, no direct balance or ledger writes.',
    rank: 80,
    legacy: ['coo'],
    // Direct balance and ledger writes are excluded on purpose. Moving money
    // should go through the approval workflow rather than one operational role
    // holding the authority outright, which is the separation the business asked
    // for. COO can approve loans, withdrawals and rollovers — the ordinary
    // operational decisions — but not rewrite a balance.
    //
    // `member.password_reset` is also excluded: it is the shortest path to
    // taking over an account, so it belongs with apex authority only.
    permissions: ALL_PERMISSIONS.filter((p) => ![
      'role.write', 'settings.write', 'feature_flag.write', 'emergency.use',
      'reversal.approve', 'system.debug', 'backup.write', 'member.delete',
      'wallet.adjust', 'ledger.post', 'contribution.delete', 'member.password_reset',
    ].includes(p)),
  },

  chief_system_analyst: {
    key: 'chief_system_analyst',
    label: 'Chief System Analyst',
    description: 'System and technical administration.',
    rank: 70,
    legacy: ['chief_system_analyst', 'cto'],
    permissions: [
      ...READ_ONLY_PERMISSIONS,
      'settings.read', 'settings.write', 'feature_flag.write',
      'role.read', 'role.write', 'audit.read',
      'backup.read', 'backup.write', 'emergency.use', 'system.debug',
      'report.manage', 'notification.send',
    ],
  },

  legal_adviser: {
    key: 'legal_adviser',
    label: 'Legal Adviser / Compliance Officer',
    description: 'Legal and compliance oversight with full visibility, but no operational writes.',
    rank: 60,
    legacy: ['legal_adviser', 'legal', 'compliance_officer'],
    permissions: [
      ...READ_ONLY_PERMISSIONS,
      'compliance.read', 'compliance.approve',
      'audit.read', 'risk.read',
      'member.verify', 'report.manage',
    ].filter((p) => p !== undefined),
  },

  manager: {
    key: 'manager',
    label: 'Manager',
    description: 'Operational member management: members, loans, contributions and approvals.',
    rank: 50,
    // `staff` and `admin` both resolve here so the two pre-existing spellings
    // keep a coherent, reduced authority rather than one being a wildcard.
    legacy: ['manager', 'admin', 'staff', 'operator'],
    permissions: [
      'dashboard.read', 'report.read', 'report.manage',
      'member.read', 'member.write', 'member.verify',
      'deposit.read', 'deposit.verify',
      'contribution.read', 'contribution.write',
      'payment_proof.read', 'payment_proof.approve',
      'withdrawal.read', 'withdrawal.approve',
      'wallet.read',
      'loan.read', 'loan.approve', 'loan.write',
      'rollover.read', 'rollover.approve',
      'guarantor.read', 'guarantor.manage',
      'fee.read', 'fee.write',
      'organization.read', 'organization.assign',
      'remittance.read',
      'notification.read', 'notification.send',
      'ticket.read', 'ticket.write',
      'referral.read',
      'compliance.read', 'audit.read', 'fraud.read',
      'settings.read',
    ],
  },

  system_analyst: {
    key: 'system_analyst',
    label: 'System Analyst',
    description: 'Technical and support functions, read-mostly. No financial or member writes.',
    rank: 40,
    legacy: ['system_analyst', 'analyst', 'viewer'],
    permissions: [
      'dashboard.read', 'report.read',
      'member.read',
      'deposit.read', 'contribution.read', 'payment_proof.read',
      'withdrawal.read', 'wallet.read', 'ledger.read',
      'loan.read', 'rollover.read', 'guarantor.read',
      'fee.read', 'settings.read',
      'organization.read', 'remittance.read',
      'notification.read', 'ticket.read', 'ticket.write',
      'referral.read',
      'compliance.read', 'audit.read', 'fraud.read',
      'role.read',
    ],
  },

  // A member has no admin permissions at all.
  member: {
    key: 'member',
    label: 'Member',
    description: 'No admin dashboard access.',
    rank: 0,
    legacy: ['member'],
    permissions: [],
  },
};

// `risk.read` is used by legal_adviser above; keep the catalog honest.
if (!PERMISSIONS['risk.read']) {
  PERMISSIONS['risk.read'] = 'View risk scoring';
  ALL_PERMISSIONS.push('risk.read');
  READ_ONLY_PERMISSIONS.push('risk.read');
}

// Build the legacy-spelling lookup once.
const ROLE_BY_LEGACY = new Map();
for (const role of Object.values(ROLES)) {
  for (const spelling of role.legacy) {
    ROLE_BY_LEGACY.set(String(spelling).toLowerCase(), role.key);
  }
}

/**
 * Resolve any `profiles.role` spelling to a canonical role key.
 * Unknown roles resolve to `null` and are treated as having no permissions.
 */
function resolveRole(raw) {
  if (!raw) return null;
  const key = String(raw).trim().toLowerCase();
  if (ROLES[key]) return key;                    // already canonical
  return ROLE_BY_LEGACY.get(key) || null;        // a legacy spelling
}

/** Canonical role definition, or null for an unknown role. */
function roleDefinition(raw) {
  const key = resolveRole(raw);
  return key ? ROLES[key] : null;
}

/**
 * Effective permissions for a role.
 *
 * A row's own `permissions` / `custom_permissions` are honoured as an ADDITIVE
 * grant (extra permissions beyond the role), never as a removal, so a grant
 * cannot be silently lost. An unknown role yields only whatever is explicitly
 * granted on the row — never a wildcard.
 */
function permissionsFor(rawRole, extra = {}) {
  const role = roleDefinition(rawRole);
  const base = role ? [...role.permissions] : [];
  const granted = []
    .concat(Array.isArray(extra.permissions) ? extra.permissions : [])
    .concat(Array.isArray(extra.custom_permissions) ? extra.custom_permissions : [])
    // Ignore anything not in the catalog, so a typo cannot widen access.
    .filter((p) => ALL_PERMISSIONS.includes(p));
  return [...new Set([...base, ...granted])];
}

/** Does this role (plus any row-level grants) hold `permission`? */
function hasPermission(rawRole, permission, extra = {}) {
  if (!permission) return false;
  if (!ALL_PERMISSIONS.includes(permission)) return false; // fail closed
  return permissionsFor(rawRole, extra).includes(permission);
}

/** Does the role hold every one of `permissions`? */
function hasAllPermissions(rawRole, permissions, extra = {}) {
  const effective = new Set(permissionsFor(rawRole, extra));
  return permissions.every((p) => ALL_PERMISSIONS.includes(p) && effective.has(p));
}

/** Role keys in descending rank, for display. */
function listRoles() {
  return Object.values(ROLES)
    .filter((r) => r.key !== 'member')
    .sort((a, b) => b.rank - a.rank)
    .map((r) => ({
      key: r.key,
      label: r.label,
      description: r.description,
      rank: r.rank,
      legacy: r.legacy,
      permissionCount: r.permissions.length,
    }));
}

function listPermissions() {
  return ALL_PERMISSIONS.map((key) => ({
    key,
    description: PERMISSIONS[key],
    readOnly: READ_ONLY_PERMISSIONS.includes(key),
  }));
}

/** Roles the backend accepts when writing `profiles.role`. */
function assignableRoleValues() {
  const values = new Set();
  for (const role of Object.values(ROLES)) {
    if (role.key === 'member') continue;
    for (const spelling of role.legacy) values.add(spelling);
  }
  return [...values];
}

module.exports = {
  PERMISSIONS,
  ALL_PERMISSIONS,
  READ_ONLY_PERMISSIONS,
  ROLES,
  resolveRole,
  roleDefinition,
  permissionsFor,
  hasPermission,
  hasAllPermissions,
  listRoles,
  listPermissions,
  assignableRoleValues,
};
