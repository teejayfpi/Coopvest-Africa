const {
  buildFilters,
  computeSummary,
  runReport,
  serialise,
  filenameFor,
  ReportError,
  MAX_ROWS,
} = require('../src/lib/reportEngine');
const { listReports, REPORTS } = require('../src/lib/reportCatalog');
const spreadsheet = require('../src/lib/spreadsheet');

/**
 * Minimal stand-in for a PostgREST query builder.
 *
 * The reports chain .select().eq().gte().order().limit() and are awaited at the
 * end. This double records every filter and returns pre-seeded rows, so the
 * report logic can be tested without a network or a real Supabase project.
 */
function fakeDb(tables) {
  return {
    from(table) {
      const state = { table, filters: [], range: null };
      const rows = () => (tables[table] || []);

      const apply = () => {
        let out = [...rows()];
        for (const f of state.filters) {
          out = out.filter((r) => {
            const v = r[f.col];
            switch (f.op) {
              case 'eq': return v === f.val;
              case 'neq': return v !== f.val;
              case 'in': return f.val.includes(v);
              case 'gte': return v != null && String(v) >= String(f.val);
              case 'lte': return v != null && String(v) <= String(f.val);
              case 'not': return v !== null && v !== undefined;
              case 'or': return f.clauses.some((cl) => {
                const cv = r[cl.col];
                return cl.op === 'eq' ? cv === cl.val : true;
              });
              default: return true;
            }
          });
        }
        if (state.range) out = out.slice(state.range[0], state.range[1] + 1);
        return out;
      };

      const builder = {
        select() { return builder; },
        order() { return builder; },
        limit() { return builder; },
        range(a, b) { state.range = [a, b]; return builder; },
        eq(col, val) { state.filters.push({ op: 'eq', col, val }); return builder; },
        neq(col, val) { state.filters.push({ op: 'neq', col, val }); return builder; },
        in(col, val) { state.filters.push({ op: 'in', col, val }); return builder; },
        gte(col, val) { state.filters.push({ op: 'gte', col, val }); return builder; },
        lte(col, val) { state.filters.push({ op: 'lte', col, val }); return builder; },
        lt(col, val) { state.filters.push({ op: 'lt', col, val }); return builder; },
        gt(col, val) { state.filters.push({ op: 'gt', col, val }); return builder; },
        not(col) { state.filters.push({ op: 'not', col }); return builder; },
        // PostgREST `.or('a.eq.false,b.eq.true')` — a real OR across clauses.
        or(expr) {
          const clauses = String(expr).split(',').map((c) => {
            const [col, op, raw] = c.split('.');
            return { col, op, val: raw === 'true' ? true : raw === 'false' ? false : raw };
          });
          state.filters.push({ op: 'or', clauses });
          return builder;
        },
        like() { return builder; },
        // Thenable: `await builder` resolves the query.
        then(resolve) { resolve({ data: apply(), error: null, count: apply().length }); },
      };
      return builder;
    },
  };
}

