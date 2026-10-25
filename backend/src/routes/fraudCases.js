/**
 * Fraud & AML case management.
 *
 * Mounted at /api/admin/fraud-cases. The rules in `lib/fraudDetection.js` raise
 * findings; this is the queue an admin works them from.
 *
 *   GET   /cases              — list cases (filter by status/severity/rule)
 *   GET   /cases/:id          — one case
 *   PATCH /cases/:id          — move a case: reviewing | resolved | dismissed
 *   POST  /scan               — run the detection rules now
 *   GET   /rules              — the rule registry
 *
 * Mounted under /api/admin so it inherits requireAdmin and the single-session
 * policy, like the rest of the admin API.
 */

const express = require('express');
const { Router } = express;

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const { RULES, evaluateRules } = require('../lib/fraudDetection');
const fraudDetectionWorker = require('../workers/fraudDetectionWorker');

const router = Router();

const CASE_STATUSES = ['open', 'reviewing', 'resolved', 'dismissed'];

function requireAdminActor(req, res) {
  if (!req.user || !req.user.id) {
    res.status(401).json({ success: false, error: 'Admin session required' });
    return null;
  }
  return req.user;
}

// ── GET /rules ───────────────────────────────────────────────────────────────
router.get('/rules', (_req, res) => {
  res.json({ success: true, rules: RULES.map((r) => ({ id: r.id, title: r.title, severity: r.severity })) });
});

// ── GET /cases ───────────────────────────────────────────────────────────────
router.get('/cases', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    let q = supabase
      .from('fraud_cases')
      .select('id, dedupe_key, rule_id, severity, profile_id, title, amount, status, occurrences, detected_at, last_seen_at, reviewed_at')
      .order('detected_at', { ascending: false })
      .limit(limit);
    if (req.query.status) q = q.eq('status', req.query.status);
    if (req.query.severity) q = q.eq('severity', req.query.severity);
    if (req.query.rule) q = q.eq('rule_id', req.query.rule);
    const { data, error } = await q;
    if (error) throw error;
    res.json({ success: true, cases: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /cases/:id ───────────────────────────────────────────────────────────
router.get('/cases/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('fraud_cases')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Case not found' });
    res.json({ success: true, case: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── PATCH /cases/:id ─────────────────────────────────────────────────────────
router.patch('/cases/:id', async (req, res) => {
  try {
    const actor = requireAdminActor(req, res);
    if (!actor) return;

    const { status, resolutionNote } = req.body || {};
    if (!CASE_STATUSES.includes(status)) {
      return res.status(400).json({ success: false, error: `status must be one of ${CASE_STATUSES.join(', ')}` });
    }
    if ((status === 'resolved' || status === 'dismissed') && !resolutionNote) {
      return res.status(400).json({ success: false, error: 'A resolution note is required to close a case' });
    }

    const terminal = status === 'resolved' || status === 'dismissed';
    const { data, error } = await supabase
      .from('fraud_cases')
      .update({
        status,
        resolution_note: resolutionNote || null,
        reviewed_by: actor.id,
        reviewed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', req.params.id)
      .select()
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Case not found' });

    await supabase.from('audit_logs').insert({
      actor_id: actor.id,
      action: terminal ? 'FRAUD_CASE_CLOSED' : 'FRAUD_CASE_UPDATED',
      target_model: 'FraudCase',
      target_id: req.params.id,
      metadata: { status, resolutionNote: resolutionNote || null },
    }).then(() => {}, () => {});

    res.json({ success: true, case: data });
  } catch (err) {
    logger.error('fraudCases PATCH error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── POST /scan ───────────────────────────────────────────────────────────────
router.post('/scan', async (req, res) => {
  try {
    const actor = requireAdminActor(req, res);
    if (!actor) return;
    const summary = await fraudDetectionWorker.runScan();
    await supabase.from('audit_logs').insert({
      actor_id: actor.id,
      action: 'FRAUD_SCAN_RUN',
      target_model: 'FraudCase',
      metadata: summary,
    }).then(() => {}, () => {});
    res.json({ success: true, summary });
  } catch (err) {
    logger.error('fraudCases scan error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── POST /evaluate (dry run) ─────────────────────────────────────────────────
// Runs the rules against supplied datasets without persisting. Handy for tuning
// a threshold without creating cases.
router.post('/evaluate', (req, res) => {
  try {
    const datasets = (req.body && req.body.datasets) || {};
    const findings = evaluateRules(datasets, (req.body && req.body.options) || {});
    res.json({ success: true, findings });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

module.exports = router;
