/**
 * Merged-ledger helpers (pure functions — unit-testable without Supabase).
 *
 * `ledger_entries` only holds entries posted through the admin platform
 * (reversals, manual adjustments, payment-proof auto-posts). Historical and
 * member-facing activity lives in `transactions`. Unless a backfill/mirror
 * job runs, querying `ledger_entries` alone renders the ledger empty even
 * though the platform has real financial activity, so the admin endpoints
 * union the two sources through these helpers.
 */

// Normalize one `transactions` row into the ledger row shape shared by the
// admin endpoints (`/ledger`, `/ledger/dashboard`, `/ledger/export.csv`).
function normalizeTransaction(t) {
  const amount = Number(t.amount || 0);
  const isCredit = (t.category || '').toLowerCase() === 'credit';
  return {
    id: t.id,
    transactionId: t.transaction_id || t.id,
    profileId: t.profile_id,
    memberName: t.profile?.name || t.profile?.email || null,
    membershipId: t.profile?.user_id || null,
    reference: t.reference || null,
    type: t.type || null,
    description: t.description || t.type || null,
    debit: isCredit ? 0 : amount,
    credit: isCredit ? amount : 0,
    amount: isCredit ? amount : -amount,
    paymentMethod: t.payment_method || null,
    source: t.source || 'system',
    status: t.status || 'completed',
    reversed: !!t.reversed,
    reversalOf: null,
    createdAt: t.created_at,
    fallback: true,
  };
}

// Union stored ledger rows with computed transaction rows. A transaction
// already represented in ledger_entries (same reference) is kept in its
// richer stored form; every other transaction is appended. Reversal entries
// use `REV-` prefixed references, so they never collide with the original.
// Result is sorted newest-first.
function mergeLedgerRows(ledgerRows, txRows) {
  const seen = new Set((ledgerRows || []).map((r) => r.reference).filter(Boolean));
  const merged = [
    ...(ledgerRows || []),
    ...(txRows || []).filter((t) => !t.reference || !seen.has(t.reference)),
  ];
  merged.sort((a, b) => {
    const aTs = a.created_at || a.createdAt || '';
    const bTs = b.created_at || b.createdAt || '';
    return bTs < aTs ? -1 : bTs > aTs ? 1 : 0;
  });
  return merged;
}

module.exports = { normalizeTransaction, mergeLedgerRows };