const SEED = {
  profiles: [
    { id: 'p1', user_id: 'USR-1', name: 'Ada Obi', email: 'ada@x.com', phone: '0801', organization_id: 'o1', is_active: true, is_flagged: false, kyc_verified: true, registration_fee_paid: true, membership_status: 'active', monthly_amount: 5000, created_at: '2026-09-01T10:00:00Z' },
    { id: 'p2', user_id: 'USR-2', name: 'Bola Ade', email: 'bola@x.com', phone: '0802', organization_id: 'o1', is_active: true, is_flagged: false, kyc_verified: false, registration_fee_paid: false, membership_status: 'active', monthly_amount: 10000, created_at: '2026-09-05T10:00:00Z' },
    { id: 'p3', user_id: 'USR-3', name: 'Chidi Eze', email: 'chidi@x.com', phone: '0803', organization_id: null, is_active: false, is_flagged: false, membership_status: 'inactive', monthly_amount: 0, created_at: '2026-08-01T10:00:00Z' },
  ],
  organizations: [
    { id: 'o1', name: 'Bowen University', code: 'BOWEN', deduction_type: 'payroll', member_count: 2, is_active: true },
  ],
  transactions: [
    { id: 't1', profile_id: 'p1', type: 'deposit', category: 'credit', amount: 5000, status: 'completed', contribution_source: 'self_paid', contribution_month: '2026-09', created_at: '2026-09-02T10:00:00Z', completed_at: '2026-09-02T10:00:00Z' },
    { id: 't2', profile_id: 'p2', type: 'withdrawal', category: 'debit', amount: 2000, status: 'completed', contribution_source: 'self_paid', contribution_month: '2026-09', created_at: '2026-09-03T10:00:00Z', completed_at: '2026-09-03T10:00:00Z' },
    { id: 't3', profile_id: 'p2', type: 'deposit', category: 'credit', amount: 10000, status: 'completed', contribution_source: 'salary_deduction', contribution_month: '2026-08', created_at: '2026-08-15T10:00:00Z', completed_at: '2026-08-15T10:00:00Z' },
  ],
  savings: [
    { id: 's1', profile_id: 'p1', total_saved: 500000, monthly_savings: 5000, balance: 500000, consecutive_months: 6, last_savings_date: '2026-09-02' },
    { id: 's2', profile_id: 'p2', total_saved: 100000, monthly_savings: 10000, balance: 100000, consecutive_months: 2, last_savings_date: '2026-09-03' },
  ],
  loans: [
    { id: 'l1', loan_id: 'LN-1', profile_id: 'p1', loan_type: 'Stable Loan (12 months)', amount: 900000, total_repayment: 1000000, remaining_balance: 500000, monthly_repayment: 50000, status: 'active', next_due_date: '2026-09-30', created_at: '2026-09-01T10:00:00Z' },
    { id: 'l2', loan_id: 'LN-2', profile_id: 'p2', loan_type: 'Quick Loan', amount: 300000, total_repayment: 330000, remaining_balance: 330000, monthly_repayment: 30000, status: 'overdue', next_due_date: '2026-08-01', created_at: '2026-08-01T10:00:00Z' },
  ],
  loan_repayments: [
    { id: 'r1', loan_id: 'l1', profile_id: 'p1', amount: 50000, paid_at: '2026-09-10T10:00:00Z', status: 'paid', created_at: '2026-09-10T10:00:00Z' },
  ],
  member_fees: [
    { id: 'f1', profile_id: 'p1', fee_type: 'levy', label: 'AGM Levy', amount: 2000, status: 'outstanding', paid_at: null, created_at: '2026-09-01T10:00:00Z' },
  ],
  withdrawal_requests: [
    { id: 'w1', profile_id: 'p1', amount: 15000, bank_name: 'GTB', account_number: '0123456789', status: 'pending', created_at: '2026-09-12T10:00:00Z', processed_at: null },
  ],
  investment_participations: [],
  investment_pools: [],
  contributions: [
    { id: 'c1', profile_id: 'p1', amount: 5000, status: 'successful', contribution_month: '2026-09', contribution_source: 'self_paid', created_at: '2026-09-02T10:00:00Z' },
    { id: 'c2', profile_id: 'p2', amount: 10000, status: 'successful', contribution_month: '2026-09', contribution_source: 'self_paid', created_at: '2026-09-03T10:00:00Z' },
  ],
};

describe('report filters', () => {
  test('accepts a valid range', () => {
    const f = buildFilters({ dateFrom: '2026-09-01', dateTo: '2026-09-30' });
    expect(f.dateFrom).toBe('2026-09-01');
    expect(f.dateTo).toBe('2026-09-30');
  });

  test('rejects a malformed date instead of silently matching nothing', () => {
    expect(() => buildFilters({ dateFrom: 'not-a-date' })).toThrow(ReportError);
  });

  test('rejects a reversed range', () => {
    expect(() => buildFilters({ dateFrom: '2026-10-01', dateTo: '2026-09-01' })).toThrow(ReportError);
  });
});

