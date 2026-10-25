/**
 * Reconciliation operations.
 *
 * The "Money Integrity" runner, mounted at /api/admin/reconciliation-ops. It
 * exposes the read-only checks in `lib/moneyIntegrity.js` so an admin can see
 * what disagrees without waiting for the 6-hourly sweep, plus the history of
 * runs the worker persisted to `money_integrity_runs`.
 *
 *   GET  /checks        — the check registry (id, title, severity)
 *   POST /run           — run the checks now and persist the result
 *   GET  /runs          — recent runs, newest first
 *   GET  /runs/:id      — one run, including the sampled offending rows
 *
 * Mounted under /api/admin so it inherits requireAdmin and the single-session
 * policy, like the rest of the admin API.
 */

const express = require('express');
const { Router } = express;

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const { CHECKS, runIntegrityChecks } = require('../lib/moneyIntegrity');

const router = Router();

function requireAdminActor(req, res) {
  if (!req.user || !req.user.id) {
    res.status(401).json({ success: false, error: 'Admin session required' });
    return null;
  }
  return req.user;
}

// ── GET /checks ──────────────────────────────────────────────────────────────
router.get('/checks', (_req, res) => {
  res.json({
    success: true,
    checks: CHECKS.map((c) => ({ id: c.id, title: c.title, severity: c.severity })),
  });
});

// ── POST /run ────────────────────────────────────────────────────────────────
// `{ checks: [ids] }` runs a subset; omitted runs them all.
router.post('/run', async (req, res) => {
  try {
    const actor = requireAdminActor(req, res);
    if (!actor) return;

    const startedAt = Date.now();
    const { ranAt, results, totals } = await runIntegrityChecks({
      db: supabase,
      checks: req.body && req.body.checks,
    });

    const row = {
      trigger: 'manual',
      ran_at: ranAt,
      checks_run: totals.checksRun,
      checks_errored: totals.checksErrored,
      discrepancies: totals.discrepancies,
      critical_checks: totals.critical,
      warning_checks: totals.warning,
      results,
      duration_ms: Date.now() - startedAt,
      triggered_by: actor.id,
    };

    const { data, error } = await supabase.from('money_integrity_runs').insert(row).select().maybeSingle();
    // A missing table must not hide the findings the admin asked for.
    const persisted = !error;
    if (error) logger.warn('reconciliationOps: could not persist run:', error.message);

    res.json({ success: true, persisted, run: data || { ...row, id: null }, totals });
  } catch (err) {
    logger.error('reconciliationOps /run error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /runs ────────────────────────────────────────────────────────────────
router.get('/runs', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
    const { data, error } = await supabase
      .from('money_integrity_runs')
      .select('id, trigger, ran_at, checks_run, checks_errored, discrepancies, critical_checks, warning_checks, duration_ms')
      .order('ran_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    res.json({ success: true, runs: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /runs/:id ────────────────────────────────────────────────────────────
router.get('/runs/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('money_integrity_runs')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Run not found' });
    res.json({ success: true, run: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
