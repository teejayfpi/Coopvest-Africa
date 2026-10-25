/**
 * Money-integrity checks. These are the rules that decide whether the money
 * tables agree, so the tests pin the arithmetic and, importantly, the
 * exclusions that prevent false positives (a pending charge has not moved
 * money; a debit subtracts).
 *
 * The checks are exercised against a small in-memory Supabase-like fake rather
 * than a live database, because the logic under test is the comparison, not the
 * query.
 */

const {
  runIntegrityChecks,
  walletBalanceVsLedger,
  duplicateCompletedReferences,
  loanOutstandingMirrorMismatch,
  stalePendingTransactions,
  negativeWalletBalance,
} = require('../src/lib/moneyIntegrity');

/**
 * Minimal fake: `.from(table).select(cols).<filters>` returns the matching rows.
 * Supports only the filters the checks use.
 */
function fakeDb(tables) {
  return {
    from(table) {
      let rows = (tables[table] || []).slice();
      const api = {
        select() { return api; },
        eq(col, val) { rows = rows.filter((r) => r[col] === val); return api; },
        neq(col, val) { rows = rows.filter((r) => r[col] !== val); return api; },
        lt(col, val) { rows = rows.filter((r) => r[col] < val); return api; },
        gte(col, val) { rows = rows.filter((r) => r[col] >= val); return api; },
        lte(col, val) { rows = rows.filter((r) => r[col] <= val); return api; },
        not(col, op, val) { if (op === 'is' && val === null) rows = rows.filter((r) => r[col] != null); return api; },
        in(col, vals) { rows = rows.filter((r) => vals.includes(r[col])); return api; },
        order() { return api; },
        limit(n) { rows = rows.slice(0, n); return api; },
        then(resolve) { return Promise.resolve({ data: rows, error: null }).then(resolve); },
      };
      return api;
    },
  };
}

describe('walletBalanceVsLedger', () => {
  test('passes when the wallet equals the net of completed entries', async () => {
    const db = fakeDb({
      wallets: [{ id: 'w1', profile_id: 'p1', balance: 500, currency: 'NGN' }],
      transactions: [
        { profile_id: 'p1', amount: 1000, category: 'credit', status: 'completed' },
        { profile_id: 'p1', amount: 500, category: 'debit', status: 'completed' },
      ],
    });
    const result = await walletBalanceVsLedger(db, { sampleLimit: 10 });
    expect(result.count).toBe(0);
  });

  test('ignores pending transactions — they have not moved money yet', async () => {
    const db = fakeDb({
      wallets: [{ id: 'w1', profile_id: 'p1', balance: 1000, currency: 'NGN' }],
      transactions: [
        { profile_id: 'p1', amount: 1000, category: 'credit', status: 'completed' },
        // A pending credit must NOT be counted, or this is a false positive.
        { profile_id: 'p1', amount: 5000, category: 'credit', status: 'pending' },
      ],
    });
    const result = await walletBalanceVsLedger(db, { sampleLimit: 10 });
    expect(result.count).toBe(0);
  });

  test('reports the difference when the stored balance is wrong', async () => {
    const db = fakeDb({
      wallets: [{ id: 'w1', profile_id: 'p1', balance: 1500, currency: 'NGN' }],
      transactions: [{ profile_id: 'p1', amount: 1000, category: 'credit', status: 'completed' }],
    });
    const result = await walletBalanceVsLedger(db, { sampleLimit: 10 });
    expect(result.count).toBe(1);
    expect(result.samples[0]).toMatchObject({
      walletId: 'w1',
      storedBalance: 1500,
      ledgerBalance: 1000,
      difference: 500,
    });
  });
});

