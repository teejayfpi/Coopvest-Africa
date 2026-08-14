/**
 * System-status middleware: maintenance mode + minimum app version.
 *
 * Reads from `system_settings` rows:
 *   - `maintenance.enabled`    -> { enabled: boolean, message?: string }
 *   - `app.min_version`        -> { ios?: string, android?: string, web?: string }
 *
 * Uses a small TTL cache so every member request doesn't hit the DB.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const CACHE_TTL_MS = 15 * 1000;
let cache = { at: 0, data: null };

const SETTING_KEYS = [
  'maintenance.enabled',
  'app.min_version',
  'emergency.freeze_loans',
  'emergency.freeze_withdrawals',
  'emergency.freeze_registration',
  'emergency.freeze_contribution_adjustments',
  'emergency.freeze_payment_proof_approval',
  'emergency.read_only',
  'emergency.message',
];

async function loadSettings() {
  if (Date.now() - cache.at < CACHE_TTL_MS && cache.data) return cache.data;
  try {
    const { data } = await supabase
      .from('system_settings')
      .select('*')
      .in('key', SETTING_KEYS);
    const byKey = {};
    for (const row of data || []) byKey[row.key] = row.value;
    cache = { at: Date.now(), data: byKey };
    return byKey;
  } catch (err) {
    logger.warn('systemStatus: settings load failed:', err.message);
    return cache.data || {};
  }
}

function cmpVersion(a, b) {
  const pa = String(a || '0').split('.').map((n) => parseInt(n, 10) || 0);
  const pb = String(b || '0').split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] || 0;
    const y = pb[i] || 0;
    if (x !== y) return x - y;
  }
  return 0;
}

// Admin routes are never blocked by emergency freezes — the Super Admin must
// always be able to reach the dashboard to lift a freeze.
function isBypassPath(path) {
  return (
    path.startsWith('/api/v2/admin') ||
    path.startsWith('/api/v1/admin') ||
    path.startsWith('/api/admin') ||
    path.startsWith('/api/v1/auth') ||
    path.startsWith('/api/auth') ||
    path === '/health' ||
    path === '/healthz' ||
    path === '/'
  );
}

// Map an emergency freeze flag to the request paths it blocks (write methods
// only — reads stay available so members can still see their balances).
function freezeViolation(path, method, settings) {
  const isWrite = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method);
  if (!isWrite) return null;

  if (settings['emergency.read_only'] === true) {
    return { kind: 'read_only', message: settings['emergency.message'] || 'The system is temporarily in read-only mode.' };
  }
  if (settings['emergency.freeze_loans'] === true && /\/(api|api\/v1)\/loans(\/|$)/.test(path)) {
    return { kind: 'freeze_loans', message: 'New loan applications are temporarily frozen.' };
  }
  if (settings['emergency.freeze_withdrawals'] === true && /\/(api|api\/v1)\/(wallet|savings).*(withdraw|payout)/.test(path)) {
    return { kind: 'freeze_withdrawals', message: 'Withdrawals are temporarily frozen.' };
  }
  if (settings['emergency.freeze_registration'] === true && /\/(api|api\/v1)\/auth\/(register|signup)/.test(path)) {
    return { kind: 'freeze_registration', message: 'New registrations are temporarily frozen.' };
  }
  if (settings['emergency.freeze_contribution_adjustments'] === true && /\/(api|api\/v1)\/contributions/.test(path)) {
    return { kind: 'freeze_contributions', message: 'Contribution adjustments are temporarily frozen.' };
  }
  return null;
}

async function enforceSystemStatus(req, res, next) {
  try {
    if (isBypassPath(req.path)) return next();
    const settings = await loadSettings();

    const m = settings['maintenance.enabled'];
    if (m && (m === true || m.enabled === true)) {
      return res.status(503).json({
        success: false,
        maintenance: true,
        message:
          (m && m.message) ||
          'The app is temporarily unavailable for maintenance. Please try again soon.',
      });
    }

    const violation = freezeViolation(req.path, req.method, settings);
    if (violation) {
      return res.status(423).json({ success: false, locked: true, reason: violation.kind, message: violation.message });
    }

    const minVersion = settings['app.min_version'];
    if (minVersion) {
      const platform = String(req.get('X-App-Platform') || '').toLowerCase();
      const appVersion = String(req.get('X-App-Version') || '').trim();
      const required = platform && minVersion[platform];
      if (required && appVersion && cmpVersion(appVersion, required) < 0) {
        return res.status(426).json({
          success: false,
          forceUpdate: true,
          minVersion: required,
          currentVersion: appVersion,
          message: `Please update the app to version ${required} or higher to continue.`,
        });
      }
    }

    return next();
  } catch (err) {
    logger.warn('systemStatus: middleware error:', err.message);
    return next();
  }
}

module.exports = { enforceSystemStatus };
