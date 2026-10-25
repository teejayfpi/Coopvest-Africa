/**
 * Fraud/AML rule engine. These rules raise a case about a real person, so the
 * tests pin the boundaries hard: what counts as a debit, the sliding window, and
 * that a below-threshold pattern is NOT flagged (a false accusation is worse
 * than a missed one here).
 */

const {
  evaluateRules,
  ruleSharedBankAccount,
  ruleRapidLargeDebits,
  ruleStructuring,
  ruleGuaranteeBurst,
  ruleNewAccountHighValue,
} = require('../src/lib/fraudDetection');

const HOUR = 3600 * 1000;

function debit(profileId, amount, at, extra = {}) {
  return { id: `${profileId}-${at}`, profile_id: profileId, type: 'withdrawal', category: 'debit', amount, status: 'completed', created_at: at, ...extra };
}

describe('ruleSharedBankAccount', () => {
  test('flags one account number linked to two members', () => {
    const findings = ruleSharedBankAccount({
      bankAccounts: [
        { profile_id: 'p1', account_number: '0123456789' },
        { profile_id: 'p2', account_number: '0123456789' },
        { profile_id: 'p3', account_number: '9876543210' },
      ],
    });
    expect(findings).toHaveLength(1);
    expect(findings[0]).toMatchObject({ ruleId: 'shared_bank_account', severity: 'critical' });
    expect(findings[0].details.memberCount).toBe(2);
  });

  test('does not flag a single-member account', () => {
    expect(ruleSharedBankAccount({ bankAccounts: [{ profile_id: 'p1', account_number: '111' }] })).toHaveLength(0);
  });
});

describe('ruleRapidLargeDebits', () => {
  test('flags three large debits within the window', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const findings = ruleRapidLargeDebits({
      transactions: [
        debit('p1', 600000, new Date(t0).toISOString()),
        debit('p1', 700000, new Date(t0 + 2 * HOUR).toISOString()),
        debit('p1', 550000, new Date(t0 + 5 * HOUR).toISOString()),
      ],
    });
    expect(findings).toHaveLength(1);
    expect(findings[0].details.count).toBe(3);
    expect(findings[0].severity).toBe('critical');
  });

  test('does not flag large debits spread across days', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const findings = ruleRapidLargeDebits({
      transactions: [
        debit('p1', 600000, new Date(t0).toISOString()),
        debit('p1', 600000, new Date(t0 + 48 * HOUR).toISOString()),
        debit('p1', 600000, new Date(t0 + 96 * HOUR).toISOString()),
      ],
    });
    expect(findings).toHaveLength(0);
  });

  test('ignores small debits and pending rows', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const findings = ruleRapidLargeDebits({
      transactions: [
        debit('p1', 1000, new Date(t0).toISOString()),
        debit('p1', 600000, new Date(t0 + HOUR).toISOString(), { status: 'pending' }),
        debit('p1', 600000, new Date(t0 + 2 * HOUR).toISOString()),
      ],
    });
    expect(findings).toHaveLength(0);
  });
});

describe('ruleStructuring', () => {
  test('flags several debits kept just under the review threshold', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const findings = ruleStructuring({
      transactions: [
        debit('p1', 470000, new Date(t0).toISOString()),
        debit('p1', 480000, new Date(t0 + 3 * HOUR).toISOString()),
        debit('p1', 490000, new Date(t0 + 6 * HOUR).toISOString()),
      ],
    });
    expect(findings).toHaveLength(1);
    expect(findings[0].severity).toBe('warning');
  });

  test('does not flag the same count of genuinely small debits', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const findings = ruleStructuring({
      transactions: [
        debit('p1', 1000, new Date(t0).toISOString()),
        debit('p1', 1000, new Date(t0 + 3 * HOUR).toISOString()),
        debit('p1', 1000, new Date(t0 + 6 * HOUR).toISOString()),
      ],
    });
    expect(findings).toHaveLength(0);
  });
});

