/**
 * Comparative analytics routes.
 *
 *   GET /comparative/options                    — period types + pickable periods
 *   GET /comparative/compare                    — two periods, side by side
 *   GET /comparative/export.:format             — the comparison as xlsx/csv
 *   GET /comparative/drilldown                  — trace a figure to transactions
 *
 * Mounted under the admin prefix alongside the reporting suite, so it inherits
 * requireAdmin.
 *
 * The comparison is deliberately built from the money/ledger tables (see
 * comparativeMetrics.js) rather than pre-aggregated dashboard fields, so every
 * figure on screen can be traced back to the rows that produced it through
 * /comparative/drilldown.
 */

const express = require('express');
const { Router } = express;

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const periods = require('../lib/reportPeriods');
const metrics = require('../lib/comparativeMetrics');
const engine = require('../lib/comparisonEngine');
const spreadsheet = require('../lib/spreadsheet');

const router = Router();

// ── period parsing ───────────────────────────────────────────────────────────

/**
 * Read a period from query params: `aType`, `aYear`, `aMonth`, `aQuarter`,
 * `aWeek`, `aStart`, `aEnd` — and the matching `b*`. Also accepts a JSON
 * `periodA`/`periodB` param for callers that prefer structure.
 */
function parsePeriodFrom(query, prefix) {
  if (query[`${prefix}Period`]) {
    try {
      return periods.resolvePeriod(JSON.parse(query[`${prefix}Period`]));
    } catch {
      throw new periods.PeriodError(`Invalid ${prefix.toUpperCase()} period JSON`);
    }
  }
  const type = query[`${prefix}Type`];
  if (!type) return null;
  return periods.resolvePeriod({
    type,
    year: query[`${prefix}Year`] !== undefined ? Number(query[`${prefix}Year`]) : undefined,
    month: query[`${prefix}Month`] !== undefined ? Number(query[`${prefix}Month`]) : undefined,
    quarter: query[`${prefix}Quarter`] !== undefined ? Number(query[`${prefix}Quarter`]) : undefined,
    week: query[`${prefix}Week`] !== undefined ? Number(query[`${prefix}Week`]) : undefined,
    start: query[`${prefix}Start`],
    end: query[`${prefix}End`],
    from: query[`${prefix}From`],
  });
}

function parseSections(query) {
  if (!query.sections) return null;
  return String(query.sections).split(',').map((s) => s.trim()).filter(Boolean);
}

/**
 * Resolve period A and B, applying the convenience shortcuts:
 *   `b=previous`     — the period immediately before A
 *   `b=previousYear` — the same period one year earlier
 */
function resolvePeriods(query) {
  const a = parsePeriodFrom(query, 'a');
  if (!a) {
    throw new periods.PeriodError('Period A is required (e.g. aType=quarter&aYear=2026&aQuarter=1)');
  }

  const bShortcut = String(query.b || '').toLowerCase();
  let b = parsePeriodFrom(query, 'b');
  if (!b && bShortcut === 'previous') b = periods.previousPeriod(a);
  if (!b && bShortcut === 'previousyear') b = periods.previousYearPeriod(a);

  if (!b) {
    throw new periods.PeriodError('Period B is required (e.g. b=previous, b=previousYear, or explicit bType=...)');
  }
  return { a, b };
}

