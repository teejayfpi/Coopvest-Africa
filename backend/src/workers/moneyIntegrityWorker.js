/**
 * Money-integrity sweep.
 *
 * Runs `lib/moneyIntegrity.js` on a schedule and persists the result to
 * `money_integrity_runs`. When a critical check finds a discrepancy it raises
 * an admin alert, so drift in the money tables is noticed by the system instead
 * of by a member who sees a number no transaction supports.
 *
 * Read-only: it never corrects a balance. A human decides that from the admin
 * queue (see `routes/reconciliationOps.js`).
 *
 * Disable with MONEY_INTEGRITY_WORKER_DISABLED=1.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');
const { runIntegrityChecks } = require('../lib/moneyIntegrity');

const POLL_INTERVAL_MS = 6 * 60 * 60 * 1000; // every 6 hours
const STARTUP_DELAY_MS = 2 * 60 * 1000;

let _timer = null;

/**
 * Run the checks once, persist the run, and alert on critical findings.
 *
 * @param {object} [opts]
 * @param {string} [opts.trigger] 'scheduled' | 'manual'
 * @param {string} [opts.triggeredBy] profile id, for a manual run
 * @returns {Promise<object>} the persisted run row (or a summary on failure)
 */
async function runOnce({ trigger = 'scheduled', triggeredBy = null } = {}) {
  const startedAt = Date.now();
  const { ranAt, results, totals } = await runIntegrityChecks({ db: supabase });
  const durationMs = Date.now() - startedAt;

  const row = {
    trigger,
    ran_at: ranAt,
    checks_run: totals.checksRun,
    checks_errored: totals.checksErrored,
    discrepancies: totals.discrepancies,
    critical_checks: totals.critical,
    warning_checks: totals.warning,
    results,
    duration_ms: durationMs,
    triggered_by: triggeredBy,
  };

  const { data, error } = await supabase
    .from('money_integrity_runs')
    .insert(row)
    .select()
    .maybeSingle();

  if (error) {
    // The table may not exist yet on an environment where migration 052 has not
    // been applied. Report it, but still alert on the findings — the alert is
    // the part that matters.
    logger.warn(`moneyIntegrityWorker: could not persist run: ${error.message}`);
  }

  if (totals.critical.length > 0) {
    logger.warn(`moneyIntegrityWorker: CRITICAL discrepancies in ${totals.critical.join(', ')} (${totals.discrepancies} total)`);
    await notifyService.notifyAdmins({
      title: 'Money integrity check found discrepancies',
      body: `The scheduled money-integrity check found ${totals.discrepancies} discrepancy(ies). Critical: ${totals.critical.join(', ') || 'none'}. Review the reconciliation screen before correcting any balance.`,
      type: 'system',
      category: 'warning',
      priority: 'high',
    });
  } else {
    logger.info(`moneyIntegrityWorker: clean run (${totals.checksRun} checks, ${totals.discrepancies} discrepancies)`);
  }

  return data || { ...row, persisted: false };
}

function start() {
  if (process.env.MONEY_INTEGRITY_WORKER_DISABLED === '1') {
    logger.info('moneyIntegrityWorker: disabled by MONEY_INTEGRITY_WORKER_DISABLED');
    return;
  }
  if (_timer) return;
  _timer = setInterval(() => {
    runOnce().catch((err) => logger.warn('moneyIntegrityWorker: sweep failed:', err.message));
  }, POLL_INTERVAL_MS);
  // Do not block server startup; let the first sweep land after boot settles.
  _timer.unref?.();
  setTimeout(() => {
    runOnce().catch((err) => logger.warn('moneyIntegrityWorker: initial sweep failed:', err.message));
  }, STARTUP_DELAY_MS).unref?.();
  logger.info('moneyIntegrityWorker: started (every 6h)');
}

function stop() {
  if (_timer) {
    clearInterval(_timer);
    _timer = null;
  }
}

module.exports = { start, stop, runOnce, POLL_INTERVAL_MS };
