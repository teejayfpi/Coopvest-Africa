/**
 * Comparison engine.
 *
 * Pairs two periods of metrics and computes, for each metric, the absolute
 * change and the percentage change, plus human-readable insights.
 *
 * Two rules that matter for financial reporting:
 *
 *   1. A percentage change is only meaningful against a non-zero base. When
 *      period A is 0 the change is reported as `null` with a reason rather than
 *      "Infinity%" or "+100%", both of which mislead.
 *   2. Some numbers should go DOWN (default rate, overdue exposure). Each metric
 *      carries `higherIsBetter`, so an insight never calls a falling default
 *      rate a decline.
 */

const periods = require('./reportPeriods');

const MIN_BASE_FOR_PCT = 0; // any non-zero base is usable

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function round2(v) {
  return Math.round(v * 100) / 100;
}

/**
 * Change between two values.
 *
 * Returns { absolute, percent, direction, baseZero } where `percent` is null
 * when the base is zero (undefined growth) and `direction` is one of
 * up/down/flat.
 */
function changeBetween(a, b) {
  const from = num(a);
  const to = num(b);
  const absolute = round2(to - from);
  const direction = absolute > 0 ? 'up' : absolute < 0 ? 'down' : 'flat';

  if (Math.abs(from) <= MIN_BASE_FOR_PCT) {
    return {
      absolute,
      percent: null,
      direction,
      // Explain the null so the UI can show "n/a (no activity in period A)"
      // instead of a blank cell.
      percentUnavailableReason: from === 0 && to === 0 ? 'no_activity_either_period' : 'no_activity_in_period_a',
    };
  }

  return { absolute, percent: round2((absolute / Math.abs(from)) * 100), direction };
}

/** Percentage-point change, used for rates (default rate 4.8% → 3.1%). */
function percentagePointChange(a, b) {
  const from = num(a);
  const to = num(b);
  return {
    absolute: round2(to - from),
    percent: null, // a rate has no meaningful % change against itself
    percentagePoints: round2(to - from),
    direction: to > from ? 'up' : to < from ? 'down' : 'flat',
  };
}

/**
 * Compare two metric lists (same section, two periods).
 *
 * Metrics are matched by key, not position, so a metric that only appears in
 * one period still lines up and is reported against a zero base.
 */
function compareMetricLists(listA = [], listB = []) {
  const byKey = new Map();
  for (const m of listA) byKey.set(m.key, { a: m, b: null });
  for (const m of listB) {
    const entry = byKey.get(m.key);
    if (entry) entry.b = m;
    else byKey.set(m.key, { a: null, b: m });
  }

  const metrics = [];
  for (const [key, { a, b }] of byKey) {
    const meta = b || a;
    const av = a ? num(a.value) : 0;
    const bv = b ? num(b.value) : 0;

    // Rates are compared in percentage points; everything else proportionally.
    const change = meta.unit === 'percent'
      ? percentagePointChange(av, bv)
      : changeBetween(av, bv);

    metrics.push({
      key,
      label: meta.label,
      unit: meta.unit,
      higherIsBetter: meta.higherIsBetter !== false,
      informational: Boolean(meta.informational),
      periodA: a ? num(a.value) : 0,
      periodB: b ? num(b.value) : 0,
      ...change,
    });
  }
  return metrics;
}

/** Build the period-over-period comparison for every section. */
function compareSections(metricsA, metricsB, periodsInfo) {
  const keys = [...new Set([...Object.keys(metricsA || {}), ...Object.keys(metricsB || {})])];
  const sections = [];

  for (const key of keys) {
    const a = metricsA?.[key] || { key, label: key, metrics: [] };
    const b = metricsB?.[key] || { key, label: key, metrics: [] };

    sections.push({
      key,
      label: a.label || b.label || key,
      metrics: compareMetricLists(a.metrics || [], b.metrics || []),
    });
  }

  return { periods: periodsInfo, sections };
}

