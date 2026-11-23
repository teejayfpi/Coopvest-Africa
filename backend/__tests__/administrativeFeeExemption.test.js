/**
 * The monthly administrative fee is payable by every member, including those on
 * salary deduction.
 *
 * It used to be hidden for salary-deduction members on the premise that payroll
 * recovers it. No payroll path can: `payroll_batch_lines` records only
 * `contribution_amount` and `registration_fee_amount`, and `organizationFinance`
 * totals only those two. Hiding the row therefore hid the charge from the only
 * channel that could collect it, and every enrolled member's fee went uncollected.
 *
 * These tests drive the real `computeObligations` against a stubbed Supabase, so
 * the rule is pinned at the point the app actually reads it. The
 * `administrative_fee_exempt` flag survives as an explanation ("this may also be
 * deducted from your salary"), not as a suppression.
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

describe('the administrative fee is payable by salary-deduction members too', () => {
  test('a payroll member with a linked employer is billed the fee', async () => {
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

    expect(o.fees).toHaveLength(1);
    expect(o.fees[0].amount).toBe(1500);
    // Savings ₦5,000 + fee ₦1,500. The employer cannot deduct this, so it is
    // owed in the app like any other member's.
    expect(o.total_due).toBe(6500);
  });

  test('the KYC spelling salary_deduction is billed the same way', async () => {
    resetTables({
      profile: {
        contribution_method: null,
        contribution_type: 'salary_deduction',
        organization_id: 'org-1',
      },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');
    expect(o.fees).toHaveLength(1);
    expect(o.total_due).toBe(6500);
  });

  test('a pending employer enrolment is still billed the fee', async () => {
    // A pending enrolment is an intention, not a deduction. Billing it on the
    // strength of an unverified claim is how the fee went uncollected.
    resetTables({
      profile: {
        contribution_method: 'payroll',
        contribution_type: 'salary_deduction',
        organization_id: null,
        pending_organization_name: 'Lagos State Ministry of Finance',
        pending_organization_requested_at: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
      },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');
    expect(o.fees).toHaveLength(1);
    expect(o.total_due).toBe(6500);
  });

  test('the fee returns once a self-declared employer window lapses', async () => {
    // A member who names an employer that is never enrolled must not hide the
    // monthly administrative fee forever.
    resetTables({
      profile: {
        contribution_method: 'payroll',
        contribution_type: 'salary_deduction',
        organization_id: null,
        pending_organization_name: 'Never Enrolled Ltd',
        pending_organization_requested_at: new Date(Date.now() - 200 * 24 * 60 * 60 * 1000).toISOString(),
      },
      memberFees: [ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');
    expect(o.fees).toHaveLength(1);
    expect(o.total_due).toBe(6500);
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

  test('a fine stays payable alongside the fee for a payroll member', async () => {
    resetTables({
      profile: { contribution_method: 'payroll', contribution_type: 'salary_deduction', organization_id: 'org-1' },
      memberFees: [FINE_ROW, ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');

    expect(o.fines).toHaveLength(1);
    expect(o.fines[0].amount).toBe(3000);
    expect(o.fees).toHaveLength(1);
    // ₦5,000 savings + ₦3,000 fine + ₦1,500 fee.
    expect(o.total_due).toBe(9500);
  });

  test('every fee row is payable for a payroll member', async () => {
    resetTables({
      profile: { contribution_method: 'payroll', contribution_type: 'salary_deduction', organization_id: 'org-1' },
      memberFees: [OTHER_FEE_ROW, ADMIN_FEE_ROW],
    });

    const o = await computeObligations('p1');

    expect(o.fees).toHaveLength(2);
    expect(o.total_due).toBe(7000);
  });
});
