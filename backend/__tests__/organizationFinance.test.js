const org = require('../src/lib/organizationFinance');

/**
 * Organization finance — the employer/institution model. These are the numbers
 * that tell Coopvest which institutions owe money, so the arithmetic and the
 * "who counts as a member" rules are pinned explicitly.
 */

// Minimal PostgREST-shaped double. Reports read whole tables and filter in JS.
function fakeDb(tables) {
  return {
    from(table) {
      const rows = tables[table] || [];
      const b = {
        select() { return b; }, order() { return b; }, limit() { return b; },
        eq() { return b; }, neq() { return b; }, in() { return b; }, gte() { return b; },
        lte() { return b; }, lt() { return b; }, gt() { return b; }, not() { return b; },
        or() { return b; }, like() { return b; }, ilike() { return b; },
        maybeSingle() { return Promise.resolve({ data: rows[0] || null, error: null }); },
        single() { return Promise.resolve({ data: rows[0] || null, error: null }); },
        then(res) { res({ data: rows, error: null, count: rows.length }); },
      };
      return b;
    },
  };
}

const RANGE = { type: 'month', label: 'September 2026', start: '2026-09-01', end: '2026-09-30' };

const SEED = {
  organizations: [
    { id: 'o1', name: 'Bowen University', code: 'BOWEN', deduction_enabled: true, is_active: true,
      deduction_type: 'payroll', remittance_cycle: 'monthly', member_count: 0,
      remittance_bank_name: 'GTB', remittance_account_number: '0123456789' },
    { id: 'o2', name: 'LAUTECH', code: 'LAU', deduction_enabled: false, is_active: true,
      deduction_type: 'manual_upload', remittance_cycle: 'monthly', member_count: 0 },
  ],
  profiles: [
    // Bowen: two members, 5,000 each → expected 10,000
    { id: 'p1', user_id: 'USR-1', name: 'Ada', organization_id: 'o1', monthly_amount: 5000, is_active: true, is_flagged: false },
    { id: 'p2', user_id: 'USR-2', name: 'Bola', organization_id: 'o1', monthly_amount: 5000, is_active: true, is_flagged: false },
    // LAUTECH: one member, no expectation set
    { id: 'p3', user_id: 'USR-3', name: 'Chidi', organization_id: 'o2', monthly_amount: 0, is_active: true, is_flagged: false },
    // Unlinked, with a pending employer request
    { id: 'p4', user_id: 'USR-4', name: 'Dami', organization_id: null, monthly_amount: 5000, is_active: true,
      is_flagged: false, pending_organization_name: 'Bowen University' },
  ],
  payroll_batches: [
    // Bowen remitted 6,000 of the 10,000 expected in September
    { id: 'b1', organization_id: 'o1', period_month: '2026-09', total_contribution_amount: 6000,
      total_registration_fee_amount: 500, remitted_at: '2026-09-10T00:00:00Z', reconciled: true, mismatch_amount: 0 },
    // A batch for another month must not leak into September
    { id: 'b2', organization_id: 'o1', period_month: '2026-08', total_contribution_amount: 9000,
      total_registration_fee_amount: 0, remitted_at: '2026-08-10T00:00:00Z', reconciled: false, mismatch_amount: 100 },
  ],
  transactions: [
    { id: 't1', profile_id: 'p1', type: 'deposit', status: 'completed', amount: 5000, created_at: '2026-09-05T00:00:00Z' },
    // p2 (Bola) did NOT contribute this month → lapsed
  ],
  loans: [
    { id: 'l1', profile_id: 'p1', status: 'active', amount: 100000, remaining_balance: 40000, next_due_date: '2026-09-20' },
  ],
};

function build(seed = SEED) {
  return org.buildOrganizationPosition({ db: fakeDb(seed), range: RANGE });
}

describe('organization position', () => {
  test('expected monthly is the sum of linked members\' deduction amounts', async () => {
    const out = await build();
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    expect(bowen.expectedMonthly).toBe(10000);
    expect(bowen.members).toBe(2);
  });

  test('remitted is taken from payroll batches for the matching month only', async () => {
    const out = await build();
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    // 6,000 for September; the August batch must not be included.
    expect(bowen.remitted).toBe(6000);
    expect(bowen.remittanceBatches).toBe(1);
  });

  test('outstanding is expected minus remitted', async () => {
    const out = await build();
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    expect(bowen.outstanding).toBe(4000);
  });

  test('a fully-remitted organization has zero outstanding', async () => {
    const seed = structuredClone(SEED);
    seed.payroll_batches = [{ id: 'b1', organization_id: 'o1', period_month: '2026-09',
      total_contribution_amount: 10000, total_registration_fee_amount: 0, reconciled: true, mismatch_amount: 0 }];
    const out = await build(seed);
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    expect(bowen.outstanding).toBe(0);
    expect(bowen.collectionRate).toBe(100);
  });

  test('an over-remittance shows as a negative outstanding, not clamped to zero', async () => {
    // Clamping would hide a surplus that finance needs to reconcile.
    const seed = structuredClone(SEED);
    seed.payroll_batches = [{ id: 'b1', organization_id: 'o1', period_month: '2026-09',
      total_contribution_amount: 15000, total_registration_fee_amount: 0, reconciled: false, mismatch_amount: 0 }];
    const out = await build(seed);
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    expect(bowen.outstanding).toBe(-5000);
  });

  test('totals aggregate across organizations', async () => {
    const out = await build();
    expect(out.totals.expectedMonthly).toBe(10000); // o2's member has no expectation
    expect(out.totals.remitted).toBe(6000);
    expect(out.totals.outstanding).toBe(4000);
    expect(out.totals.members).toBe(3);
  });

  test('gaps in remittance are visible as zero-remitted rows', async () => {
    const out = await build();
    const lau = out.rows.find((r) => r.organizationId === 'o2');
    expect(lau.remitted).toBe(0);
    expect(lau.remittanceBatches).toBe(0);
  });

  test('rows are ordered by what is owed, so the actionable orgs come first', async () => {
    const out = await build();
    expect(out.rows[0].organizationId).toBe('o1'); // owes 4,000
    expect(out.rows[1].organizationId).toBe('o2'); // owes nothing
  });

  test('period is reported back with the month key', async () => {
    const out = await build();
    expect(out.period.month).toBe('2026-09');
  });
});

