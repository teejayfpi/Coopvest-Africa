const fs = require('fs');
const path = require('path');
const { applyPaidMonthRule } = require('../src/routes/wallet');

/**
 * The amount due is built from rows that exist, filtered by loan status. A loan
 * status missing from the filter silently drops that loan's repayment from what
 * the member owes.
 *
 * This happened with `in_recovery`: the recovery worker moves a loan there at
 * the third missed month, so the repayment vanished from amount due precisely
 * when the member was most in arrears. Migration 072 fixed the same omission in
 * the repayment path; this pins the obligations path.
 */
describe('amount due includes loans that still owe money', () => {
  const walletSrc = fs.readFileSync(
    path.join(__dirname, '../src/routes/wallet.js'),
    'utf8',
  );

  const listedStatuses = () => {
    const match = walletSrc.match(/const ACTIVE_LOAN_STATUSES = \[([^\]]+)\]/);
    expect(match).not.toBeNull();
    return match[1].split(',').map((s) => s.trim().replace(/['"]/g, ''));
  };

  test('in_recovery loans keep their repayment in amount due', () => {
    expect(listedStatuses()).toContain('in_recovery');
  });

  test('defaulted loans keep their repayment in amount due', () => {
    expect(listedStatuses()).toContain('defaulted');
  });

  test('only statuses the loans table accepts are listed', () => {
    // The live CHECK constraint, migration 013 plus later additions.
    const valid = [
      'pending', 'under_review', 'approved', 'active', 'repaying', 'overdue',
      'defaulted', 'in_recovery', 'completed', 'rejected', 'cancelled', 'rolled_over',
    ];
    for (const status of listedStatuses()) {
      expect(valid).toContain(status);
    }
  });

  test('settled and rejected loans are not billed', () => {
    const statuses = listedStatuses();
    expect(statuses).not.toContain('completed');
    expect(statuses).not.toContain('rejected');
    expect(statuses).not.toContain('cancelled');
    expect(statuses).not.toContain('pending');
  });

  test('a fine and a fee both reach total_due alongside the repayment', () => {
    const obligations = applyPaidMonthRule(
      {
        monthly_savings: 5000,
        loans: [{ loan_id: 'L1', monthly_repayment: 2000 }],
        fines: [{ id: 'f1', amount: 3000 }],
        fees: [{ id: 'x1', amount: 1500 }],
      },
      { paidThisMonth: false, joinedThisMonth: false },
    );
    // 5000 savings + 2000 repayment + 3000 penalty + 1500 administrative fee,
    // plus this month's recurring charge which has no row of its own yet.
    expect(obligations.total_due).toBe(13000);
  });
});
