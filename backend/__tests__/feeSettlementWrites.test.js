/**
 * Fee settlement must actually reach the database.
 *
 * A member paid the NGN1,500 administrative fee twice and the card still showed
 * it due. The cause was not the pricing: every settlement write included
 * `member_fees.deposit_id`, whose foreign key points at `deposit_requests`, while
 * the value passed was a `payment_proofs` id. The write therefore failed with
 * 23503 on every attempt, and no call site read `{ error }`, so the code logged
 * "settled" over a write that never happened.
 *
 * Two settlement paths are exercised, because different proofs reach each and
 * both carried the defect:
 *   - no `target_month`  -> the fee leg of `applyAllocations`
 *   - `target_month` set -> `applyTargetMonth`, which owns that month's fee and
 *     makes `applyAllocations` skip it
 */

const state = {
  feeType: { id: 'fee-admin' },
  existingRow: null,
  updated: [],
  inserted: [],
  updateError: null,
  insertError: null,
};

jest.mock('../src/config/supabase', () => {
  const query = (table) => {
    const q = {
      select: () => q,
      eq: () => q,
      in: () => q,
      is: () => q,
      order: () => q,
      limit: () => q,
      maybeSingle: () => {
        if (table === 'fee_types') return Promise.resolve({ data: state.feeType, error: null });
        return Promise.resolve({ data: state.existingRow, error: null });
      },
      update: (patch) => {
        state.updated.push({ table, patch });
        const done = Promise.resolve({ error: state.updateError });
        return { eq: () => done, then: (res) => done.then(res) };
      },
      insert: (row) => {
        state.inserted.push({ table, row });
        return Promise.resolve({ error: state.insertError });
      },
      then: (res) => Promise.resolve({ data: [], error: null }).then(res),
    };
    return q;
  };
  return { from: query };
});

jest.mock('../src/services/notifyService', () => ({
  notifyPaymentProofApproved: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../src/lib/failedChargeAudit', () => ({
  recordFailedCharge: jest.fn(),
  alertFailedCharge: jest.fn(),
}));
jest.mock('../src/lib/paystackCharge', () => ({
  paystackFetch: jest.fn(),
  secretKey: () => 'sk_test',
  classifyFailure: () => 'unknown',
}));

const { applyAllocations, applyTargetMonth } = require('../src/routes/payments');

const proof = (overrides = {}) => ({
  id: 'proof-1',
  profile_id: 'profile-1',
  amount: 1500,
  payment_type: 'other',
  status: 'approved',
  metadata: {
    allocation_type: 'fee',
    allocations: [{ type: 'fee', amount: 1500 }],
  },
  ...overrides,
});

const advanceProof = () =>
  proof({
    metadata: {
      allocation_type: 'fee',
      allocations: [{ type: 'fee', amount: 1500 }],
      target_month: '2026-11',
    },
  });

const feeWrites = () =>
  [...state.updated, ...state.inserted].filter((w) => w.table === 'member_fees');

beforeEach(() => {
  state.feeType = { id: 'fee-admin' };
  state.existingRow = null;
  state.updated = [];
  state.inserted = [];
  state.updateError = null;
  state.insertError = null;
});

describe('fee settlement writes', () => {
  test('never writes the deposit_id foreign key (in-month path)', async () => {
    state.existingRow = { id: 'fee-row-1', status: 'outstanding' };

    await applyAllocations(proof());

    expect(feeWrites().length).toBeGreaterThan(0);
    for (const write of feeWrites()) {
      expect(write.patch || write.row).not.toHaveProperty('deposit_id');
    }
  });

  test('never writes the deposit_id foreign key (advance path)', async () => {
    await applyTargetMonth(advanceProof());

    expect(feeWrites().length).toBeGreaterThan(0);
    for (const write of feeWrites()) {
      expect(write.patch || write.row).not.toHaveProperty('deposit_id');
    }
  });

  test('marks an existing outstanding row paid', async () => {
    state.existingRow = { id: 'fee-row-1', status: 'outstanding' };

    await applyAllocations(proof());

    const settle = state.updated.find(
      (w) => w.table === 'member_fees' && w.patch.status === 'paid',
    );
    expect(settle).toBeDefined();
    expect(settle.patch.paid_at).toBeTruthy();
  });

  test('creates a paid row when the fee was never billed (in-month path)', async () => {
    state.existingRow = null;

    await applyAllocations(proof());

    const created = state.inserted.find(
      (w) => w.table === 'member_fees' && w.row.status === 'paid',
    );
    expect(created).toBeDefined();
    expect(created.row.amount).toBe(1500);
    expect(created.row.fee_type).toBe('fee');
  });

  test('records the advance month as paid', async () => {
    state.existingRow = null;

    await applyTargetMonth(advanceProof());

    const created = state.inserted.find(
      (w) => w.table === 'member_fees' && w.row.status === 'paid',
    );
    expect(created).toBeDefined();
    expect(created.row.billing_month).toBe('2026-11');
    // A row created for collected money must never read as outstanding, or the
    // member is asked to pay the same month again.
    expect(created.row.status).not.toBe('outstanding');
  });

  test('survives a rejected insert without throwing', async () => {
    state.existingRow = null;
    state.insertError = { code: '23503', message: 'violates foreign key constraint' };

    // Settlement is best-effort so an approved proof is never rolled back, but
    // the failure must be logged rather than reported as success.
    await expect(applyTargetMonth(advanceProof())).resolves.toBeUndefined();

    expect(state.inserted.some((w) => w.table === 'member_fees')).toBe(true);
  });
});
