/**
 * Loan Approval Matrix — maker-checker thresholds.
 *
 * Reads `system_settings['loan_approval.thresholds']` (same key the Admin
 * Dashboard's Loan Approval Matrix page manages) and decides whether a given
 * admin role may approve a loan of a given amount outright, or whether the
 * approval must go through the Approval Center (Super Admin = checker).
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const rbac = require('./permissions');

const SUPER_ADMIN_ROLES = ['superadmin', 'super_admin'];
const SETTING_KEY = 'loan_approval.thresholds';
const UNLIMITED = 1e12; // JSON cannot represent Infinity; treat anything above this as unlimited

const DEFAULT_THRESHOLDS = {
  levels: [
    // Historical spellings kept so an existing configured setting is unaffected.
    { level: 1, maxAmount: 100000, role: 'staff' },
    { level: 2, maxAmount: 1000000, role: 'admin' },
    // Canonical names for the same tiers, so the new role vocabulary resolves to
    // a usable limit instead of falling through to zero. `manager` is
    // deliberately the staff-level figure: collapsing tiers must not widen
    // authority.
    { level: 1, maxAmount: 100000, role: 'manager' },
    // Operations may approve ordinary loans outright. Anything larger still
    // routes to the Approval Center.
    { level: 2, maxAmount: 1000000, role: 'coo' },
    { level: 3, maxAmount: UNLIMITED + 1, role: 'super_admin' },
    { level: 3, maxAmount: UNLIMITED + 1, role: 'ceo' },
  ],
};

/**
 * Canonical role key for threshold matching.
 *
 * The stored thresholds use the historical spellings (`staff`, `admin`,
 * `super_admin`). Now that roles have canonical names, comparing the raw string
 * would be wrong: a user stored as `ceo` or `manager` would match no level and
 * fall through to a limit of ZERO, forcing even an apex approver to route their
 * own loans to the Approval Center. Resolving first keeps the configured
 * thresholds working under either spelling.
 */
function canonicalRole(role) {
  return rbac.resolveRole(role) || null;
}

/** The role names a level may legitimately declare for a given canonical role. */
function roleSpellingsFor(canonical) {
  const def = canonical ? rbac.ROLES[canonical] : null;
  return def ? [def.key, ...def.legacy] : [];
}

async function getThresholds() {
  try {
    const { data } = await supabase
      .from('system_settings')
      .select('value')
      .eq('key', SETTING_KEY)
      .maybeSingle();
    if (data?.value && Array.isArray(data.value.levels)) return data.value;
  } catch (err) {
    logger.warn('approvalMatrix: failed to load thresholds, using defaults:', err.message);
  }
  return DEFAULT_THRESHOLDS;
}

/** Maximum amount this role may approve outright (Infinity = unlimited). */
function maxApprovableAmount(role, thresholds) {
  const canonical = canonicalRole(role);

  // Apex authority is unlimited regardless of how the thresholds are written,
  // so a misconfigured level list can never force the CEO through their own
  // approval gate.
  if (canonical === 'ceo') return Infinity;
  if (SUPER_ADMIN_ROLES.includes(role || '')) return Infinity;

  // No resolvable role — refuse rather than invent a limit.
  if (!canonical) return 0;

  const normalised = String(role || '').toLowerCase();

  // 1. An EXACT spelling match wins. This preserves the documented behaviour
  //    that `admin` keeps its own 1,000,000 level and `staff` keeps 100,000, and
  //    that repeating a role takes the highest of its entries (an operator's
  //    explicit override).
  const exact = (thresholds?.levels || []).filter(
    (l) => String(l.role || '').toLowerCase() === normalised,
  );
  if (exact.length > 0) {
    const max = exact.reduce((m, l) => Math.max(m, Number(l.maxAmount) || 0), 0);
    return max > UNLIMITED ? Infinity : max;
  }

  // 2. No exact entry. Fall back to the levels that share this canonical role
  //    (e.g. the new name `manager` under a settings list storing staff/admin),
  //    and take the MOST RESTRICTIVE. Where a canonical role subsumes several
  //    historical tiers, taking the highest would widen authority: a staff
  //    approver capped at 100,000 must not inherit admin's 1,000,000 merely
  //    because the two now share a role.
  const spellings = new Set(roleSpellingsFor(canonical));
  const collapsed = (thresholds?.levels || []).filter(
    (l) => spellings.has(String(l.role || '').toLowerCase()),
  );
  if (collapsed.length === 0) {
    // A role with no configured level cannot approve anything outright, so the
    // request goes to the Approval Center rather than through it.
    return 0;
  }
  const min = collapsed.reduce((m, l) => Math.min(m, Number(l.maxAmount) || 0), Infinity);
  return min > UNLIMITED ? Infinity : min;
}

/** True when this role must route a loan of `amount` through the Approval Center. */
async function requiresSuperAdminApproval(role, amount) {
  const thresholds = await getThresholds();
  const limit = maxApprovableAmount(role, thresholds);
  return Number(amount) > limit;
}

module.exports = {
  SUPER_ADMIN_ROLES,
  DEFAULT_THRESHOLDS,
  getThresholds,
  maxApprovableAmount,
  requiresSuperAdminApproval,
};