describe('duplicateCompletedReferences', () => {
  test('flags two completed rows sharing a reference', async () => {
    const now = new Date().toISOString();
    const db = fakeDb({
      transactions: [
        { reference: 'REF-1', profile_id: 'p1', amount: 100, status: 'completed', created_at: now },
        { reference: 'REF-1', profile_id: 'p1', amount: 100, status: 'completed', created_at: now },
        { reference: 'REF-2', profile_id: 'p2', amount: 50, status: 'completed', created_at: now },
      ],
    });
    const result = await duplicateCompletedReferences(db, { sampleLimit: 10 });
    expect(result.count).toBe(1);
    expect(result.samples[0]).toMatchObject({ reference: 'REF-1', occurrences: 2, totalAmount: 200 });
  });

  test('does not flag a reference that appears once', async () => {
    const now = new Date().toISOString();
    const db = fakeDb({
      transactions: [{ reference: 'REF-1', profile_id: 'p1', amount: 100, status: 'completed', created_at: now }],
    });
    const result = await duplicateCompletedReferences(db, { sampleLimit: 10 });
    expect(result.count).toBe(0);
  });
});

describe('loanOutstandingMirrorMismatch', () => {
  test('flags a loan whose mirror drifted from remaining_balance', async () => {
    const db = fakeDb({
      loans: [
        { id: 'l1', profile_id: 'p1', remaining_balance: 800, outstanding_balance: 1000, amount: 1000, status: 'active' },
        { id: 'l2', profile_id: 'p2', remaining_balance: 400, outstanding_balance: 400, amount: 500, status: 'active' },
      ],
    });
    const result = await loanOutstandingMirrorMismatch(db, { sampleLimit: 10 });
    expect(result.count).toBe(1);
    expect(result.samples[0]).toMatchObject({ loanId: 'l1', remainingBalance: 800, outstandingBalance: 1000 });
  });
});

describe('stalePendingTransactions', () => {
  test('only flags pending rows older than the cutoff', async () => {
    const old = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
    const recent = new Date().toISOString();
    const db = fakeDb({
      transactions: [
        { id: 't1', profile_id: 'p1', amount: 100, status: 'pending', created_at: old },
        { id: 't2', profile_id: 'p1', amount: 100, status: 'pending', created_at: recent },
      ],
    });
    const result = await stalePendingTransactions(db, { sampleLimit: 10, olderThanHours: 24 });
    expect(result.count).toBe(1);
    expect(result.samples[0].transactionId).toBe('t1');
  });
});

describe('negativeWalletBalance', () => {
  test('flags a wallet below zero', async () => {
    const db = fakeDb({
      wallets: [
        { id: 'w1', profile_id: 'p1', balance: -5, currency: 'NGN' },
        { id: 'w2', profile_id: 'p2', balance: 10, currency: 'NGN' },
      ],
    });
    const result = await negativeWalletBalance(db, { sampleLimit: 10 });
    expect(result.count).toBe(1);
    expect(result.samples[0].walletId).toBe('w1');
  });
});

describe('runIntegrityChecks', () => {
  test('aggregates results and names the critical checks that found something', async () => {
    const now = new Date().toISOString();
    const db = fakeDb({
      wallets: [{ id: 'w1', profile_id: 'p1', balance: -5, currency: 'NGN' }],
      transactions: [{ reference: 'REF-1', profile_id: 'p1', amount: 100, status: 'completed', created_at: now }],
      loans: [],
    });
    const { totals, results } = await runIntegrityChecks({ db, sampleLimit: 5 });
    expect(totals.checksRun).toBe(5);
    expect(totals.critical).toContain('negative_wallet_balance');
    // A clean check reports zero and is not named.
    expect(totals.critical).not.toContain('duplicate_completed_references');
    expect(results.find((r) => r.id === 'negative_wallet_balance').count).toBe(1);
  });

  test('a subset of checks can be requested', async () => {
    const db = fakeDb({ wallets: [], transactions: [], loans: [] });
    const { totals } = await runIntegrityChecks({ db, checks: ['negative_wallet_balance'] });
    expect(totals.checksRun).toBe(1);
  });
});
