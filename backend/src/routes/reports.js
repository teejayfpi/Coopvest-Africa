/**
 * Admin reporting suite routes.
 *
 * Mounted under the same /api/admin prefix as the rest of the admin API, so it
 * inherits that router's `requireAdmin` guard and single-session policy.
 *
 *   GET /reports/catalog                  — what reports exist (drives the picker)
 *   GET /reports/run/:id                  — run a report, JSON body
 *   GET /reports/export/:id.:format       — download csv or xlsx
 *   GET /reports/catalog/:id              — one report's definition
 *
 * Existing scheduled-report endpoints (`/reports/scheduled*`) live in adminApi
 * and are untouched; these are the ad-hoc reporting endpoints the dashboard was
 * missing.
 */

const express = require('express');
const { Router } = express;

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const { listReports, REPORTS } = require('../lib/reportCatalog');
const reportEngine = require('../lib/reportEngine');

const router = Router();

// ── GET /reports/catalog ─────────────────────────────────────────────────────
router.get('/catalog', async (_req, res) => {
  try {
    const reports = listReports();
    const categories = [...new Set(reports.map((r) => r.category))];
    res.json({ success: true, reports, categories, total: reports.length });
  } catch (err) {
    logger.error('reports catalog error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /reports/catalog/:id ─────────────────────────────────────────────────
router.get('/catalog/:id', async (req, res) => {
  try {
    const report = REPORTS[req.params.id];
    if (!report) {
      res.status(404).json({ success: false, error: `Unknown report: ${req.params.id}` });
      return;
    }
    res.json({
      success: true,
      report: {
        id: report.id,
        name: report.name,
        category: report.category,
        description: report.description,
        supportsDateRange: Boolean(report.supportsDateRange),
        supportsOrganization: Boolean(report.supportsOrganization),
        columns: report.columns,
      },
    });
  } catch (err) {
    logger.error('report definition error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * Shared handler body for running and for exporting, so a downloaded file can
 * never disagree with the table the admin just looked at.
 */
async function produceReport(req, res, format) {
  try {
    const payload = await reportEngine.runReport(req.params.id, req.query, { db: supabase });

    const { body, contentType, filename } = reportEngine.serialise(payload, format);

    if (format === 'json') {
      res.json({ success: true, ...body });
      return;
    }

    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    // Expose the row count so the client can show "exported N rows".
    res.setHeader('X-Report-Row-Count', String(payload.rowCount));
    res.setHeader('X-Report-Truncated', String(payload.truncated));
    res.send(body);
  } catch (err) {
    if (err instanceof reportEngine.ReportError) {
      res.status(err.status).json({ success: false, error: err.message });
      return;
    }
    logger.error(`report ${req.params.id} failed:`, err);
    res.status(500).json({ success: false, error: err.message });
  }
}

// ── GET /reports/run/:id ─────────────────────────────────────────────────────
router.get('/run/:id', (req, res) => produceReport(req, res, 'json'));

// ── GET /reports/export/:id.:format ──────────────────────────────────────────
// The extension is part of the field so a plain <a download> works without a
// query param that browsers might strip.
router.get('/export/:id.:format', (req, res) => produceReport(req, res, req.params.format));

// Also accept ?format= for programmatic callers and the fetch-based downloader.
router.get('/export/:id', (req, res) => produceReport(req, res, req.query.format || 'xlsx'));

module.exports = router;