// ── GET /comparative/options ─────────────────────────────────────────────────
router.get('/options', async (req, res) => {
  try {
    const year = Number(req.query.year) || new Date().getUTCFullYear();
    res.json({
      success: true,
      periodTypes: periods.PERIOD_TYPES,
      currentYear: year,
      weeks: periods.enumeratePeriods('week', year).map((p) => ({ label: p.label, value: `W${periods.isoWeekNumber(new Date(`${p.start}T00:00:00Z`))}|${year}`, start: p.start, end: p.end })),
      months: periods.enumeratePeriods('month', year).map((p) => ({ label: p.label, month: Number(p.start.slice(5, 7)), year, start: p.start, end: p.end })),
      quarters: periods.enumeratePeriods('quarter', year).map((p) => ({ label: p.label, quarter: Number(p.start.slice(5, 7)) ? Math.floor((Number(p.start.slice(5, 7)) - 1) / 3) + 1 : 1, year, start: p.start, end: p.end })),
      years: [year - 2, year - 1, year, year + 1].map((y) => ({ label: String(y), year: y })),
      sections: metrics.listSections(),
      shortcuts: [
        { value: 'previous', label: 'Previous period' },
        { value: 'previousYear', label: 'Same period last year' },
      ],
    });
  } catch (err) {
    logger.error('comparative options error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /comparative/compare ─────────────────────────────────────────────────

async function buildComparison(query) {
  const { a, b } = resolvePeriods(query);
  const sectionKeys = parseSections(query);
  const ctxBase = { db: supabase, logger };

  const [metricsA, metricsB] = await Promise.all([
    metrics.runSections(sectionKeys, { ...ctxBase, range: a }),
    metrics.runSections(sectionKeys, { ...ctxBase, range: b }),
  ]);

  const comparison = engine.compareSections(metricsA, metricsB, {
    a: { type: a.type, label: a.label, start: a.start, end: a.end },
    b: { type: b.type, label: b.label, start: b.start, end: b.end },
  });

  // Organization rows are compared only when that section was requested.
  let organizationComparison = null;
  if (metricsA.organizations || metricsB.organizations) {
    organizationComparison = engine.compareOrganizationRows(
      metricsA.organizations?.rows || [],
      metricsB.organizations?.rows || [],
    );
  }

  const insights = engine.generateInsights(comparison);

  // Surface any data-quality disagreements at the top level so the UI can warn
  // rather than present an untraceable number as fact.
  const dataQuality = [
    ...(metricsA.savings?.dataQuality || []).map((d) => ({ ...d, period: 'a' })),
    ...(metricsB.savings?.dataQuality || []).map((d) => ({ ...d, period: 'b' })),
  ];

  return {
    generatedAt: new Date().toISOString(),
    periods: comparison.periods,
    sections: comparison.sections,
    organizationComparison,
    composition: {
      a: metricsA.savings?.composition || [],
      b: metricsB.savings?.composition || [],
    },
    dataQuality,
    insights,
  };
}

router.get('/compare', async (req, res) => {
  try {
    const result = await buildComparison(req.query);
    res.json({ success: true, ...result });
  } catch (err) {
    if (err instanceof periods.PeriodError || err.status === 400) {
      res.status(err.status || 400).json({ success: false, error: err.message });
      return;
    }
    logger.error('comparative compare error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /comparative/export.:format ──────────────────────────────────────────

/**
 * Flatten a comparison into spreadsheet columns.
 *
 * One row per metric, with Period A, Period B, change and change %, so the
 * export carries the same numbers as the screen (built from the same
 * comparison object).
 */
function comparisonToSheet(result) {
  const columns = [
    { key: 'section', label: 'Section', type: 'text' },
    { key: 'metric', label: 'Metric', type: 'text' },
    { key: 'periodA', label: `Period A — ${result.periods.a.label}`, type: 'number' },
    { key: 'periodB', label: `Period B — ${result.periods.b.label}`, type: 'number' },
    { key: 'change', label: 'Change', type: 'number' },
    { key: 'changePct', label: 'Change %', type: 'text' },
    { key: 'direction', label: 'Direction', type: 'text' },
  ];

  const rows = [];
  for (const section of result.sections) {
    for (const m of section.metrics) {
      rows.push({
        section: section.label,
        metric: m.label,
        periodA: m.periodA,
        periodB: m.periodB,
        change: m.absolute,
        changePct: m.unit === 'percent'
          ? (m.percentagePoints !== undefined ? `${m.percentagePoints} pp` : 'n/a')
          : (m.percent === null ? 'n/a' : `${m.percent}%`),
        direction: m.direction,
      });
    }
  }

  // Organization rows, when the section was requested, with the org name
  // folded into the Metric column so one sheet serves the whole report.
  if (result.organizationComparison) {
    for (const org of result.organizationComparison) {
      for (const m of org.metrics) {
        rows.push({
          section: 'Organizations',
          metric: `${org.organization} — ${m.label}`,
          periodA: m.periodA,
          periodB: m.periodB,
          change: m.absolute,
          changePct: m.percent === null ? 'n/a' : `${m.percent}%`,
          direction: m.direction,
        });
      }
    }
  }

  return { columns, rows };
}

router.get('/export.:format', async (req, res) => {
  try {
    const result = await buildComparison(req.query);
    const format = String(req.params.format || 'xlsx').toLowerCase();
    const { columns, rows } = comparisonToSheet(result);
    const stamp = new Date().toISOString().slice(0, 10);
    const slug = `${result.periods.a.label} vs ${result.periods.b.label}`
      .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    const filename = `coopvest-comparison-${slug}-${stamp}.${format}`;

    if (format === 'csv') {
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.send(spreadsheet.toCsv({ columns, rows }));
      return;
    }
    if (format === 'xlsx') {
      res.setHeader(
        'Content-Type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.send(spreadsheet.toXlsx({
        sheetName: 'Comparison',
        columns,
        rows,
      }));
      return;
    }

    res.status(400).json({
      success: false,
      error: `Unsupported format: ${format}. Use xlsx or csv.`,
    });
  } catch (err) {
    if (err instanceof periods.PeriodError || err.status === 400) {
      res.status(err.status || 400).json({ success: false, error: err.message });
      return;
    }
    logger.error('comparative export error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /comparative/drilldown ───────────────────────────────────────────────

/**
 * Trace a figure back to the underlying rows.
 *
 * The drill-down chain is Organization → Member → Transaction → Reference →
 * Ledger entry, which is what makes a headline number auditable.
 *
 *   metric=total_contributions  → transactions of contribution type in period
 *   metric=repayments_received  → loan_repayments in period
 *   metric=amount_disbursed     → loans disbursed in period
 *   metric=new_members          → profiles created in period
 *   metric=outstanding_loans    → open loans with reconstructed balances
 *
 * Optional `organizationId` and `profileId` narrow the chain.
 */
const DRILLDOWNS = {
  total_contributions: {
    label: 'Total contributions',
    table: 'transactions',
    dateField: 'created_at',
    filter: (t) => ['deposit', 'savings_deposit', 'transfer_in'].includes(t.type)
      && t.status !== 'failed' && t.status !== 'reversed',
    columns: [
      { key: 'date', label: 'Date', type: 'date' },
      { key: 'transactionId', label: 'Transaction ID', type: 'text' },
      { key: 'member', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'method', label: 'Method', type: 'text' },
      { key: 'reference', label: 'Reference', type: 'text' },
      { key: 'source', label: 'Source', type: 'text' },
      { key: 'status', label: 'Status', type: 'text' },
    ],
  },
  repayments_received: {
    label: 'Repayments received',
    table: 'loan_repayments',
    dateField: 'paid_at',
    columns: [
      { key: 'date', label: 'Date', type: 'date' },
      { key: 'loanId', label: 'Loan ID', type: 'text' },
      { key: 'member', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'principal', label: 'Principal (₦)', type: 'currency' },
      { key: 'interest', label: 'Interest (₦)', type: 'currency' },
      { key: 'status', label: 'Status', type: 'text' },
    ],
  },
  amount_disbursed: {
    label: 'Total amount disbursed',
    table: 'loans',
    // No disbursed_at column exists; approved_at is the funding timestamp.
    dateField: 'approved_at',
    filter: (l) => ['approved', 'disbursed', 'active', 'repaying', 'overdue', 'in_recovery', 'completed'].includes(l.status),
    columns: [
      { key: 'date', label: 'Disbursed', type: 'date' },
      { key: 'loanId', label: 'Loan ID', type: 'text' },
      { key: 'member', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'loanType', label: 'Product', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'status', label: 'Status', type: 'text' },
    ],
  },
  new_members: {
    label: 'New members',
    table: 'profiles',
    dateField: 'created_at',
    columns: [
      { key: 'date', label: 'Joined', type: 'date' },
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'member', label: 'Member', type: 'text' },
      { key: 'email', label: 'Email', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'status', label: 'Status', type: 'text' },
    ],
  },
};

router.get('/drilldown', async (req, res) => {
  try {
    const { a, b } = resolvePeriods(req.query);
    const which = String(req.query.period || 'b').toLowerCase() === 'a' ? a : b;
    const metricKey = String(req.query.metric || '');
    const spec = DRILLDOWNS[metricKey];
    if (!spec) {
      res.status(400).json({
        success: false,
        error: `Cannot drill into "${metricKey}". Supported: ${Object.keys(DRILLDOWNS).join(', ')}`,
      });
      return;
    }

    const [profiles, orgs] = await Promise.all([
      metrics.loadProfiles(supabase, logger, 50000),
      metrics.loadOrganizations(supabase, logger),
    ]);
    const profileMap = new Map(profiles.map((p) => [p.id, p]));
    const orgMap = new Map(orgs.map((o) => [o.id, o.name]));

    // Fetch the underlying rows for the metric's table.
    let raw = [];
    const { fromIso, toIso } = periods.rangeBounds(which);
    if (spec.table === 'transactions') {
      raw = await metrics.loadTransactions(supabase, logger);
    } else if (spec.table === 'loan_repayments') {
      raw = await metrics.loadRepayments(supabase, logger);
    } else if (spec.table === 'loans') {
      raw = await metrics.loadLoans(supabase, logger);
    } else if (spec.table === 'profiles') {
      raw = profiles;
    }

    const dateOf = (row) => row[spec.dateField] || row.created_at;

    // Build the transaction ids per member so each row can name its ledger
    // reference — the last link in the Organization → Member → Transaction
    // chain.
    let rows = raw
      .filter((r) => periods.inRange(dateOf(r), which))
      .filter((r) => (spec.filter ? spec.filter(r) : true))
      .filter((r) => {
        if (!req.query.organizationId) return true;
        const p = profileMap.get(r.profile_id);
        return p && p.organization_id === req.query.organizationId;
      })
      .filter((r) => {
        if (!req.query.profileId) return true;
        return r.profile_id === req.query.profileId || r.id === req.query.profileId;
      });

    const mapped = rows.map((r) => {
      const profile = profileMap.get(r.profile_id) || (spec.table === 'profiles' ? r : null);
      const base = {
        date: dateOf(r),
        member: profile?.name || profile?.full_name || profile?.email || '',
        memberId: profile?.user_id || '',
        organization: profile ? (orgMap.get(profile.organization_id) || '') : '',
      };
      if (spec.table === 'transactions') {
        return {
          ...base,
          transactionId: r.transaction_id || r.id,
          amount: Number(r.amount || 0),
          method: r.payment_method || '',
          reference: r.reference || '',
          source: r.contribution_source || '',
          status: r.status || '',
        };
      }
      if (spec.table === 'loan_repayments') {
        return {
          ...base,
          loanId: r.loan_id || '',
          amount: Number(r.amount || 0),
          principal: Number(r.principal_component || 0),
          interest: Number(r.interest_component || 0),
          status: r.status || '',
        };
      }
      if (spec.table === 'loans') {
        return {
          ...base,
          loanId: r.loan_id || r.id,
          loanType: r.loan_type || '',
          amount: Number(r.amount || 0),
          status: r.status || '',
        };
      }
      return {
        date: r.created_at,
        memberId: r.user_id || '',
        member: r.name || r.full_name || r.email || '',
        email: r.email || '',
        organization: orgMap.get(r.organization_id) || '',
        status: r.membership_status || (r.is_active ? 'active' : 'inactive'),
      };
    });

    const total = mapped.reduce((s, r) => s + Number(r.amount || 0), 0);

    res.json({
      success: true,
      metric: metricKey,
      metricLabel: spec.label,
      period: { type: which.type, label: which.label, start: which.start, end: which.end },
      columns: spec.columns,
      rows: mapped.slice(0, 1000),
      rowCount: mapped.length,
      total: Math.round(total * 100) / 100,
      truncated: mapped.length > 1000,
      chain: ['Organization', 'Member', 'Transaction', 'Reference', 'Ledger entry'],
    });
  } catch (err) {
    if (err instanceof periods.PeriodError) {
      res.status(400).json({ success: false, error: err.message });
      return;
    }
    logger.error('comparative drilldown error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
