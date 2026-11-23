/**
 * The monthly administrative fee worker, exercised through `processDue` rather
 * than only its pure decision helper.
 *
 * The risk this guards is not "does it bill once" but "does it bill once when
 * it runs twice". The worker ticks daily, restarts with the server, and can
 * overlap on a slow pass. If a second pass inserted a second NGN1,500 row the
 * member's amount due would silently double, so the unique violation (23505)
 * from migration 076 has to be treated as success, not as an error to retry.
 */

const state = {
  feeTypes: [{ id: 'fee-admin', amount: 1500 }],
  profiles: [],
  inserted: [],
  insertBehaviour: null, // (row) => ({ error }) | null
};

jest.mock('../src/config/supabase', () => ({
  from: (table) => {
    const query = {
      select: () => query,
      eq: () => query,
      in: () => query,
      order: () => query,
      limit: () => query,
      maybeSingle: () => Promise.resolve({ data: state.feeTypes[0] ?? null, error: null }),
      insert: (row) => {
        const override = state.insertBehaviour && state.insertBehaviour(row, state.inserted);
        if (override && override.error) return Promise.resolve({ error: override.error });
        state.inserted.push(row);
        return Promise.resolve({ error: null });
      },
      then: (resolve) => resolve({ data: table === 'profiles' ? state.profiles : [], error: null }),
    };
    return query;
  },
}));

const { processDue } = require('../src/workers/monthlyAdministrativeFeeWorker');

const member = (over = {}) => ({
  id: 'p1',
  created_at: '2026-01-10T00:00:00Z',
  contribution_method: 'manual',
  is_active: true,
  is_flagged: false,
  ...over,
});

beforeEach(() => {
  state.profiles = [member()];
  state.inserted = [];
  state.insertBehaviour = null;
});

describe('processDue', () => {
  const now = new Date(2026, 10, 20); // 2026-11

  test('bills an active member for the current month', async () => {
    const res = await processDue({ now });
    expect(res.month).toBe('2026-11');
    expect(state.inserted).toHaveLength(1);
    expect(state.inserted[0]).toMatchObject({
      profile_id: 'p1',
      fee_type: 'fee',
      amount: 1500,
      status: 'outstanding',
      billing_month: '2026-11',
    });
  });

  test('a second run does not create a second charge', async () => {
    await processDue({ now });
    // Simulate the database rejecting the duplicate month for this member.
    state.insertBehaviour = (row, already) =>
      already.some((r) => r.profile_id === row.profile_id && r.billing_month === row.billing_month)
        ? { error: { code: '23505', message: 'duplicate key value violates unique constraint' } }
        : null;

    const res = await processDue({ now });
    expect(res.tally.already_billed).toBe(1);
    expect(res.tally.billed).toBeUndefined();
    expect(state.inserted).toHaveLength(1); // still one row, not two
  });

  test('the duplicate is not counted as a failure', async () => {
    state.insertBehaviour = () => ({ error: { code: '23505', message: 'duplicate' } });
    const res = await processDue({ now });
    expect(res.tally.already_billed).toBe(1);
    expect(res.tally.failed).toBeUndefined();
  });

  test('a genuine insert error is reported, not swallowed', async () => {
    state.insertBehaviour = () => ({ error: { code: '08006', message: 'connection failure' } });
    const res = await processDue({ now });
    expect(res.tally.failed).toBe(1);
    expect(state.inserted).toHaveLength(0);
  });

  test('a payroll member with an employer is skipped: salary covers the fee', async () => {
    state.profiles = [member({ contribution_method: 'payroll', organization_id: 'org-1' })];
    const res = await processDue({ now });
    expect(state.inserted).toHaveLength(0);
    expect(res.tally.skipped).toBe(1);
  });

  test('a direct-deposit member is billed', async () => {
    state.profiles = [member({ contribution_method: 'manual' })];
    const res = await processDue({ now });
    expect(state.inserted).toHaveLength(1);
    expect(res.tally.billed).toBe(1);
  });

  test('a missing catalogue row stops the run instead of billing a wrong amount', async () => {
    state.feeTypes = [];
    const res = await processDue({ now });
    expect(res.error).toBe('fee type missing');
    expect(state.inserted).toHaveLength(0);
    state.feeTypes = [{ id: 'fee-admin', amount: 1500 }];
  });
});
