/**
 * Report runner: turns a catalog entry + a filter set into a report payload,
 * and serialises that payload to JSON, CSV or XLSX.
 *
 * Kept separate from the HTTP layer so it can be driven directly by tests with
 * a fake db, and so the same code path produces the on-screen table and every
 * export — the export can never disagree with what the admin saw.
 */

const { REPORTS } = require('./reportCatalog');
const spreadsheet = require('./spreadsheet');

// Guard rail: exports are generated synchronously in-request, so cap the row
// count. 20k rows is a few MB of xlsx — well within a request budget.
const MAX_ROWS = 20000;

const EXPORT_FORMATS = ['json', 'csv', 'xlsx'];

class ReportError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.name = 'ReportError';
    this.status = status;
  }
}

/**
 * Normalise and validate the filter set.
 *
 * Rejecting unknown report ids and malformed dates here means the catalog
 * functions can assume clean input.
 */
function buildFilters(query = {}) {
  const dateFrom = query.dateFrom ? String(query.dateFrom) : null;
  const dateTo = query.dateTo ? String(query.dateTo) : null;

  for (const [key, value] of [['dateFrom', dateFrom], ['dateTo', dateTo]]) {
    if (value && Number.isNaN(new Date(value).getTime())) {
      throw new ReportError(`Invalid ${key}: not a valid date`);
    }
  }
  if (dateFrom && dateTo && new Date(dateFrom) > new Date(dateTo)) {
    throw new ReportError('dateFrom must not be after dateTo');
  }

  return {
    dateFrom,
    dateTo,
    organizationId: query.organizationId || null,
    memberId: query.memberId || null,
    status: query.status || null,
    groupBy: query.groupBy || null,
  };
}

function getReport(id) {
  const report = REPORTS[id];
  if (!report) throw new ReportError(`Unknown report: ${id}`, 404);
  return report;
}

/**
 * Sum the money columns so every report gets a totals row for free — the
 * "how much money" question should not require the admin to add up a column.
 */
function computeSummary(columns, rows) {
  const summary = {};
  for (const col of columns) {
    if (col.type === 'currency' || col.type === 'number') {
      const total = rows.reduce((acc, r) => {
        const n = Number(r[col.key]);
        return acc + (Number.isFinite(n) ? n : 0);
      }, 0);
      // Rates and averages must not be summed; only real additive measures.
      const additive = col.type === 'currency' || /Count|Transactions|Members|Loans|Contributors|Defaulted/.test(col.label);
      if (additive) summary[col.key] = Math.round(total * 100) / 100;
    }
  }
  return summary;
}

/**
 * Run a report.
 *
 * @param {string} id        catalog report id
 * @param {object} query     raw filter query
 * @param {object} deps      { db } — Supabase client, or a test double
 * @returns {Promise<{report, columns, rows, summary, rowCount, truncated, filters, generatedAt}>}
 */
async function runReport(id, query = {}, deps = {}) {
  const report = getReport(id);
  const db = deps.db;
  if (!db) throw new ReportError('No database client supplied', 500);

  const filters = buildFilters(query);
  const result = (await report.fetch({ db, filters, logger: deps.logger })) || {};
  const strip = result.strip || [];
  let rows = result.rows || [];

  if (strip.length) {
    rows = rows.map((row) => {
      const clean = { ...row };
      for (const key of strip) delete clean[key];
      return clean;
    });
  }

  const truncated = rows.length > MAX_ROWS;
  const limited = truncated ? rows.slice(0, MAX_ROWS) : rows;

  return {
    report: { id: report.id, name: report.name, category: report.category, description: report.description },
    columns: report.columns.map((c) => ({ key: c.key, label: c.label, type: c.type })),
    rows: limited,
    summary: computeSummary(report.columns, limited),
    rowCount: limited.length,
    truncated,
    filters,
    generatedAt: new Date().toISOString(),
  };
}

/** Excel forbids these in sheet names; the writer sanitises too, belt and braces. */
function filenameFor(report, format, generatedAt) {
  const stamp = String(generatedAt || '').slice(0, 10);
  const slug = report.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  return `coopvest-${slug}-${stamp}.${format}`;
}

/**
 * Serialise a report payload.
 *
 * CSV and XLSX both include a trailing "TOTAL" row built from `summary` so the
 * download carries the same totals the screen showed.
 */
function serialise(payload, format) {
  const fmt = String(format || 'json').toLowerCase();
  if (!EXPORT_FORMATS.includes(fmt)) {
    throw new ReportError(`Unsupported format: ${format}. Use one of ${EXPORT_FORMATS.join(', ')}`);
  }

  if (fmt === 'json') {
    return { body: payload, contentType: 'application/json', filename: null };
  }

  // Represent money columns as numbers in exports so spreadsheets can total
  // them; the on-screen JSON keeps the same numeric values.
  const numericColumns = payload.columns.map((c) => c);

  const exportRows = [...payload.rows];
  const summaryCols = Object.keys(payload.summary || {});
  if (summaryCols.length > 0) {
    const totalRow = {};
    for (const c of numericColumns) {
      if (summaryCols.includes(c.key)) totalRow[c.key] = payload.summary[c.key];
    }
    const firstKey = numericColumns[0]?.key;
    if (firstKey && totalRow[firstKey] === undefined) totalRow[firstKey] = 'TOTAL';
    exportRows.push(totalRow);
  }

  const generatedAt = payload.generatedAt;
  if (fmt === 'csv') {
    return {
      body: spreadsheet.toCsv({ columns: numericColumns, rows: exportRows }),
      contentType: 'text/csv; charset=utf-8',
      filename: filenameFor(payload.report, 'csv', generatedAt),
    };
  }

  return {
    body: spreadsheet.toXlsx({
      sheetName: payload.report.name,
      columns: numericColumns,
      rows: exportRows,
    }),
    contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    filename: filenameFor(payload.report, 'xlsx', generatedAt),
  };
}

module.exports = {
  MAX_ROWS,
  EXPORT_FORMATS,
  ReportError,
  buildFilters,
  computeSummary,
  runReport,
  serialise,
  filenameFor,
};