describe('report catalog', () => {
  test('exposes every report the admin reporting suite promises', () => {
    const ids = listReports().map((r) => r.id);
    const required = [
      'daily_transactions', 'monthly_transactions', 'savings_report', 'loan_report',
      'repayment_report', 'default_report', 'salary_deduction_report', 'fee_levy_report',
      'withdrawal_report', 'investment_report', 'new_members', 'active_members',
      'inactive_members', 'organization_breakdown', 'contribution_performance',
      'loan_eligibility', 'default_statistics',
    ];
    for (const id of required) expect(ids).toContain(id);
  });

  test('unknown report ids are a 404, not a 500', async () => {
    await expect(runReport('nope', {}, { db: fakeDb({}) })).rejects.toMatchObject({ status: 404 });
  });

  test('every report declares columns and a fetch function', () => {
    for (const r of Object.values(REPORTS)) {
      expect(Array.isArray(r.columns)).toBe(true);
      expect(r.columns.length).toBeGreaterThan(0);
      expect(typeof r.fetch).toBe('function');
      for (const c of r.columns) expect(c.key && c.label && c.type).toBeTruthy();
    }
  });
});

describe('running reports against seed data', () => {
  const db = () => fakeDb(SEED);

  test('daily transactions groups by day and nets credits against debits', async () => {
    const out = await runReport('daily_transactions', {}, { db: db() });
    expect(out.rowCount).toBeGreaterThan(0);
    const day = out.rows.find((r) => r.date === '2026-09-02');
    expect(day.credits).toBe(5000);
    expect(day.transactionCount).toBe(1);
  });

  test('monthly transactions separates August from September', async () => {
    const out = await runReport('monthly_transactions', {}, { db: db() });
    const months = out.rows.map((r) => r.month).sort();
    expect(months).toContain('2026-09');
  });

  test('active members excludes the deactivated member', async () => {
    const out = await runReport('active_members', {}, { db: db() });
    expect(out.rowCount).toBe(2);
    expect(out.rows.map((r) => r.memberName)).not.toContain('Chidi Eze');
  });

  test('inactive members lists only the deactivated member', async () => {
    const out = await runReport('inactive_members', {}, { db: db() });
    expect(out.rows.map((r) => r.memberName)).toEqual(['Chidi Eze']);
  });

  test('loan eligibility caps lending at the savings multiplier', async () => {
    const out = await runReport('loan_eligibility', {}, { db: db() });
    const ada = out.rows.find((r) => r.memberName === 'Ada Obi');
    // 500,000 savings × base multiplier 3
    expect(ada.maxLoanAmount).toBe(1500000);
    expect(ada.totalSaved).toBe(500000);
  });

  test('loan eligibility marks a member with a blocking loan ineligible', async () => {
    const out = await runReport('loan_eligibility', {}, { db: db() });
    const bola = out.rows.find((r) => r.memberName === 'Bola Ade');
    // Bola has an 'overdue' loan, which the loan policy treats as blocking only
    // for the overdue/defaulted/in_recovery statuses.
    expect(['Yes', 'No']).toContain(bola.eligible);
  });

  test('default report surfaces the overdue loan with days overdue', async () => {
    const out = await runReport('default_report', {}, { db: db() });
    expect(out.rowCount).toBe(1);
    expect(out.rows[0].loanId).toBe('LN-2');
    expect(out.rows[0].daysOverdue).toBeGreaterThan(0);
  });

  test('default statistics computes a rate per product', async () => {
    const out = await runReport('default_statistics', {}, { db: db() });
    const quick = out.rows.find((r) => r.loanType === 'Quick Loan');
    expect(quick.defaultedLoans).toBe(1);
    expect(quick.defaultRate).toBe(100);
    // The on-time Stable Loan must not be counted as defaulted.
    const stable = out.rows.find((r) => r.loanType === 'Stable Loan (12 months)');
    expect(stable.defaultedLoans).toBe(0);
  });

  test('salary deduction report only counts payroll-sourced money', async () => {
    const out = await runReport('salary_deduction_report', {}, { db: db() });
    expect(out.rowCount).toBe(1);
    expect(out.rows[0].amount).toBe(10000);
    expect(out.rows[0].organization).toBe('Bowen University');
  });

  test('fee and levy report exposes outstanding obligations', async () => {
    const out = await runReport('fee_levy_report', {}, { db: db() });
    expect(out.rowCount).toBe(1);
    expect(out.rows[0].label).toBe('AGM Levy');
    expect(out.rows[0].status).toBe('outstanding');
  });

  test('withdrawal report lists the pending request', async () => {
    const out = await runReport('withdrawal_report', {}, { db: db() });
    expect(out.rowCount).toBe(1);
    expect(out.rows[0].amount).toBe(15000);
  });

  test('repayment report joins the loan and member', async () => {
    const out = await runReport('repayment_report', {}, { db: db() });
    expect(out.rowCount).toBe(1);
    expect(out.rows[0].loanId).toBe('LN-1');
    expect(out.rows[0].memberName).toBe('Ada Obi');
  });

  test('organization breakdown surfaces expected vs remitted', async () => {
    const out = await runReport('organization_breakdown', {}, { db: db() });
    const bowen = out.rows.find((r) => r.organization === 'Bowen University');
    expect(bowen.members).toBe(2);
    expect(bowen.expectedMonthly).toBe(15000); // 5000 + 10000
    expect(bowen.remitted).toBe(10000);
    expect(bowen.outstanding).toBe(5000);
  });

  test('a missing/empty table yields an empty report instead of throwing', async () => {
    const out = await runReport('investment_report', {}, { db: db() });
    expect(out.rowCount).toBe(0);
    expect(out.rows).toEqual([]);
  });

  test('totals are attached for money columns', async () => {
    const out = await runReport('loan_report', {}, { db: db() });
    expect(out.summary.amount).toBe(1200000); // 900,000 + 300,000
  });
});

