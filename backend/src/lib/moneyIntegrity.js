/**
 * Money-integrity checks.
 *
 * The platform's money lives in several places that are supposed to agree:
 * `wallets.balance` is meant to equal the net of a member's completed ledger
 * entries; `loans.remaining_balance` is mirrored into `outstanding_balance` by a
 * trigger; a settled charge should appear once, not twice. When those drift the
 * symptom is always the same — a member sees a number that no transaction
 * supports — and it is found by a person noticing, weeks later.
 *
 * This module is the runner for the "money integrity" job: a fixed set of
 * read-only checks that each return the rows that disagree. It never writes to
 * the ledger; a human decides what to do with a discrepancy. Results are
 * persisted by the route so a discrepancy has a trail.
 *
 * Every check receives the Supabase-like `db` and returns
 * `{ count, samples, truncated, error }`. A check that cannot run (a table the
 * deployment does not have) reports an `error` rather than throwing, so one
 * broken check never hides the others.
 */

const DEFAULT_SAMPLE_LIMIT = 20;
const WALLET_SCAN_CAP = 5000;

function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function money(n) {
  return Math.round(toNumber(n) * 100) / 100;
}

/**
 * wallets.balance must equal the net of that member's completed transactions.
 *
 * Credits add, debits subtract. A pending or failed transaction has not moved
 * money yet, so it is excluded — including it is the classic false positive.
 */
async function walletBalanceVsLedger(db, { sampleLimit }) {
  const { data: wallets, error: wErr } = await db
    .from('wallets')
    .select('id, profile_id, balance, currency')
    .limit(WALLET_SCAN_CAP);
  if (wErr) return { error: wErr.message };

  const rows = wallets || [];
  if (rows.length === 0) return { count: 0, samples: [], truncated: false };

  const profileIds = [...new Set(rows.map((w) => w.profile_id).filter(Boolean))];
  const net = new Map();

  // Batch the ledger read so a large member base does not build one huge `in`.
  const BATCH = 200;
  for (let i = 0; i < profileIds.length; i += BATCH) {
    const batch = profileIds.slice(i, i + BATCH);
    const { data: txns, error: tErr } = await db
      .from('transactions')
      .select('profile_id, amount, category, status')
      .in('profile_id', batch)
      .eq('status', 'completed');
    if (tErr) return { error: tErr.message };
    for (const t of txns || []) {
      const delta = t.category === 'debit' ? -toNumber(t.amount) : toNumber(t.amount);
      net.set(t.profile_id, (net.get(t.profile_id) || 0) + delta);
    }
  }

  const mismatches = [];
  for (const w of rows) {
    const expected = money(net.get(w.profile_id) || 0);
    const actual = money(w.balance);
    if (Math.abs(expected - actual) >= 0.01) {
      mismatches.push({
        walletId: w.id,
        profileId: w.profile_id,
        currency: w.currency || 'NGN',
        storedBalance: actual,
        ledgerBalance: expected,
        difference: money(actual - expected),
      });
    }
  }

  return {
    count: mismatches.length,
    samples: mismatches.slice(0, sampleLimit),
    truncated: mismatches.length > sampleLimit,
  };
}

/** A wallet balance below zero — money that cannot exist. */
async function negativeWalletBalance(db, { sampleLimit }) {
  const { data, error } = await db
    .from('wallets')
    .select('id, profile_id, balance, currency')
    .lt('balance', 0)
    .limit(sampleLimit + 1);
  if (error) return { error: error.message };
  const rows = data || [];
  return {
    count: rows.length,
    samples: rows.slice(0, sampleLimit).map((w) => ({
      walletId: w.id,
      profileId: w.profile_id,
      balance: money(w.balance),
      currency: w.currency || 'NGN',
    })),
    truncated: rows.length > sampleLimit,
  };
}

/**
 * Completed transactions that share a reference.
 *
 * A duplicate settled charge means a member was credited or debited twice for
 * one payment. Idempotency is meant to prevent this, so any hit is real.
 */
