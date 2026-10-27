/**
 * A member whose contributions are withheld by an employer has the monthly
 * administrative fee recovered from their salary, so it must not also be
 * presented as an in-app obligation — that would charge them twice for the same
 * month. These tests drive the real `computeObligations` against a stubbed
 * Supabase, so the rule is pinned at the point the app actually reads it.
 *
 * The exemption is narrow: only the administrative fee is hidden, only for
 * members with an employer on file, and fines stay payable because a penalty is
 * not part of the standard monthly deduction.
 */
const mockTables = {};

jest.mock('../src/config/supabase', () => ({
  from: (table) => {
    const query = {
      select: () => query,
      eq: () => query,
      in: () => query,
      order: () => query,
      limit: () => query,
      maybeSingle: () => Promise.resolve({ data: mockTables[table] ?? null, error: null }),
      then: (resolve) => resolve({ data: mockTables[table] ?? [], error: null }),
    };
    return query;
  },
}));

const { computeObligations } = require('../src/routes/wallet');

const ADMIN_FEE_TYPE_ID = 'ft-admin-fee';

const ADMIN_FEE_ROW = {
  id: 'mf-admin-fee',
  fee_type: 'fee',
  fee_type_id: ADMIN_FEE_TYPE_ID,
  label: 'Administrative Fee',
  loan_id: null,
  amount: 1500,
  created_at: '2026-03-01T00:00:00Z',
};

const FINE_ROW = {
  id: 'mf-fine',
  fee_type: 'fine',
  fee_type_id: 'ft-late-fine',
  label: 'Late Loan Repayment Fine',
  loan_id: null,
  amount: 3000,
  created_at: '2026-03-01T00:00:00Z',
};

const OTHER_FEE_ROW = {
  id: 'mf-other',
  fee_type: 'fee',
  fee_type_id: 'ft-development-levy',
  label: 'Development Levy',
  loan_id: null,
  amount: 500,
  created_at: '2026-03-01T00:00:00Z',
};

function resetTables({ profile, memberFees = [], loans = [] }) {
  for (const key of Object.keys(mockTables)) delete mockTables[key];
  mockTables.profiles = { created_at: '2024-01-15T00:00:00Z', ...profile };
  mockTables.savings = { monthly_savings: 5000, last_savings_date: null };
  mockTables.contribution_plans = { current_monthly_amount: 5000 };
  mockTables.loans = loans;
  mockTables.member_fees = memberFees;
  mockTables.contributions = [];
  mockTables.fee_types = { id: ADMIN_FEE_TYPE_ID };
}

describe('administrative fee is withheld for salary-deduction members', () => {
  test('a payroll member with an employer is not shown the fee in-app', async () => {
    resetTables({
      profile: {
        contribution_method: 'payroll',
        contribution_type: 'salary_deduction',
        organization_id: 'org-1',
        pending_organization_name: null,
      },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');

    expect(o.fees).toHaveLength(0);
    expect(o.administrative_fee_exempt).toBe(true);
    // Savings only — the ₦1,500 is recovered from salary, not owed in the app.
    expect(o.total_due).toBe(5000);
  });

  test('the KYC spelling salary_deduction is honoured too', async () => {
    // The sign-up wizard writes `contribution_type`; the settings screen writes
    // `contribution_method`. Either must identify the member.
    resetTables({
      profile: {
        contribution_method: null,
        contribution_type: 'salary_deduction',
        organization_id: 'org-1',
      },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');
    expect(o.fees).toHaveLength(0);
    expect(o.total_due).toBe(5000);
  });

  test('a pending employer enrolment counts as an employer on file', async () => {
    resetTables({
      profile: {
        contribution_method: 'payroll',
        contribution_type: 'salary_deduction',
        organization_id: null,
        pending_organization_name: 'Lagos State Ministry of Finance',
      },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');
    expect(o.fees).toHaveLength(0);
  });

  test('the exemption is reported so the app can explain the waiver', async () => {
    resetTables({
      profile: { contribution_method: 'payroll', contribution_type: 'salary_deduction', organization_id: 'org-1' },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');
    expect(o.administrative_fee_exempt).toBe(true);
  });
});

describe('the exemption does not leak', () => {
  test('a self-paying member still owes the fee', async () => {
    resetTables({
      profile: { contribution_method: 'manual', contribution_type: 'direct_deposit', organization_id: 'org-1' },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');

    expect(o.fees).toHaveLength(1);
    expect(o.fees[0].amount).toBe(1500);
    expect(o.administrative_fee_exempt).toBeUndefined();
    expect(o.total_due).toBe(6500);
  });

  test('a payroll member with no employer on file still owes the fee', async () => {
    // Without an employer there is no deduction to recover the fee from, so the
    // in-app obligation stands. This is the guard against exempting on the
    // strength of the contribution method alone.
    resetTables({
      profile: {
        contribution_method: 'payroll',
        contribution_type: 'salary_deduction',
        organization_id: null,
        pending_organization_name: null,
      },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');
    expect(o.fees).toHaveLength(1);
    expect(o.total_due).toBe(6500);
  });

  test('a fine stays payable for a payroll member', async () => {
    // A penalty is not part of the standard monthly deduction, so it is not
    // covered by the exemption.
    resetTables({
      profile: { contribution_method: 'payroll', contribution_type: 'salary_deduction', organization_id: 'org-1' },
      memberFees: [FINE_ROW, ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');

    expect(o.fines).toHaveLength(1);
    expect(o.fines[0].amount).toBe(3000);
    expect(o.fees).toHaveLength(0);
    expect(o.total_due).toBe(8000);
  });

  test('a non-administrative fee is untouched for a payroll member', async () => {
    // Only the identified administrative-fee row is hidden. Another 'fee'
    // category entry (here a separate Development Levy) must still be payable.
    resetTables({
      profile: { contribution_method: 'payroll', contribution_type: 'salary_deduction', organization_id: 'org-1' },
      memberFees: [OTHER_FEE_ROW, ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');

    expect(o.fees).toHaveLength(1);
    expect(o.fees[0].id).toBe('mf-other');
    expect(o.total_due).toBe(5500);
  });
});