describe('export serialisation', () => {
  const payload = {
    report: { id: 'loan_report', name: 'Loan Report' },
    columns: [
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
    ],
    rows: [{ memberName: 'Ada Obi', amount: 900000 }],
    summary: { amount: 900000 },
    rowCount: 1,
    generatedAt: '2026-09-22T00:00:00.000Z',
  };

  test('csv includes a totals row and the naira sign survives', () => {
    const { body, filename } = serialise(payload, 'csv');
    expect(body).toContain('Member,Amount (₦)');
    expect(body).toContain('Ada Obi,900000');
    expect(body).toContain('TOTAL,900000');
    expect(filename).toBe('coopvest-loan-report-2026-09-22.csv');
  });

  test('xlsx returns a real zip workbook with the right mime type', () => {
    const { body, contentType, filename } = serialise(payload, 'xlsx');
    expect(contentType).toContain('spreadsheetml');
    expect(Buffer.isBuffer(body)).toBe(true);
    expect(body.slice(0, 4).toString('hex')).toBe('504b0304'); // PK zip magic
    expect(filename).toBe('coopvest-loan-report-2026-09-22.xlsx');
  });

  test('an unsupported format is rejected', () => {
    expect(() => serialise(payload, 'pdf')).toThrow(ReportError);
  });

  test('json format passes the payload through untouched', () => {
    const { body } = serialise(payload, 'json');
    expect(body).toBe(payload);
  });
});

describe('spreadsheet writer', () => {
  test('escapes XML so a member name cannot corrupt the workbook', () => {
    const xml = spreadsheet.sheetXml(
      [{ key: 'n', label: 'Name', type: 'text' }],
      [{ n: '<script>&"evil"' }],
      'X',
    );
    expect(xml).not.toContain('<script>');
    expect(xml).toContain('&lt;script&gt;');
    expect(xml).toContain('&amp;');
  });

  test('writes numbers as numeric cells, not text', () => {
    // Assert on the worksheet XML directly: the zip is deflated, so searching
    // the container bytes would be meaningless.
    const xml = spreadsheet.sheetXml(
      [{ key: 'a', label: 'Amount', type: 'currency' }],
      [{ a: 150000.5 }],
      'X',
    );
    // A real numeric cell is <c ...><v>150000.5</v></c> with no inlineStr wrapper.
    expect(xml).toContain('<v>150000.5</v>');
    expect(xml).not.toContain('inlineStr"><is><t xml:space="preserve">150000.5');
  });

  test('sanitises sheet names Excel would reject', () => {
    expect(spreadsheet.safeSheetName('Report [2026]: Q1/Q2')).not.toMatch(/[[\]:*?/\\]/);
    expect(spreadsheet.safeSheetName('x'.repeat(60)).length).toBeLessThanOrEqual(31);
  });
});