describe('ruleGuaranteeBurst', () => {
  test('flags a guarantor who consented to several loans quickly', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const guarantees = [1, 2, 3].map((n) => ({
      loan_id: `l${n}`,
      guarantor_profile_id: 'g1',
      status: 'consented',
      consented_at: new Date(t0 + n * 24 * HOUR).toISOString(),
    }));
    const findings = ruleGuaranteeBurst({ guarantees });
    expect(findings).toHaveLength(1);
    expect(findings[0].details.loanIds).toHaveLength(3);
  });

  test('accepts the legacy guarantor_id column too', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const guarantees = [1, 2, 3].map((n) => ({
      loan_id: `l${n}`,
      guarantor_id: 'g1',
      status: 'consented',
      consented_at: new Date(t0 + n * 24 * HOUR).toISOString(),
    }));
    expect(ruleGuaranteeBurst({ guarantees })).toHaveLength(1);
  });

  test('ignores pending guarantees', () => {
    const t0 = new Date('2025-06-01T00:00:00Z').getTime();
    const guarantees = [1, 2, 3].map((n) => ({
      loan_id: `l${n}`,
      guarantor_profile_id: 'g1',
      status: 'pending',
      consented_at: new Date(t0 + n * 24 * HOUR).toISOString(),
    }));
    expect(ruleGuaranteeBurst({ guarantees })).toHaveLength(0);
  });
});

describe('ruleNewAccountHighValue', () => {
  test('flags a new account whose activity crosses the high-value line', () => {
    const now = new Date('2025-06-20T00:00:00Z');
    const findings = ruleNewAccountHighValue({
      profiles: [{ id: 'p1', created_at: '2025-06-10T00:00:00Z' }],
      transactions: [
        { profile_id: 'p1', amount: 600000, category: 'credit', status: 'completed', created_at: '2025-06-11T00:00:00Z' },
        { profile_id: 'p1', amount: 600000, category: 'credit', status: 'completed', created_at: '2025-06-12T00:00:00Z' },
      ],
    }, { now });
    expect(findings).toHaveLength(1);
    expect(findings[0].details.total).toBe(1200000);
  });

  test('ignores an older account', () => {
    const now = new Date('2025-06-20T00:00:00Z');
    const findings = ruleNewAccountHighValue({
      profiles: [{ id: 'p1', created_at: '2024-01-01T00:00:00Z' }],
      transactions: [{ profile_id: 'p1', amount: 5000000, category: 'credit', status: 'completed', created_at: '2025-06-11T00:00:00Z' }],
    }, { now });
    expect(findings).toHaveLength(0);
  });
});

describe('evaluateRules', () => {
  test('runs every rule and tags each finding with its ruleId', () => {
    const now = new Date();
    const t0 = now.getTime() - HOUR;
    const findings = evaluateRules({
      bankAccounts: [
        { profile_id: 'p1', account_number: '0123456789' },
        { profile_id: 'p2', account_number: '0123456789' },
      ],
      transactions: [
        debit('p1', 600000, new Date(t0).toISOString()),
        debit('p1', 700000, new Date(t0 + 60 * 1000).toISOString()),
        debit('p1', 550000, new Date(t0 + 120 * 1000).toISOString()),
      ],
    });
    const ids = findings.map((f) => f.ruleId);
    expect(ids).toContain('shared_bank_account');
    expect(ids).toContain('rapid_large_debits');
    expect(findings.every((f) => typeof f.dedupeKey === 'string' && f.dedupeKey.length > 0)).toBe(true);
  });

  test('a malformed dataset does not abort the scan', () => {
    // null transactions would throw inside the rules; evaluateRules must swallow
    // it and still return whatever the other rules found.
    const findings = evaluateRules({ transactions: null, bankAccounts: [
      { profile_id: 'p1', account_number: '9' },
      { profile_id: 'p2', account_number: '9' },
    ] });
    expect(findings.some((f) => f.ruleId === 'shared_bank_account')).toBe(true);
  });

  test('dedupeKey is stable across runs for the same finding', () => {
    const datasets = {
      bankAccounts: [
        { profile_id: 'p1', account_number: '0123456789' },
        { profile_id: 'p2', account_number: '0123456789' },
      ],
    };
    const a = evaluateRules(datasets).find((f) => f.ruleId === 'shared_bank_account');
    const b = evaluateRules(datasets).find((f) => f.ruleId === 'shared_bank_account');
    expect(a.dedupeKey).toBe(b.dedupeKey);
  });
});
