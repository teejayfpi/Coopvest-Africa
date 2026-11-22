/**
 * Admin loan penalty and restructure.
 *
 * Penalty existed only as a dashboard toast that said "Penalty of ₦X added" and
 * made no request. Restructure was real but forced `status = 'active'` on every
 * loan and left `total_repayment` stale when the plan changed.
 */

const supabaseState = {
  loan: null,
  feeType: null,
  inserted: [],
  updated: null,
};

jest.mock('../src/config/supabase', () => {
  const api = {
    __state: supabaseState,
    from(table) {
      const chain = {
        select: () => chain,
        eq: () => chain,
        order: () => chain,
        limit: () => chain,
        maybeSingle: async () => {
          if (table === 'loans') return { data: supabaseState.loan, error: null };
          if (table === 'fee_types') return { data: supabaseState.feeType, error: null };
          return { data: null, error: null };
        },
        insert: (row) => {
          supabaseState.inserted.push({ table, row });
          return { select: () => ({ maybeSingle: async () => ({ data: { id: 'fee-1', ...row }, error: null }) }) };
        },
        update: (row) => {
          supabaseState.updated = { table, row };
          return { eq: () => ({ select: () => ({ maybeSingle: async () => ({ data: { id: 'loan-1', ...row }, error: null }) }) }) };
        },
      };
      return chain;
    },
    async rpc() {
      return { data: null, error: null };
    },
  };
  return api;
});

jest.mock('../src/services/notifyService', () => ({
  sendInApp: jest.fn().mockResolvedValue({}),
  broadcast: jest.fn().mockResolvedValue([]),
  sendEmail: jest.fn().mockResolvedValue({}),
  pushToProfile: jest.fn().mockResolvedValue({}),
}));

jest.mock('../src/lib/guarantorNotifications', () => ({
  notifyGuarantorsOfDecision: jest.fn().mockResolvedValue(0),
  notifyGuarantorsOfRecovery: jest.fn().mockResolvedValue(0),
  boundGuarantorIds: jest.fn().mockResolvedValue([]),
}));

const supabase = require('../src/config/supabase');
const notifyService = require('../src/services/notifyService');
const router = require('../src/routes/adminApi');

const LOAN = {
  id: 'loan-1',
  loan_id: 'LN-1',
  profile_id: 'borrower-1',
  amount: 250000,
  tenure_months: 4,
  monthly_repayment: 65000,
  total_repayment: 260000,
  status: 'overdue',
};

function call(pathSuffix, body = {}) {
  const layer = router.stack.find(
    (l) => l.route && l.route.path === `/loans/:id/${pathSuffix}` && l.route.methods.post,
  );
  const handler = layer.route.stack[layer.route.stack.length - 1].handle;
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(p) { this.body = p; return this; },
  };
  return handler({ params: { id: LOAN.id }, body, user: { id: 'admin-1' } }, res)
    .then(() => res);
}

beforeEach(() => {
  jest.clearAllMocks();
  supabase.__state.loan = { ...LOAN };
  supabase.__state.feeType = { id: 'ft-1', name: 'Late Loan Repayment Fine', amount: 3000 };
  supabase.__state.inserted = [];
  supabase.__state.updated = null;
});

describe('POST /loans/:id/penalty', () => {
  test('writes a real obligation row, not just a message', async () => {
    const res = await call('penalty', { amount: 3000 });
    expect(res.statusCode).toBe(201);
    const fee = supabase.__state.inserted.find((x) => x.table === 'member_fees');
    expect(fee).toBeDefined();
    expect(fee.row.amount).toBe(3000);
    expect(fee.row.status).toBe('outstanding');
    expect(fee.row.fee_type).toBe('fine');
  });

  test('links the penalty to the loan and the borrower', async () => {
    await call('penalty', { amount: 3000 });
    const fee = supabase.__state.inserted.find((x) => x.table === 'member_fees');
    expect(fee.row.loan_id).toBe('loan-1');
    expect(fee.row.profile_id).toBe('borrower-1');
  });

  test('falls back to the configured fine amount', async () => {
    const res = await call('penalty', {});
    expect(res.body.amount).toBe(3000);
  });

  test('the member is told, on push as well as in-app', async () => {
    await call('penalty', { amount: 3000 });
    const n = notifyService.broadcast.mock.calls[0][0];
    expect(n.profileIds).toEqual(['borrower-1']);
    expect(n.channels).toEqual(expect.arrayContaining(['in_app', 'push']));
    expect(n.body).toMatch(/3,000/);
  });

  test('a loan that cannot be in arrears is refused', async () => {
    for (const status of ['pending', 'approved', 'completed', 'rejected', 'cancelled']) {
      supabase.__state.loan = { ...LOAN, status };
      const res = await call('penalty', { amount: 3000 });
      expect(res.statusCode).toBe(409);
      expect(res.body.code).toBe('NOT_PENALISABLE');
    }
    expect(supabase.__state.inserted.filter((x) => x.table === 'member_fees')).toHaveLength(0);
  });

  test('no amount anywhere is a 400, not a zero-naira fine', async () => {
    supabase.__state.feeType = null;
    const res = await call('penalty', {});
    expect(res.statusCode).toBe(400);
  });

  test('a notification failure does not undo the charge', async () => {
    notifyService.broadcast.mockRejectedValueOnce(new Error('push down'));
    const res = await call('penalty', { amount: 3000 });
    expect(res.statusCode).toBe(201);
  });
});

describe('POST /loans/:id/restructure', () => {
  test('a restructure does not resurrect a closed loan', async () => {
    // It used to set status = 'active' unconditionally.
    for (const status of ['rejected', 'completed', 'cancelled', 'pending']) {
      supabase.__state.loan = { ...LOAN, status };
      const res = await call('restructure', { newTenureMonths: 6, reason: 'x' });
      expect(res.statusCode).toBe(409);
      expect(res.body.code).toBe('NOT_RESTRUCTURABLE');
    }
    expect(supabase.__state.updated).toBeNull();
  });

  test('a live loan keeps its status rather than being forced to active', async () => {
    supabase.__state.loan = { ...LOAN, status: 'overdue' };
    await call('restructure', { newTenureMonths: 6, reason: 'x' });
    expect(supabase.__state.updated.row.status).toBeUndefined();
  });

  test('total_repayment follows the new instalment count', async () => {
    // Stale totals would disagree with the schedule, and next_due_date derives
    // from it.
    await call('restructure', { newTenureMonths: 6, reason: 'x' });
    expect(supabase.__state.updated.row.tenure_months).toBe(6);
    expect(supabase.__state.updated.row.total_repayment).toBe(6 * 65000);
  });

  test('a missing loan is a 404', async () => {
    supabase.__state.loan = null;
    const res = await call('restructure', { newTenureMonths: 6, reason: 'x' });
    expect(res.statusCode).toBe(404);
  });
});