async function duplicateCompletedReferences(db, { sampleLimit, sinceDays = 90 }) {
  const since = new Date(Date.now() - sinceDays * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await db
    .from('transactions')
    .select('reference, profile_id, amount, status, created_at')
    .eq('status', 'completed')
    .gte('created_at', since)
    .not('reference', 'is', null)
    .limit(WALLET_SCAN_CAP);
  if (error) return { error: error.message };

  const byRef = new Map();
  for (const t of data || []) {
    if (!t.reference) continue;
    const list = byRef.get(t.reference) || [];
    list.push(t);
    byRef.set(t.reference, list);
  }

  const dupes = [];
  for (const [reference, list] of byRef.entries()) {
    if (list.length > 1) {
      dupes.push({
        reference,
        occurrences: list.length,
        totalAmount: money(list.reduce((s, t) => s + toNumber(t.amount), 0)),
        profileIds: [...new Set(list.map((t) => t.profile_id).filter(Boolean))],
      });
    }
  }

  return {
    count: dupes.length,
    samples: dupes.slice(0, sampleLimit),
    truncated: dupes.length > sampleLimit,
  };
}

/**
 * `remaining_balance` (source of truth) and `outstanding_balance` (mirror kept
 * in step by the migration-040 trigger) must agree. A gap means a write path
 * bypassed the trigger.
 */
async function loanOutstandingMirrorMismatch(db, { sampleLimit }) {
  const { data, error } = await db
    .from('loans')
    .select('id, profile_id, remaining_balance, outstanding_balance, amount, status')
    .not('outstanding_balance', 'is', null)
    .limit(WALLET_SCAN_CAP);
  if (error) return { error: error.message };

  const mismatches = [];
  for (const l of data || []) {
    const remaining = money(l.remaining_balance ?? l.amount);
    const mirror = money(l.outstanding_balance);
    if (Math.abs(remaining - mirror) >= 0.01) {
      mismatches.push({
        loanId: l.id,
        profileId: l.profile_id,
        status: l.status,
        remainingBalance: remaining,
        outstandingBalance: mirror,
        difference: money(mirror - remaining),
      });
    }
  }

  return {
    count: mismatches.length,
    samples: mismatches.slice(0, sampleLimit),
    truncated: mismatches.length > sampleLimit,
  };
}

/**
 * Transactions parked in `pending` for longer than a day.
 *
 * A charge that never reached a terminal state is the failure mode the
 * failed-charge reconcile worker exists for; anything still pending after 24h
 * means that sweep could not resolve it either, so a human must.
 */
async function stalePendingTransactions(db, { sampleLimit, olderThanHours = 24 }) {
  const cutoff = new Date(Date.now() - olderThanHours * 60 * 60 * 1000).toISOString();
  const { data, error } = await db
    .from('transactions')
    .select('id, profile_id, amount, type, category, reference, created_at')
    .eq('status', 'pending')
    .lt('created_at', cutoff)
    .order('created_at', { ascending: true })
    .limit(sampleLimit + 1);
  if (error) return { error: error.message };
  const rows = data || [];
  return {
    count: rows.length,
    samples: rows.slice(0, sampleLimit).map((t) => ({
      transactionId: t.id,
      profileId: t.profile_id,
      amount: money(t.amount),
      type: t.type || t.category,
      reference: t.reference,
      createdAt: t.created_at,
    })),
    truncated: rows.length > sampleLimit,
  };
}

/**
 * The registry the route iterates. `severity` drives whether a non-zero count
 * raises an admin alert: `critical` always alerts, `warning` only records.
 */
const CHECKS = [
  { id: 'wallet_balance_vs_ledger', title: 'Wallet balance disagrees with the transaction ledger', severity: 'critical', run: walletBalanceVsLedger },
  { id: 'duplicate_completed_references', title: 'Duplicate completed transactions sharing a reference', severity: 'critical', run: duplicateCompletedReferences },
  { id: 'negative_wallet_balance', title: 'Wallet with a negative balance', severity: 'critical', run: negativeWalletBalance },
  { id: 'loan_outstanding_mirror_mismatch', title: 'Loan outstanding_balance does not mirror remaining_balance', severity: 'warning', run: loanOutstandingMirrorMismatch },
  { id: 'stale_pending_transactions', title: 'Transaction pending for more than 24 hours', severity: 'warning', run: stalePendingTransactions },
];

/**
 * Run every check (or a named subset).
 *
 * @param {object}   opts
 * @param {object}   opts.db          Supabase-like client
 * @param {string[]} [opts.checks]    check ids to run; default all
 * @param {number}   [opts.sampleLimit]
 * @returns {Promise<{ranAt: string, results: Array, totals: object}>}
 */
async function runIntegrityChecks({ db, checks, sampleLimit = DEFAULT_SAMPLE_LIMIT } = {}) {
  const selected = Array.isArray(checks) && checks.length > 0
    ? CHECKS.filter((c) => checks.includes(c.id))
    : CHECKS;

  const results = [];
  for (const check of selected) {
    let outcome;
    try {
      outcome = await check.run(db, { sampleLimit });
    } catch (err) {
      outcome = { error: err.message };
    }
    results.push({
      id: check.id,
      title: check.title,
      severity: check.severity,
      count: outcome.error ? 0 : outcome.count,
      samples: outcome.samples || [],
      truncated: Boolean(outcome.truncated),
      error: outcome.error || null,
    });
  }

  const totals = {
    checksRun: results.length,
    checksErrored: results.filter((r) => r.error).length,
    discrepancies: results.reduce((s, r) => s + r.count, 0),
    critical: results.filter((r) => r.severity === 'critical' && r.count > 0).map((r) => r.id),
    warning: results.filter((r) => r.severity === 'warning' && r.count > 0).map((r) => r.id),
  };

  return { ranAt: new Date().toISOString(), results, totals };
}

module.exports = {
  CHECKS,
  runIntegrityChecks,
  // exported for targeted tests
  walletBalanceVsLedger,
  negativeWalletBalance,
  duplicateCompletedReferences,
  loanOutstandingMirrorMismatch,
  stalePendingTransactions,
};
