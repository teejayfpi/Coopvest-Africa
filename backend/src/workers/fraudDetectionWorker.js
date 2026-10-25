/**
 * Fraud & AML detection worker.
 *
 * Runs the rule engine in `lib/fraudDetection.js` over recent data and upserts
 * each finding into `fraud_cases` (migration 054) keyed on `dedupe_key`, so the
 * same suspicion is raised once and then tracked to a resolution rather than
 * reappearing on every scan.
 *
 * A new *critical* finding alerts the admins. Re-finding an existing open case
 * only bumps its `occurrences`/`last_seen_at` — a case an admin has already
 * dismissed is not resurrected by a later scan (its status is left as-is).
 *
 * Detection only. It never freezes an account or moves money; a human decides
 * that from the case queue.
 *
 * Disable with FRAUD_DETECTION_WORKER_DISABLED=1.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');
const { evaluateRules } = require('../lib/fraudDetection');

const POLL_INTERVAL_MS = 12 * 60 * 60 * 1000; // every 12 hours
const STARTUP_DELAY_MS = 3 * 60 * 1000;
const SCAN_DAYS = 30;
const SCAN_LIMIT = 20000;

let _timer = null;

function since(days = SCAN_DAYS) {
  return new Date(Date.now() - days * 24 * 3600 * 1000).toISOString();
}

/** Fetch the datasets the rules need. A missing table is reported, not fatal. */
async function fetchDatasets() {
  const from = since();
  const [bankAccounts, transactions, guarantees, profiles] = await Promise.all([
    supabase.from('bank_accounts').select('profile_id, account_number, bank_name'),
    supabase.from('transactions')
      .select('id, profile_id, type, category, amount, status, created_at')
      .gte('created_at', from)
      .limit(SCAN_LIMIT),
    supabase.from('loan_guarantors')
      .select('loan_id, guarantor_profile_id, guarantor_id, status, consented_at, created_at')
      .gte('created_at', from)
      .limit(SCAN_LIMIT),
    supabase.from('profiles').select('id, created_at').gte('created_at', from).limit(SCAN_LIMIT),
  ]);

  const datasets = {
    bankAccounts: bankAccounts.data || [],
    transactions: transactions.data || [],
    guarantees: guarantees.data || [],
    profiles: profiles.data || [],
  };
  for (const [name, res] of Object.entries({ bankAccounts, transactions, guarantees, profiles })) {
    if (res.error) logger.warn(`fraudDetectionWorker: ${name} read failed: ${res.error.message}`);
  }
  return datasets;
}

/**
 * Upsert one finding. Returns 'created' | 'updated' | 'skipped'.
 * A finding for a case an admin already resolved or dismissed is left alone.
 */
async function persistFinding(finding) {
  const now = new Date().toISOString();
  const { data: existing, error: findErr } = await supabase
    .from('fraud_cases')
    .select('id, status, occurrences')
    .eq('dedupe_key', finding.dedupeKey)
    .maybeSingle();
  if (findErr) throw findErr;

  if (!existing) {
    const { error } = await supabase.from('fraud_cases').insert({
      dedupe_key: finding.dedupeKey,
      rule_id: finding.ruleId,
      severity: finding.severity,
      profile_id: finding.profileId || null,
      title: finding.title,
      details: finding.details || {},
      amount: finding.amount != null ? finding.amount : null,
      status: 'open',
      detected_at: now,
      last_seen_at: now,
    });
    if (error) throw error;
    return 'created';
  }

  if (existing.status === 'resolved' || existing.status === 'dismissed') {
    return 'skipped';
  }

  const { error } = await supabase
    .from('fraud_cases')
    .update({
      last_seen_at: now,
      occurrences: (existing.occurrences || 1) + 1,
      details: finding.details || {},
      amount: finding.amount != null ? finding.amount : null,
      updated_at: now,
    })
    .eq('id', existing.id);
  if (error) throw error;
  return 'updated';
}

/**
 * Run a scan, persist findings, and alert on new critical cases.
 *
 * @returns {Promise<{scannedAt, findings, created, updated, skipped, criticalNew}>}
 */
async function runScan() {
  const scannedAt = new Date().toISOString();
  const datasets = await fetchDatasets();
  const findings = evaluateRules(datasets);

  const summary = { scannedAt, findings: findings.length, created: 0, updated: 0, skipped: 0, criticalNew: 0 };
  for (const finding of findings) {
    try {
      const outcome = await persistFinding(finding);
      summary[outcome] += 1;
      if (outcome === 'created' && finding.severity === 'critical') summary.criticalNew += 1;
    } catch (err) {
      // A missing table (migration 054 not applied) must not stop the scan.
      logger.warn(`fraudDetectionWorker: could not persist ${finding.dedupeKey}: ${err.message}`);
    }
  }

  if (summary.criticalNew > 0) {
    await notifyService.notifyAdmins({
      title: 'New critical fraud alerts',
      body: `${summary.criticalNew} new critical fraud case(s) need review. Open the fraud case queue to investigate.`,
      type: 'system',
      category: 'warning',
      priority: 'high',
    });
  }

  logger.info(`fraudDetectionWorker: scan complete — ${summary.findings} findings (${summary.created} new, ${summary.updated} recurring)`);
  return summary;
}

function start() {
  if (process.env.FRAUD_DETECTION_WORKER_DISABLED === '1') {
    logger.info('fraudDetectionWorker: disabled by FRAUD_DETECTION_WORKER_DISABLED');
    return;
  }
  if (_timer) return;
  _timer = setInterval(() => {
    runScan().catch((err) => logger.warn('fraudDetectionWorker: scan failed:', err.message));
  }, POLL_INTERVAL_MS);
  _timer.unref?.();
  setTimeout(() => {
    runScan().catch((err) => logger.warn('fraudDetectionWorker: initial scan failed:', err.message));
  }, STARTUP_DELAY_MS).unref?.();
  logger.info('fraudDetectionWorker: started (every 12h)');
}

function stop() {
  if (_timer) {
    clearInterval(_timer);
    _timer = null;
  }
}

module.exports = { start, stop, runScan, fetchDatasets, persistFinding, POLL_INTERVAL_MS };
