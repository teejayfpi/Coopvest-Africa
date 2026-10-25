/**
 * Annual contribution & interest certificate aggregation.
 *
 * The certificate is a figure a member shows an employer or a tax office, so the
 * tests pin the boundaries that matter: only settled transactions count, prior
 * years feed the opening balance, and interest is reported separately from
 * contributions.
 */

const { buildCertificate } = require('../src/lib/annualCertificate');

const profile = { id: '11111111-2222-3333-4444-555555555555', name: 'Ada Obi', email: 'ada@example.com' };

function txn(overrides) {
  return { type: 'savings', category: 'credit', amount: 100, status: 'completed', created_at: '2025-06-15T10:00:00Z', ...overrides };
}

describe('buildCertificate', () => {
  test('totals contributions and interest for the year only', () => {
    const cert = buildCertificate({
      profile,
      year: 2025,
      transactions: [
        txn({ amount: 1000, created_at: '2025-01-10T00:00:00Z' }),
        txn({ amount: 500, created_at: '2025-12-31T00:00:00Z' }),
        txn({ type: 'interest', amount: 250, created_at: '2025-06-30T00:00:00Z' }),
        // Belongs to the prior year — must not be in the year's totals.
        txn({ amount: 9000, created_at: '2024-06-15T00:00:00Z' }),
      ],
    });
    expect(cert.year).toBe(2025);
    expect(cert.summary.totalContributions).toBe(1500);
    expect(cert.summary.totalInterest).toBe(250);
  });

  test('carries prior-year activity into the opening balance', () => {
    const cert = buildCertificate({
      profile,
      year: 2025,
      transactions: [
        txn({ amount: 9000, created_at: '2024-06-15T00:00:00Z' }),
        txn({ amount: 1000, created_at: '2025-01-10T00:00:00Z' }),
      ],
    });
    expect(cert.summary.openingBalance).toBe(9000);
    expect(cert.summary.closingBalance).toBe(10000);
  });

  test('excludes pending transactions so an unsettled charge never inflates it', () => {
    const cert = buildCertificate({
      profile,
      year: 2025,
      transactions: [
        txn({ amount: 1000 }),
        txn({ amount: 5000, status: 'pending' }),
        txn({ amount: 700, status: 'failed' }),
      ],
    });
    expect(cert.summary.totalContributions).toBe(1000);
    expect(cert.summary.closingBalance).toBe(1000);
  });

  test('a debit reduces the closing balance and is reported as a withdrawal', () => {
    const cert = buildCertificate({
      profile,
      year: 2025,
      transactions: [
        txn({ amount: 1000 }),
        txn({ type: 'withdrawal', category: 'debit', amount: 300 }),
      ],
    });
    expect(cert.summary.totalWithdrawals).toBe(300);
    expect(cert.summary.closingBalance).toBe(700);
  });

  test('breaks contributions and interest down by month', () => {
    const cert = buildCertificate({
      profile,
      year: 2025,
      transactions: [
        txn({ amount: 100, created_at: '2025-01-05T00:00:00Z' }),
        txn({ amount: 200, created_at: '2025-01-20T00:00:00Z' }),
        txn({ type: 'interest', amount: 50, created_at: '2025-03-31T00:00:00Z' }),
      ],
    });
    expect(cert.monthly).toHaveLength(12);
    expect(cert.monthly[0]).toMatchObject({ month: 1, name: 'January', contributions: 300, count: 2 });
    expect(cert.monthly[2]).toMatchObject({ month: 3, name: 'March', interest: 50 });
    expect(cert.monthly[5].contributions).toBe(0);
  });

  test('produces a stable, quotable reference', () => {
    const cert = buildCertificate({ profile, year: 2025, transactions: [] });
    expect(cert.reference).toBe('CV-2025-11111111');
    expect(cert.certificateType).toBe('annual_contribution_and_interest');
  });

  test('rejects a missing or non-integer year', () => {
    expect(() => buildCertificate({ profile, transactions: [] })).toThrow(/year/i);
    expect(() => buildCertificate({ profile, year: 'x', transactions: [] })).toThrow(/year/i);
  });

  test('an empty year is a valid certificate of zero', () => {
    const cert = buildCertificate({ profile, year: 2025, transactions: [] });
    expect(cert.summary).toMatchObject({
      openingBalance: 0,
      totalContributions: 0,
      totalInterest: 0,
      closingBalance: 0,
      transactionCount: 0,
    });
  });
});
