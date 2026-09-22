const engine = require('../src/lib/comparisonEngine');
const metrics = require('../src/lib/comparativeMetrics');

/**
 * Comparison maths and the calculations behind each metric. These are the
 * numbers management reads, so the edge cases (zero base, rates vs amounts,
 * point-in-time balances) are pinned explicitly.
 */
describe('change calculation', () => {
  test('matches the worked example from the specification', () => {
    // January ₦8,500,000 → February ₦11,200,000 = +₦2.7M / +31.8%
    const c = engine.changeBetween(8500000, 11200000);
    expect(c.absolute).toBe(2700000);
    expect(c.percent).toBe(31.76);
    expect(c.direction).toBe('up');
  });

  test('reports a decrease with a negative absolute change', () => {
    const c = engine.changeBetween(84, 71);
    expect(c.absolute).toBe(-13);
    expect(c.percent).toBe(-15.48);
    expect(c.direction).toBe('down');
  });

  test('a zero base yields null percent with a reason, never Infinity', () => {
    const c = engine.changeBetween(0, 100);
    expect(c.absolute).toBe(100);
    expect(c.percent).toBeNull();
    expect(Number.isFinite(c.absolute)).toBe(true);
    expect(c.percentUnavailableReason).toBe('no_activity_in_period_a');
  });

  test('zero in both periods is flat, not an error', () => {
    const c = engine.changeBetween(0, 0);
    expect(c.absolute).toBe(0);
    expect(c.direction).toBe('flat');
    expect(c.percentUnavailableReason).toBe('no_activity_either_period');
  });

  test('rates compare in percentage points, not percent change', () => {
    // Default rate 4.8% → 3.1% is a 1.7pp fall. Calling that "-35.4%" against
    // itself would be misleading on a rate.
    const c = engine.percentagePointChange(4.8, 3.1);
    expect(c.percentagePoints).toBe(-1.7);
    expect(c.percent).toBeNull();
    expect(c.direction).toBe('down');
  });
});

describe('metric list comparison', () => {
  test('matches metrics by key, not position', () => {
    const a = [{ key: 'x', label: 'X', value: 1, unit: 'number' }];
    const b = [{ key: 'y', label: 'Y', value: 2, unit: 'number' }, { key: 'x', label: 'X', value: 3, unit: 'number' }];
    const out = engine.compareMetricLists(a, b);
    const x = out.find((m) => m.key === 'x');
    expect(x.periodA).toBe(1);
    expect(x.periodB).toBe(3);
  });

  test('a metric present only in period B compares against zero', () => {
    const out = engine.compareMetricLists([], [{ key: 'z', label: 'Z', value: 5, unit: 'number' }]);
    expect(out[0].periodA).toBe(0);
    expect(out[0].periodB).toBe(5);
    expect(out[0].percent).toBeNull();
  });

  test('is unaffected by metric ordering', () => {
    const a = [
      { key: 'a', label: 'A', value: 1, unit: 'number' },
      { key: 'b', label: 'B', value: 2, unit: 'number' },
    ];
    const b = [
      { key: 'b', label: 'B', value: 4, unit: 'number' },
      { key: 'a', label: 'A', value: 2, unit: 'number' },
    ];
    const out = engine.compareMetricLists(a, b);
    expect(out.find((m) => m.key === 'a').absolute).toBe(1);
    expect(out.find((m) => m.key === 'b').absolute).toBe(2);
  });
});

describe('organization comparison', () => {
  const rowsA = [{ organizationId: 'o1', organization: 'Bowen University', code: 'BOWEN', members: 400, contributions: 4000000, repaymentRate: 96.2 }];
  const rowsB = [{ organizationId: 'o1', organization: 'Bowen University', code: 'BOWEN', members: 420, contributions: 4200000, repaymentRate: 96.0 }];

  test('pairs the same organization across two periods', () => {
    const out = engine.compareOrganizationRows(rowsA, rowsB);
    expect(out).toHaveLength(1);
    const members = out[0].metrics.find((m) => m.key === 'members');
    expect(members.periodA).toBe(400);
    expect(members.periodB).toBe(420);
    expect(members.percent).toBe(5);
  });

  test('an organization present in only one period still appears', () => {
    const out = engine.compareOrganizationRows(rowsA, [
      ...rowsB,
      { organizationId: 'o2', organization: 'LAUTECH', code: 'LAU', members: 315, contributions: 3100000, repaymentRate: 94.8 },
    ]);
    expect(out).toHaveLength(2);
    const lau = out.find((o) => o.organizationId === 'o2');
    expect(lau.metrics.find((m) => m.key === 'members').periodA).toBe(0);
  });

  test('sorts by period B contributions descending', () => {
    const out = engine.compareOrganizationRows(rowsA, [
      { organizationId: 'o1', organization: 'Small', contributions: 1000, members: 1 },
      { organizationId: 'o2', organization: 'Big', contributions: 9000, members: 1 },
    ]);
    expect(out[0].organization).toBe('Big');
  });
});

