const { normalizeTransaction, mergeLedgerRows } = require('../src/services/ledgerMerge');

describe('normalizeTransaction', () => {
  test('maps a credit transaction to a ledger credit row', () => {
    const row = normalizeTransaction({
      id: 'tx-1',
      transaction_id: 'TXN-abc',
      profile_id: 'p-1',
      category: 'credit',
      amount: 5000,
      type: 'deposit',
      description: 'Wallet deposit',
      payment_method: 'bank_transfer',
      status: 'completed',
      reference: 'REF-1',
      created_at: '2026-06-24T14:30:14Z',
      profile: { name: 'Ada', email: 'ada@example.com', user_id: 'CV-0001' },
    });
    expect(row.credit).toBe(5000);
    expect(row.debit).toBe(0);
    expect(row.amount).toBe(5000);
    expect(row.memberName).toBe('Ada');
    expect(row.membershipId).toBe('CV-0001');
    expect(row.transactionId).toBe('TXN-abc');
    expect(row.fallback).toBe(true);
  });

  test('maps a debit transaction to a ledger debit row with negative amount', () => {
    const row = normalizeTransaction({ id: 'tx-2', category: 'debit', amount: 1200, created_at: '2026-06-25T00:00:00Z' });
    expect(row.debit).toBe(1200);
    expect(row.credit).toBe(0);
    expect(row.amount).toBe(-1200);
    expect(row.memberName).toBeNull();
  });

  test('handles missing amount and profile gracefully', () => {
    const row = normalizeTransaction({ id: 'tx-3' });
    expect(row.credit).toBe(0);
    expect(row.debit).toBe(0);
    expect(row.status).toBe('completed');
    expect(row.source).toBe('system');
  });
});

describe('mergeLedgerRows', () => {
  const tx = (id, reference, createdAt) => ({ id, reference, createdAt, fallback: true });

  test('unions ledger entries with transactions so the ledger is never empty', () => {
    const merged = mergeLedgerRows([], [tx('t1', 'R1', '2026-06-01T00:00:00Z')]);
    expect(merged).toHaveLength(1);
    expect(merged[0].id).toBe('t1');
  });

  test('keeps the stored ledger row when a transaction with the same reference exists', () => {
    const stored = { id: 'le-1', reference: 'R1', created_at: '2026-06-01T00:00:00Z', source: 'payment-proof' };
    const merged = mergeLedgerRows([stored], [tx('t1', 'R1', '2026-06-01T00:00:00Z')]);
    expect(merged).toHaveLength(1);
    expect(merged[0].id).toBe('le-1');
  });

  test('never drops REV- reversal entries that reference an original transaction', () => {
    const reversal = { id: 'le-2', reference: 'REV-R1', created_at: '2026-06-02T00:00:00Z' };
    const merged = mergeLedgerRows([reversal], [tx('t1', 'R1', '2026-06-01T00:00:00Z')]);
    expect(merged).toHaveLength(2);
  });

  test('sorts merged rows newest-first across both date field shapes', () => {
    const stored = { id: 'le-3', reference: 'R9', created_at: '2026-06-03T00:00:00Z' };
    const merged = mergeLedgerRows([stored], [
      tx('t-old', 'R1', '2026-06-01T00:00:00Z'),
      tx('t-new', 'R2', '2026-06-05T00:00:00Z'),
    ]);
    expect(merged.map((r) => r.id)).toEqual(['t-new', 'le-3', 't-old']);
  });

  test('handles null inputs', () => {
    expect(mergeLedgerRows(null, null)).toEqual([]);
  });
});
