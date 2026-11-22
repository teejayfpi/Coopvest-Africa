/**
 * Disbursement endpoint and migration 070.
 *
 * The behaviour these guard is the one that unblocked the loan lifecycle:
 * before this, approval left a loan at 'approved', repayment only accepts
 * 'active'/'repaying'/'overdue', and the recovery worker only scans those. So
 * an approved loan could not be repaid and its guarantors were never warned.
 */

const fs = require('fs');
const path = require('path');

jest.mock('../src/config/supabase', () => {
  const state = { loan: null, rpcError: null, rpcResult: null, rpcCalls: [], updates: [] };
  const api = {
    __state: state,
    from(table) {
      const chain = {
        select: () => chain,
        eq: () => chain,
        maybeSingle: async () => {
          if (table === 'loans') return { data: state.loan, error: null };
          return { data: null, error: null };
        },
        insert: async () => ({ data: null, error: null }),
        update: (row) => {
          state.updates.push({ table, row });
          return { eq: () => ({ select: () => ({ maybeSingle: async () => ({ data: null, error: null }) }) }) };
        },
      };
      return chain;
    },
    async rpc(name, params) {
      state.rpcCalls.push({ name, params });
      return { data: state.rpcResult, error: state.rpcError };
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
const guarantorNotifications = require('../src/lib/guarantorNotifications');

const APPROVED = {
  id: 'loan-1',
  loan_id: 'LN-1',
  profile_id: 'borrower-1',
  amount: 250000,
  status: 'approved',
};

/** Drive the handler the way Express would, and return the recorded response. */
function callDisburse(loan) {
  supabase.__state.loan = loan;
  supabase.__state.rpcCalls = [];

  const router = require('../src/routes/adminApi');
  const layer = router.stack.find(
    (l) => l.route && l.route.path === '/loans/:id/disburse' && l.route.methods.post,
  );
  const handler = layer.route.stack[layer.route.stack.length - 1].handle;

  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  return handler({ params: { id: loan?.id ?? 'loan-1' }, body: {}, user: { id: 'admin-1' } }, res)
    .then(() => res);
}

beforeEach(() => {
  jest.clearAllMocks();
  supabase.__state.updates = [];
  supabase.__state.rpcError = null;
  supabase.__state.rpcResult = null;
});

describe('POST /loans/:id/disburse', () => {
  test('an approved loan is disbursed', async () => {
    supabase.__state.rpcResult = { ...APPROVED, status: 'active' };
    const res = await callDisburse(APPROVED);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(supabase.__state.rpcCalls).toHaveLength(1);
    expect(supabase.__state.rpcCalls[0].name).toBe('loan_disburse');
  });

  test('the admin who disbursed is recorded, not an anonymous caller', async () => {
    supabase.__state.rpcResult = { ...APPROVED, status: 'active' };
    await callDisburse(APPROVED);
    expect(supabase.__state.rpcCalls[0].params.p_admin_id).toBe('admin-1');
  });

  test('a loan that is not approved is refused before any money moves', async () => {
    for (const status of ['pending', 'under_review', 'rejected', 'active', 'completed']) {
      const res = await callDisburse({ ...APPROVED, status });
      expect(res.statusCode).toBe(409);
      expect(res.body.code).toBe('NOT_DISBURSABLE');
      // The decisive assertion: no RPC ran, so the wallet is untouched.
      expect(supabase.__state.rpcCalls).toHaveLength(0);
    }
  });

  test('a second click does not credit the principal twice', async () => {
    // First call succeeds and the loan becomes 'active'; the RPC's own guard
    // would also refuse, but the endpoint must not even reach it.
    supabase.__state.rpcResult = { ...APPROVED, status: 'active' };
    const first = await callDisburse(APPROVED);
    expect(first.statusCode).toBe(200);

    const second = await callDisburse({ ...APPROVED, status: 'active' });
    expect(second.statusCode).toBe(409);
    expect(supabase.__state.rpcCalls).toHaveLength(0);
  });

  test('the RPC refusing a non-approved loan is surfaced as 409, not 500', async () => {
    supabase.__state.rpcError = {
      code: '22023',
      message: 'Only an approved loan can be disbursed. Current status: active',
    };
    const res = await callDisburse(APPROVED);
    expect(res.statusCode).toBe(409);
    expect(res.body.code).toBe('NOT_DISBURSABLE');
  });

  test('a missing migration is a clear 503, not a silent success', async () => {
    supabase.__state.rpcError = {
      code: '42883',
      message: 'function public.loan_disburse(uuid, uuid) does not exist',
    };
    const res = await callDisburse(APPROVED);
    expect(res.statusCode).toBe(503);
    expect(res.body.code).toBe('MIGRATION_REQUIRED');
    // Nothing may be reported as paid out when the function was never applied.
    expect(res.body.success).toBeFalsy();
  });

  test('a missing loan is a 404', async () => {
    const res = await callDisburse(null);
    expect(res.statusCode).toBe(404);
    expect(supabase.__state.rpcCalls).toHaveLength(0);
  });

  test('the borrower is told on in-app and push', async () => {
    supabase.__state.rpcResult = { ...APPROVED, status: 'active' };
    await callDisburse(APPROVED);
    const call = notifyService.broadcast.mock.calls[0][0];
    expect(call.profileIds).toEqual(['borrower-1']);
    expect(call.channels).toEqual(expect.arrayContaining(['in_app', 'push']));
    expect(call.body).toMatch(/250,000/);
  });

  test('guarantors are told the liability has started', async () => {
    supabase.__state.rpcResult = { ...APPROVED, status: 'active' };
    await callDisburse(APPROVED);
    expect(guarantorNotifications.notifyGuarantorsOfDecision).toHaveBeenCalled();
  });

  test('a notification failure does not undo the disbursement', async () => {
    supabase.__state.rpcResult = { ...APPROVED, status: 'active' };
    notifyService.broadcast.mockRejectedValueOnce(new Error('push down'));
    const res = await callDisburse(APPROVED);
    // The money has already moved; reporting failure would invite a retry.
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

describe('migration 070', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../migrations/070_loan_disbursement.sql'), 'utf8',
  );

  test('only an approved loan qualifies', () => {
    expect(sql).toMatch(/v_loan\.status\s*<>\s*'approved'/);
  });

  test('the loan row is locked before the wallet', () => {
    const loanLock = sql.indexOf('FROM public.loans WHERE id = p_loan_id FOR UPDATE');
    const walletLock = sql.indexOf('WHERE profile_id = v_loan.profile_id FOR UPDATE');
    expect(loanLock).toBeGreaterThan(-1);
    expect(walletLock).toBeGreaterThan(loanLock);
  });

  test('the disbursement is written to the ledger', () => {
    expect(sql).toMatch(/INSERT INTO public\.transactions/);
    expect(sql).toMatch(/'loan_disbursement'/);
  });

  test('the loan ends up in a status the rest of the system acts on', () => {
    // 'disbursed' is permitted by the constraint but read by nobody; the
    // repayment path and recovery worker both key on 'active'.
    expect(sql).toMatch(/status\s*=\s*'active'/);
  });

  test('the disbursing admin is recorded', () => {
    expect(sql).toMatch(/disbursed_by\s*=\s*p_admin_id/);
  });

  test('the wallet balance is credited by the principal', () => {
    expect(sql).toMatch(/v_wallet_before\s*\+\s*v_amount/);
  });
});