/**
 * Compare per-organization rows between two periods.
 *
 * Pairs by organization id so "Bowen Q1 vs Bowen Q2" compares like with like.
 * `aliases` lets the caller compare two different organizations in the same
 * period instead (pass organizations[0].id as both).
 */
function compareOrganizationRows(rowsA = [], rowsB = []) {
  const byId = new Map();
  for (const r of rowsA) byId.set(r.organizationId, { a: r, b: null });
  for (const r of rowsB) {
    const entry = byId.get(r.organizationId);
    if (entry) entry.b = r;
    else byId.set(r.organizationId, { a: null, b: r });
  }

  const numericFields = [
    ['members', 'Members', 'number'],
    ['activeMembers', 'Active members', 'number'],
    ['activeLoans', 'Active loans', 'number'],
    ['contributions', 'Contributions', 'currency'],
    ['salaryDeductions', 'Salary deductions', 'currency'],
    ['outstandingLoans', 'Outstanding loans', 'currency'],
    ['repayments', 'Repayments', 'currency'],
    ['repaymentRate', 'Repayment rate', 'percent'],
  ];

  return [...byId.values()].map(({ a, b }) => {
    const org = b || a;
    return {
      organizationId: org.organizationId,
      organization: org.organization,
      code: org.code,
      metrics: numericFields.map(([field, label, unit]) => {
        const av = num(a?.[field]);
        const bv = num(b?.[field]);
        const change = unit === 'percent' ? percentagePointChange(av, bv) : changeBetween(av, bv);
        return {
          key: field,
          label,
          unit,
          higherIsBetter: field === 'repaymentRate' ? true : true,
          periodA: av,
          periodB: bv,
          ...change,
        };
      }),
    };
  }).sort((x, y) => {
    const xc = x.metrics.find((m) => m.key === 'contributions')?.periodB || 0;
    const yc = y.metrics.find((m) => m.key === 'contributions')?.periodB || 0;
    return yc - xc;
  });
}

// ── insights ─────────────────────────────────────────────────────────────────

const CURRENCY_KEYS = new Set([
  'total_contributions', 'total_income', 'amount_disbursed', 'amount_approved',
  'outstanding_loans', 'salary_deductions', 'repayments_received', 'rollover_amount',
]);

function formatMoney(v) {
  const n = num(v);
  if (Math.abs(n) >= 1_000_000) return `₦${(n / 1_000_000).toFixed(1)}M`;
  if (Math.abs(n) >= 1_000) return `₦${(n / 1_000).toFixed(0)}K`;
  return `₦${n.toLocaleString('en-NG')}`;
}

function formatNumber(v) {
  return num(v).toLocaleString('en-NG');
}

function formatPercent(v) {
  return `${num(v).toFixed(1)}%`;
}

function formatValue(value, unit) {
  if (unit === 'currency') return formatMoney(value);
  if (unit === 'percent') return formatPercent(value);
  return formatNumber(value);
}

/**
 * Generate plain-English insights from a comparison.
 *
 * Deliberately deterministic and computed from the numbers rather than
 * generated prose, so an insight can always be traced to the metric it came
 * from. `periods` supplies the labels used in the sentences.
 */