describe('insight generation', () => {
  const comparison = {
    periods: { a: { label: 'January 2026' }, b: { label: 'February 2026' } },
    sections: [
      {
        key: 'savings',
        label: 'Savings',
        metrics: [
          { key: 'total_contributions', label: 'Total contributions', unit: 'currency', periodA: 8500000, periodB: 11200000, absolute: 2700000, percent: 31.76, direction: 'up', higherIsBetter: true },
          { key: 'salary_share_pct', label: 'Salary share', unit: 'percent', periodA: 70, periodB: 78, absolute: 8, percentagePoints: 8, percent: null, direction: 'up' },
        ],
      },
      {
        key: 'membership',
        label: 'Membership',
        metrics: [
          { key: 'new_members', label: 'New members', unit: 'number', periodA: 125, periodB: 178, absolute: 53, percent: 42.4, direction: 'up', higherIsBetter: true },
        ],
      },
      {
        key: 'loans',
        label: 'Loans',
        metrics: [
          { key: 'amount_disbursed', label: 'Amount disbursed', unit: 'currency', periodA: 45000000, periodB: 72000000, absolute: 27000000, percent: 60, direction: 'up', higherIsBetter: true },
          { key: 'default_rate', label: 'Default rate', unit: 'percent', periodA: 4.8, periodB: 3.1, absolute: -1.7, percentagePoints: -1.7, percent: null, direction: 'down', higherIsBetter: false },
        ],
      },
    ],
  };

  test('the executive summary covers contributions, membership and loans', () => {
    const { summary } = engine.generateInsights(comparison);
    expect(summary).toContain('Contributions increased');
    expect(summary).toContain('New membership increased');
    expect(summary).toContain('Loan disbursement increased');
  });

  test('a falling default rate is treated as a decrease, not a decline', () => {
    const { insights } = engine.generateInsights(comparison);
    const dr = insights.find((i) => i.metric === 'default_rate');
    expect(dr).toBeTruthy();
    expect(dr.text).toContain('percentage points');
    // lower is better, and it fell, so the sentiment is positive
    expect(dr.sentiment).toBe('positive');
  });

  test('rates are described in percentage points, never as a percent change', () => {
    const { insights } = engine.generateInsights(comparison);
    const share = insights.find((i) => i.metric === 'salary_share_pct');
    // The movement is "8.0 percentage points". The sentence still shows the two
    // rate values (70.0% → 78.0%), which is correct — what must not appear is a
    // percentage *change* of the rate itself.
    expect(share.text).toContain('rose by 8.0 percentage points');
    expect(share.text).not.toMatch(/\(8\.0%\)/);
    expect(share.text).not.toContain('increased by 8.0%');
  });

  test('insight counts separate improvement from decline', () => {
    const out = engine.generateInsights(comparison);
    expect(out.improvedCount).toBeGreaterThan(0);
    expect(out.improvementRate).toBeGreaterThan(0);
  });
});

describe('loan position reconstruction', () => {
  // A loan's live balance is today's figure. To compare quarter-on-quarter the
  // balance has to be rewound to the period end, or every past period would
  // show today's book.
  const loan = { id: 'L1', amount: 900000, original_principal: 900000, remaining_balance: 500000, principal_repaid: 400000, created_at: '2026-01-10T00:00:00Z' };
  const repayments = [
    { loan_id: 'L1', amount: 100000, principal_component: 90000, paid_at: '2026-02-01T00:00:00Z' },
    { loan_id: 'L1', amount: 100000, principal_component: 90000, paid_at: '2026-05-01T00:00:00Z' },
  ];

  test('rewinds the balance to the period end', () => {
    // At 31 Mar only the February repayment had happened, so the balance was
    // 100,000 higher than the live figure.
    const endMs = new Date('2026-03-31T23:59:59.999Z').getTime();
    const pos = metrics.loanPositionAsAt(loan, repayments, endMs, Date.now());
    expect(pos.balanceAtEnd).toBe(600000);
    expect(pos.principalRepaidAtEnd).toBe(310000);
  });

  test('the live figure is unchanged when the period end is now', () => {
    const now = Date.now();
    const pos = metrics.loanPositionAsAt(loan, repayments, now, now);
    expect(pos.balanceAtEnd).toBe(500000);
    expect(pos.principalRepaidAtEnd).toBe(400000);
  });

  test('a loan created after the period end did not exist then', () => {
    const endMs = new Date('2026-01-01T23:59:59.999Z').getTime();
    const pos = metrics.loanPositionAsAt(loan, repayments, endMs, Date.now());
    expect(pos.existed).toBe(false);
  });
});

