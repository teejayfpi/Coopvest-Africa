/**
 * Remote feature-flag enforcement.
 *
 * Flags are stored in `system_settings` under keys prefixed with
 * `feature_flag.` (e.g. `feature_flag.loanModule`). The admin dashboard
 * toggles these via the cross-backend admin API; mobile routes check them
 * via `requireFeatureFlag('loanModule')`.
 *
 * A flag is considered ENABLED when its stored value is `true`, the string
 * `"true"`, or an object of shape `{ enabled: true, ... }`. Missing flags
 * default to enabled (fail-open) so a brand-new install keeps working.
 *
 * FIX: value column may be TEXT rather than JSONB in some Supabase setups.
 * We now parse string values before checking .enabled so a seeded row of
 * `{ enabled: true }` stored as JSON text doesn't silently disable features.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const REQUIRED_FLAGS = [
  'loanModule',
  'savingsModule',
  'investmentModule',
  'referralSystem',
  'walletTransfers',
  'withdrawalRequests',
  'memberRegistration',
  'statementDownloads',
  'notifications',
  'qrReferralSystem',
];

const CACHE_TTL_MS = 15 * 1000;
let cache = { at: 0, map: new Map() };

/**
 * Parse a raw Supabase value into a boolean enabled state.
 * Handles: boolean true, string "true", JSONB object { enabled: true },
 * and JSON string '{"enabled":true,...}' (TEXT column case).
 */
function parseEnabled(rawValue) {
  if (rawValue === true || rawValue === 'true') return true;
  if (rawValue === false || rawValue === 'false' || rawValue === null || rawValue === undefined) return false;
  let val = rawValue;
  if (typeof val === 'string') {
    try { val = JSON.parse(val); } catch (_) { return false; }
  }
  return val?.enabled === true;
}

async function loadAllFlags() {
  if (Date.now() - cache.at < CACHE_TTL_MS && cache.map.size > 0) return cache.map;
  try {
    const { data } = await supabase
      .from('system_settings')
      .select('*')
      .like('key', 'feature_flag.%');
    const map = new Map();
    for (const row of data || []) {
      const k = row.key.replace(/^feature_flag\./, '');
      map.set(k, parseEnabled(row.value));
    }
    cache = { at: Date.now(), map };
    return map;
  } catch (err) {
    logger.warn('featureFlags: load failed:', err.message);
    return cache.map;
  }
}

function invalidateCache() {
  cache = { at: 0, map: new Map() };
}

function requireFeatureFlag(flag) {
  return async function featureFlagMiddleware(req, res, next) {
    try {
      const map = await loadAllFlags();
      if (!map.has(flag)) return next(); // default: enabled (fail-open)
      if (map.get(flag) === true) return next();
      return res.status(503).json({
        success: false,
        featureDisabled: flag,
        message: `The ${flag} feature is currently disabled by the administrator.`,
      });
    } catch (err) {
      logger.warn('featureFlags: middleware error:', err.message);
      return next();
    }
  };
}

async function seedRequiredFlags() {
  try {
    const { data } = await supabase
      .from('system_settings')
      .select('key')
      .like('key', 'feature_flag.%');
    const existing = new Set((data || []).map((r) => r.key));
    const rows = REQUIRED_FLAGS
      .filter((f) => !existing.has(`feature_flag.${f}`))
      .map((f) => ({
        key: `feature_flag.${f}`,
        value: { enabled: true, payload: null },
        description: `Remote toggle for the ${f} module`,
        updated_at: new Date().toISOString(),
      }));
    if (rows.length > 0) {
      await supabase.from('system_settings').insert(rows);
      logger.info(`featureFlags: seeded ${rows.length} required flags`);
    }
  } catch (err) {
    logger.warn('featureFlags: seed failed:', err.message);
  }
}

module.exports = { requireFeatureFlag, seedRequiredFlags, invalidateCache, REQUIRED_FLAGS };