function generateInsights(comparison, { maxInsights = 12 } = {}) {
  const insights = [];
  const pa = comparison.periods?.a?.label || 'Period A';
  const pb = comparison.periods?.b?.label || 'Period B';

  let improved = 0;
  let declined = 0;
  let comparable = 0;

  for (const section of comparison.sections || []) {
    for (const m of section.metrics || []) {
      if (m.informational) continue;
      if (m.absolute === 0) continue;

      const good = m.higherIsBetter ? m.absolute > 0 : m.absolute < 0;
      if (good) improved += 1;
      else declined += 1;

      // Only headline-worthy movements become insights, so the list stays
      // readable rather than restating every metric.
      const pct = m.percent;
      const isBig = pct !== null ? Math.abs(pct) >= 10 : false;
      const isMoneyHeadline = m.unit === 'currency' && Math.abs(m.absolute) >= 100000;
      if (!isBig && !isMoneyHeadline && m.unit !== 'percent') continue;

      let sentence;
      if (m.unit === 'percent') {
        const pp = m.percentagePoints ?? m.absolute;
        sentence = `${m.label} ${pp > 0 ? 'rose' : 'fell'} by ${Math.abs(pp).toFixed(1)} percentage points `
          + `(${formatPercent(m.periodA)} → ${formatPercent(m.periodB)}).`;
      } else if (pct !== null) {
        sentence = `${m.label} ${m.absolute > 0 ? 'increased' : 'decreased'} by `
          + `${formatValue(Math.abs(m.absolute), m.unit)} (${Math.abs(pct).toFixed(1)}%), `
          + `${formatValue(m.periodA, m.unit)} → ${formatValue(m.periodB, m.unit)}.`;
      } else {
        sentence = `${m.label} moved from nothing to ${formatValue(m.periodB, m.unit)}.`;
      }
      insights.push({ section: section.key, metric: m.key, sentiment: good ? 'positive' : 'negative', text: sentence });
    }
  }

  // Section-level comparability only counts metrics with a usable base.
  for (const section of comparison.sections || []) {
    for (const m of section.metrics || []) {
      if (!m.informational && m.percent !== null) comparable += 1;
    }
  }

  // A short summary sentence up front, which is what the CEO reads first.
  const summaryParts = [];
  const contribution = (comparison.sections || [])
    .find((s) => s.key === 'savings')?.metrics
    .find((m) => m.key === 'total_contributions');
  if (contribution && contribution.percent !== null) {
    summaryParts.push(
      `Contributions ${contribution.absolute >= 0 ? 'increased' : 'decreased'} by `
      + `${formatMoney(Math.abs(contribution.absolute))} (${Math.abs(contribution.percent).toFixed(1)}%) `
      + `from ${pa} to ${pb}.`,
    );
  }

  const newMembers = (comparison.sections || [])
    .find((s) => s.key === 'membership')?.metrics
    .find((m) => m.key === 'new_members');
  if (newMembers && newMembers.percent !== null) {
    summaryParts.push(
      `New membership ${newMembers.absolute >= 0 ? 'increased' : 'decreased'} by `
      + `${Math.abs(newMembers.percent).toFixed(1)}%.`,
    );
  }

  const disbursed = (comparison.sections || [])
    .find((s) => s.key === 'loans')?.metrics
    .find((m) => m.key === 'amount_disbursed');
  const defaultRate = (comparison.sections || [])
    .find((s) => s.key === 'loans')?.metrics
    .find((m) => m.key === 'default_rate');
  if (disbursed && disbursed.percent !== null) {
    let s = `Loan disbursement ${disbursed.absolute >= 0 ? 'increased' : 'decreased'} by `
      + `${Math.abs(disbursed.percent).toFixed(1)}%`;
    if (defaultRate && defaultRate.percentagePoints) {
      const pp = defaultRate.percentagePoints;
      s += `, while the default rate ${pp > 0 ? 'increased' : 'decreased'} by `
        + `${Math.abs(pp).toFixed(1)} percentage points`;
    }
    summaryParts.push(`${s}.`);
  }

  const salaryShare = (comparison.sections || [])
    .find((s) => s.key === 'savings')?.metrics
    .find((m) => m.key === 'salary_share_pct');
  if (salaryShare && salaryShare.periodB > 0) {
    summaryParts.push(
      `Salary-based contributions accounted for ${salaryShare.periodB.toFixed(1)}% of total contributions in ${pb}.`,
    );
  }

  const overall = comparable > 0
    ? Math.round((improved / (improved + declined || 1)) * 1000) / 10
    : 0;

  const summary = summaryParts.join(' ');

  return {
    summary,
    periodA: pa,
    periodB: pb,
    improvedCount: improved,
    declinedCount: declined,
    comparableMetricCount: comparable,
    improvementRate: overall,
    insights: insights.slice(0, maxInsights),
  };
}

module.exports = {
  changeBetween,
  percentagePointChange,
  compareMetricLists,
  compareSections,
  compareOrganizationRows,
  generateInsights,
  formatValue,
  round2,
};