describe('income categorisation', () => {
  test('distinguishes the levy types management reports on', () => {
    expect(metrics.incomeCategoryOf({ fee_type: 'levy', label: 'AGM Levy' })).toBe('agm_levies');
    expect(metrics.incomeCategoryOf({ fee_type: 'levy', label: 'Development Levy' })).toBe('development_levies');
    expect(metrics.incomeCategoryOf({ fee_type: 'registration_fee' })).toBe('registration_fees');
    expect(metrics.incomeCategoryOf({ fee_type: 'fee', label: 'Mobile App Fee' })).toBe('other_income');
    expect(metrics.incomeCategoryOf({ fee_type: 'fine', label: 'Late Repayment Fine' })).toBe('other_income');
  });
});

describe('rate helper', () => {
  test('guards against divide-by-zero', () => {
    expect(metrics.rate(1, 0)).toBe(0);
    expect(metrics.rate(0, 0)).toBe(0);
  });

  test('rounds to one decimal place', () => {
    expect(metrics.rate(1, 3)).toBe(33.3);
  });
});

describe('ledger authority', () => {
  // The `transactions` table is the central ledger. `contributions` is derived
  // and drifted on the live project (it holds a ₦100,000,000 row the ledger
  // does not). A headline figure must be traceable to real transactions, so the
  // ledger wins and the disagreement is surfaced rather than hidden.
  const range = { start: '2026-09-01', end: '2026-09-30' };

  function dbWith({ transactions, contributions }) {
    return {
      from(table) {
        const rows = table === 'transactions' ? transactions
          : table === 'contributions' ? contributions
            : [];
        const b = {
          select() { return b; }, order() { return b; }, limit() { return b; },
          eq() { return b; }, neq() { return b; }, in() { return b; }, gte() { return b; },
          lte() { return b; }, lt() { return b; }, gt() { return b; }, not() { return b; },
          or() { return b; }, like() { return b; },
          then(res) { res({ data: rows, error: null, count: rows.length }); },
        };
        return b;
      },
    };
  }

  test('uses the ledger total, not the derived contributions table', async () => {
    const out = await metrics.SECTIONS.savings.run({
      db: dbWith({
        transactions: [{ id: 't1', profile_id: 'p1', type: 'deposit', status: 'completed', amount: 5000, created_at: '2026-09-10T00:00:00Z' }],
        contributions: [{ id: 'c1', profile_id: 'p1', amount: 100000000, created_at: '2026-09-10T00:00:00Z' }],
      }),
      range,
    });
    const total = out.metrics.find((m) => m.key === 'total_contributions').value;
    expect(total).toBe(5000);
    expect(out.dataQuality).toHaveLength(1);
    expect(out.dataQuality[0].check).toBe('contributions_table_vs_ledger');
    expect(out.dataQuality[0].difference).toBe(99995000);
  });

  test('no warning when the two agree', async () => {
    const row = { profile_id: 'p1', amount: 5000, created_at: '2026-09-10T00:00:00Z' };
    const out = await metrics.SECTIONS.savings.run({
      db: dbWith({
        transactions: [{ id: 't1', type: 'deposit', status: 'completed', ...row }],
        contributions: [{ id: 'c1', ...row }],
      }),
      range,
    });
    expect(out.dataQuality).toHaveLength(0);
    expect(out.metrics.find((m) => m.key === 'total_contributions').value).toBe(5000);
  });

  test('failed and reversed transactions never count as contributions', async () => {
    const out = await metrics.SECTIONS.savings.run({
      db: dbWith({
        transactions: [
          { id: 't1', profile_id: 'p1', type: 'deposit', status: 'completed', amount: 1000, created_at: '2026-09-10T00:00:00Z' },
          { id: 't2', profile_id: 'p1', type: 'deposit', status: 'failed', amount: 9000, created_at: '2026-09-10T00:00:00Z' },
          { id: 't3', profile_id: 'p1', type: 'deposit', status: 'reversed', amount: 9000, created_at: '2026-09-10T00:00:00Z' },
        ],
        contributions: [],
      }),
      range,
    });
    expect(out.metrics.find((m) => m.key === 'total_contributions').value).toBe(1000);
  });
});