describe('member status within an organization', () => {
  test('a member who contributed is counted as contributing', async () => {
    const out = await build();
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    expect(bowen.contributingMembers).toBe(1); // p1 paid
    expect(bowen.lapsedMembers).toBe(1);       // p2 did not
  });

  test('a member with no expected amount is not reported as lapsed', async () => {
    // There was nothing to deduct, so calling them lapsed would be wrong.
    const out = await build();
    const lau = out.rows.find((r) => r.organizationId === 'o2');
    expect(lau.lapsedMembers).toBe(0);
    expect(lau.membersWithoutExpectation).toBe(1);
  });
});

describe('unlinked members are surfaced, never dropped', () => {
  test('members with no organization are counted separately', async () => {
    const out = await build();
    expect(out.unlinked.total).toBe(1);
  });

  test('pending employer requests are grouped by requested name', async () => {
    const out = await build();
    expect(out.unlinked.pending).toBe(1);
    expect(out.unlinked.pendingRequests).toEqual([
      { organizationName: 'Bowen University', members: 1 },
    ]);
  });

  test('an unlinked member does not inflate any organization\'s expected figure', async () => {
    // Dami asked for Bowen but is not linked, so Bowen's expectation stays 10k.
    const out = await build();
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    expect(bowen.expectedMonthly).toBe(10000);
    expect(bowen.members).toBe(2);
  });
});

describe('stored member_count drift', () => {
  test('the live count is reported alongside the stored counter', async () => {
    // `organizations.member_count` reads 0 for every org in production while
    // members exist, so the drift has to be visible.
    const out = await build();
    const bowen = out.rows.find((r) => r.organizationId === 'o1');
    expect(bowen.members).toBe(2);
    expect(bowen.storedMemberCount).toBe(0);
    expect(bowen.memberCountDrift).toBe(-2);
  });
});

describe('organization detail', () => {
  test('lists members with their expected, contributed and variance', async () => {
    const detail = await org.buildOrganizationDetail({
      db: fakeDb(SEED), orgId: 'o1', range: RANGE,
    });
    expect(detail.members).toHaveLength(2);
    const ada = detail.members.find((m) => m.member === 'Ada');
    expect(ada.expectedMonthly).toBe(5000);
    expect(ada.contributed).toBe(5000);
    expect(ada.variance).toBe(0);
    const bola = detail.members.find((m) => m.member === 'Bola');
    expect(bola.contributed).toBe(0);
    expect(bola.variance).toBe(-5000);
  });

  test('includes loan exposure per member', async () => {
    const detail = await org.buildOrganizationDetail({
      db: fakeDb(SEED), orgId: 'o1', range: RANGE,
    });
    const ada = detail.members.find((m) => m.member === 'Ada');
    expect(ada.activeLoans).toBe(1);
    expect(ada.outstandingLoans).toBe(40000);
  });

  test('remittance history is newest first', async () => {
    const detail = await org.buildOrganizationDetail({
      db: fakeDb(SEED), orgId: 'o1', range: RANGE,
    });
    expect(detail.remittanceHistory[0].periodMonth).toBe('2026-09');
    expect(detail.remittanceHistory[1].periodMonth).toBe('2026-08');
  });

  test('an unknown organization returns null rather than throwing', async () => {
    const detail = await org.buildOrganizationDetail({
      db: fakeDb(SEED), orgId: 'nope', range: RANGE,
    });
    expect(detail).toBeNull();
  });
});

describe('organization trend', () => {
  test('returns a continuous month series including months with no remittance', async () => {
    const trend = await org.buildOrganizationTrend({ db: fakeDb(SEED), orgId: 'o1', months: 3 });
    expect(trend.months).toHaveLength(3);
    // Every month carries an expected figure so a gap is a visible zero, not an
    // absent point.
    for (const m of trend.months) expect(m.expected).toBe(10000);
  });

  test('the last month in the series is the current month', async () => {
    const trend = await org.buildOrganizationTrend({ db: fakeDb(SEED), orgId: 'o1', months: 2 });
    const now = new Date();
    const key = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
    expect(trend.months[trend.months.length - 1].periodMonth).toBe(key);
  });
});
