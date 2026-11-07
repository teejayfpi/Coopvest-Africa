/**
 * Regression tests for the six findings in the wallet/guarantor security review.
 *
 * Each test pins the specific behaviour that was wrong, so a future edit that
 * reintroduces it fails here rather than in production.
 *
 *   1. A guarantee could be confirmed or declined on another member's behalf,
 *      because the acting guarantor was read from the request body.
 *   2. A wallet loan repayment larger than the outstanding balance was accepted
 *      and the excess was debited but never applied.
 *   3. A transfer debited the sender and credited the recipient as separate
 *      statements, with a read-then-write balance update.
 *   4. `flutter analyze` / `flutter test` could not fail the APK build.
 *   5. A release APK was published signed with a throwaway CI key.
 *   6. A referral bonus could be consumed twice by concurrent applications.
 *
 * The wallet and referral behaviour is delegated to Postgres functions, so the
 * route-level tests here assert the routes *call* them with the caller's own
 * identity, and the SQL is exercised directly against the live database (see
 * the verification notes in the migration).
 */

const fs = require('fs');
const path = require('path');
const request = require('supertest');
const express = require('express');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');

// ── fake supabase ───────────────────────────────────────────────────────────
// Records every rpc call and lets a test decide the outcome.
const mockRpcCalls = [];
let mockRpcResult = { data: null, error: null };

function mockMakeQuery(table) {
  const q = {
    table,
    filters: [],
    select: () => q,
    eq: (col, val) => { q.filters.push(['eq', col, val]); return q; },
    in: () => q,
    order: () => q,
    limit: () => q,
    maybeSingle: () => Promise.resolve({ data: null, error: null }),
    single: () => Promise.resolve({ data: null, error: null }),
    insert: () => q,
    update: () => q,
    then: (resolve) => resolve({ data: [], error: null, count: 0 }),
  };
  return q;
}

jest.mock('../src/config/supabase', () => ({
  from: (table) => mockMakeQuery(table),
  rpc: (fn, args) => {
    mockRpcCalls.push({ fn, args });
    return Promise.resolve(mockRpcResult);
  },
}));

jest.mock('../src/middleware/auth', () => ({
  authenticate: (req, _res, next) => {
    req.user = { id: 'caller-profile-id', role: 'member', email: 'caller@test.local' };
    next();
  },
}));

// The repayment route reads the loan from this middleware. Supplying it lets the
// test reach the wallet branch, which is where the overpayment bug lived.
jest.mock('../src/middleware/ownership', () => ({
  verifyLoanOwnership: (req, _res, next) => {
    req.loan = {
      id: '33333333-3333-3333-3333-333333333333',
      loan_id: 'LN-TEST-1',
      profile_id: 'caller-profile-id',
      status: 'active',
      remaining_balance: 50000,
    };
    next();
  },
}));

const loansRouter = require('../src/routes/loans');
const walletRouter = require('../src/routes/wallet');

const app = express();
app.use(express.json());
app.use('/api/v1/loans', loansRouter);
app.use('/api/v1/wallet', walletRouter);

beforeEach(() => {
  mockRpcCalls.length = 0;
  mockRpcResult = { data: null, error: null };
});

// ── Finding 1: guarantor consent / decline identity ─────────────────────────
describe('finding 1 — a guarantee can only be acted on by its own guarantor', () => {
  const VICTIM = 'victim-profile-id';

  test('consent naming a different guarantor is rejected with 403', async () => {
    const res = await request(app)
      .post('/api/v1/loans/11111111-1111-1111-1111-111111111111/guarantors/confirm')
      .send({ guarantor_id: VICTIM, guarantor_name: 'Victim' });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
    // The decisive point: no database work happened, so the forged consent was
    // never recorded.
    expect(mockRpcCalls).toHaveLength(0);
  });

  test('decline naming a different guarantor is rejected with 403', async () => {
    const res = await request(app)
      .post('/api/v1/loans/11111111-1111-1111-1111-111111111111/guarantors/decline')
      .send({ guarantor_id: VICTIM, reason: 'not me' });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });

  test('the routes no longer read the acting guarantor from the body', () => {
    const src = read('src/routes/loans.js');
    // The old code was `const { guarantor_id: guarantorId } = req.body;`.
    expect(src).not.toMatch(/guarantor_id:\s*guarantorId\s*\}\s*=\s*req\.body/);
    // The acting identity must come from the authenticated request.
    expect(src).toMatch(/const guarantorId = req\.user\.id/);
  });
});

// ── Finding 2: repayment cannot exceed the outstanding balance ──────────────
describe('finding 2 — a wallet repayment larger than the loan is refused', () => {
  test('the route passes the caller and loan to the atomic function', async () => {
    mockRpcResult = {
      data: { remaining_balance: 30000, repayment: { id: 'r1' }, wallet_balance: 1000 },
      error: null,
    };

    const res = await request(app)
      .post('/api/v1/loans/33333333-3333-3333-3333-333333333333/repay')
      .send({ amount: 20000, paymentMethod: 'wallet' });

    const call = mockRpcCalls.find((c) => c.fn === 'wallet_loan_repayment');
    expect(call).toBeDefined();
    expect(call.args.p_profile_id).toBe('caller-profile-id');
    expect(call.args.p_loan_id).toBe('33333333-3333-3333-3333-333333333333');
    expect(call.args.p_amount).toBe(20000);
    expect(res.status).toBe(201);
  });

  test('an overpayment rejection surfaces as a 400, not a silent success', async () => {
    mockRpcResult = {
      data: null,
      error: { message: 'Repayment of 60000.00 exceeds the outstanding loan balance of 50000.00' },
    };

    const res = await request(app)
      .post('/api/v1/loans/33333333-3333-3333-3333-333333333333/repay')
      .send({ amount: 60000, paymentMethod: 'wallet' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/exceeds the outstanding loan balance/);
  });

  test('the route no longer clamps the balance with Math.max(0, ...)', () => {
    const src = read('src/routes/loans.js');
    expect(src).not.toMatch(/Math\.max\(\s*0\s*,\s*remainingBefore\s*-\s*amount\s*\)/);
    expect(src).toMatch(/supabase\.rpc\(\s*'wallet_loan_repayment'/);
  });

  test('the SQL refuses an amount above the outstanding balance', () => {
    const sql = read('migrations/062_atomic_wallet_operations.sql');
    expect(sql).toMatch(/v_amount > v_remaining/);
    expect(sql).toMatch(/exceeds the outstanding loan balance/);
  });
});

// ── Finding 3: transfer is a single atomic function ─────────────────────────
describe('finding 3 — transfer runs as one function, not four statements', () => {
  test('the route calls wallet_transfer with the caller as the sender', async () => {
    mockRpcResult = {
      data: { sender_balance: 500, transaction: { id: 't1' }, reference: 'TRF-1' },
      error: null,
    };

    const res = await request(app)
      .post('/api/v1/wallet/transfer')
      .send({ toUserId: 'someone-else', amount: 100 });

    const call = mockRpcCalls.find((c) => c.fn === 'wallet_transfer');
    expect(call).toBeDefined();
    expect(call.args.p_from_profile_id).toBe('caller-profile-id');
    expect(res.status).toBe(201);
  });

  test('the route no longer debits and credits via adjustBalance', () => {
    const src = read('src/routes/wallet.js');
    const transferBody = src.slice(src.indexOf("router.post(\n  '/transfer'"), src.indexOf("router.get(\n  '/contributions'"));
    expect(transferBody).not.toMatch(/adjustBalance\(/);
    expect(src).toMatch(/supabase\.rpc\(\s*'wallet_transfer'/);
  });

  test('the SQL locks both wallets before reading either balance', () => {
    const sql = read('migrations/062_atomic_wallet_operations.sql');
    expect(sql).toMatch(/FOR UPDATE/);
    // Both rows locked in one ordered statement, so opposite-direction
    // transfers cannot deadlock.
    expect(sql).toMatch(/ORDER BY id\s+FOR UPDATE/);
  });

  test('the SQL rejects an overdraw instead of writing a negative balance', () => {
    const sql = read('migrations/062_atomic_wallet_operations.sql');
    expect(sql).toMatch(/Insufficient wallet balance/);
  });
});

// ── Finding 4: analyze and test gate the build ──────────────────────────────
describe('finding 4 — the APK workflow fails when analyze or tests fail', () => {
  const wf = read('../.github/workflows/build-apk.yml');

  test('flutter analyze is not suffixed with `|| true`', () => {
    const line = wf.split('\n').find((l) => l.includes('flutter analyze'));
    expect(line).toBeDefined();
    expect(line).not.toMatch(/\|\|\s*true/);
  });

  test('flutter test is not suffixed with `|| true`', () => {
    const line = wf.split('\n').find((l) => l.includes('flutter test'));
    expect(line).toBeDefined();
    expect(line).not.toMatch(/\|\|\s*true/);
  });
});

// ── Finding 5: no publishable APK from a throwaway key ──────────────────────
describe('finding 5 — a publishable release refuses a throwaway keystore', () => {
  const wf = read('../.github/workflows/build-apk.yml');

  test('the generated-key branch is limited to pull requests', () => {
    expect(wf).toMatch(/github\.event_name.*=.*"pull_request"/);
  });

  test('the publishable path exits non-zero when the secret is absent', () => {
    expect(wf).toMatch(/Refusing to build a publishable release APK/);
    expect(wf).toMatch(/exit 1/);
  });
});

// ── Finding 6: referral bonus is claimed atomically ─────────────────────────
describe('finding 6 — a referral bonus is claimed in one statement', () => {
  const src = read('src/services/referralService.js');

  test('the claim is conditional on the event being unconsumed', () => {
    // The guard that makes the claim atomic: only the caller whose UPDATE
    // matches a still-unconsumed row wins.
    expect(src).toMatch(/\.eq\(\s*'bonus_consumed',\s*false\s*\)/);
  });

  test('a lost claim does not apply the bonus', () => {
    expect(src).toMatch(/just applied to another loan/);
  });

  test('the consuming loan is recorded on the event', () => {
    expect(src).toMatch(/consumed_by_loan_id/);
  });

  test('the migration adds the consumed_by_loan_id column', () => {
    const sql = read('migrations/062_atomic_wallet_operations.sql');
    expect(sql).toMatch(/ADD COLUMN IF NOT EXISTS consumed_by_loan_id/);
  });

  test('the loan application claims the bonus before writing the loan', () => {
    const loans = read('src/routes/loans.js');
    const claimAt = loans.indexOf('referralService.applyBonusToLoan');
    const insertAt = loans.indexOf(".from('loans')\n        .insert(insertPayload)");
    expect(claimAt).toBeGreaterThan(-1);
    expect(insertAt).toBeGreaterThan(-1);
    // Claim first, so a lost claim cannot leave a loan carrying the discount.
    expect(claimAt).toBeLessThan(insertAt);
  });

  test('a failed loan insert releases the claim', () => {
    const loans = read('src/routes/loans.js');
    expect(loans).toMatch(/releaseBonusClaim\(loanUuid\)/);
  });
});

// ── The same class of defect in the savings routes ─────────────────────────
describe('savings movements use the atomic function too', () => {
  test('deposit and withdraw both call savings_move with the caller', () => {
    const src = read('src/routes/savings.js');
    const calls = src.match(/supabase\.rpc\(\s*'savings_move'/g) || [];
    expect(calls).toHaveLength(2);
    expect(src).toMatch(/p_profile_id: req\.user\.id/);
  });

  test('the read-then-write helpers are gone from savings.js', () => {
    const src = read('src/routes/savings.js');
    expect(src).not.toMatch(/adjustSavings\(/);
    expect(src).not.toMatch(/adjustBalance\(/);
    // The old code computed the new balance in JavaScript before writing it.
    expect(src).not.toMatch(/Number\(row\.balance\)\s*\+\s*Number\(delta\)/);
  });

  test('the SQL locks both rows before reading either balance', () => {
    const sql = read('migrations/062_atomic_wallet_operations.sql');
    const fn = sql.slice(sql.indexOf('FUNCTION public.savings_move'));
    expect(fn).toMatch(/FOR UPDATE/);
    expect(fn).toMatch(/Insufficient savings balance/);
    expect(fn).toMatch(/Insufficient wallet balance/);
  });

  test('the ledger row uses the values the constraints allow', () => {
    // `transactions.category` only permits 'credit' and 'debit'; the savings
    // kind belongs in `type`. The old code wrote category='savings_deposit',
    // so the insert always violated the check constraint and threw — after the
    // wallet and savings balances had already been moved.
    const sql = read('migrations/062_atomic_wallet_operations.sql');
    const fn = sql.slice(sql.indexOf('FUNCTION public.savings_move'));
    expect(fn).toMatch(/THEN 'savings_deposit' ELSE 'savings_withdrawal' END/);
    expect(fn).toMatch(/THEN 'debit' ELSE 'credit' END/);
    expect(fn).not.toMatch(/'savings_deposit',\s*\n\s*'debit'/);
  });
});

// ── The same class of defect in the admin deposit-verify path ──────────────
describe('admin deposit verification is atomic', () => {
  const admin = read('src/routes/admin.js');
  const sql = read('migrations/062_atomic_wallet_operations.sql');

  test('both verify paths call the function instead of crediting directly', () => {
    const calls = admin.match(/supabase\.rpc\(\s*'verify_deposit_request'/g) || [];
    expect(calls).toHaveLength(2);
  });

  test('the read-then-write credit is gone from admin.js', () => {
    expect(admin).not.toMatch(/Number\(wallet\.balance\)\s*\+\s*amount/);
  });

  test('the function locks the request before checking its status', () => {
    const fn = sql.slice(sql.indexOf('FUNCTION public.verify_deposit_request'));
    const lockAt = fn.indexOf('FOR UPDATE');
    const checkAt = fn.indexOf("v_deposit.status <> 'pending'");
    expect(lockAt).toBeGreaterThan(-1);
    expect(checkAt).toBeGreaterThan(-1);
    // The lock must come first, or two concurrent callers both see 'pending'.
    expect(lockAt).toBeLessThan(checkAt);
  });

  test('the function does not erase existing admin notes', () => {
    const fn = sql.slice(sql.indexOf('FUNCTION public.verify_deposit_request'));
    expect(fn).toMatch(/COALESCE\(p_notes, admin_notes\)/);
  });
});

// ── The functions must not be callable by a signed-in member ────────────────
describe('the wallet functions are not exposed to anon or authenticated', () => {
  const sql = read('migrations/062_atomic_wallet_operations.sql');

  test.each([
    'wallet_transfer',
    'wallet_loan_repayment',
    'savings_move',
    'verify_deposit_request',
  ])('%s is revoked from PUBLIC, anon and authenticated', (fn) => {
    expect(sql).toMatch(new RegExp(`REVOKE ALL ON FUNCTION public\\.${fn}[^;]*FROM PUBLIC, anon, authenticated`, 's'));
  });

  test('execute is granted only to service_role', () => {
    expect(sql).toMatch(/GRANT EXECUTE ON FUNCTION public\.wallet_transfer[^;]*TO service_role/);
    expect(sql).toMatch(/GRANT EXECUTE ON FUNCTION public\.wallet_loan_repayment[^;]*TO service_role/);
    expect(sql).toMatch(/GRANT EXECUTE ON FUNCTION public\.savings_move[^;]*TO service_role/);
    expect(sql).toMatch(/GRANT EXECUTE ON FUNCTION public\.verify_deposit_request[^;]*TO service_role/);
  });
});
