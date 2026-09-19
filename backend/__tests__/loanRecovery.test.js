const fs = require('fs');
const path = require('path');

/**
 * Regression guard for loan-recovery escalation.
 *
 * `getConsecutiveMissedMonths` read `loan.missed_months` and
 * `loan.payments_made`. Neither is a column on `loans` (verified against
 * production), so `payments_made` was always 0 and the function returned every
 * month elapsed since approval:
 *
 *     return Math.max(0, expectedPayments - 0) === monthsSinceApproved
 *
 * A member who had repaid every month was therefore still reported as having
 * missed all of them, and escalated to a ₦3,000 penalty. The nearby
 * `next_due_date` comparison had the opposite problem: nothing ever wrote that
 * column, so it could never match and overdue loans were invisible.
 *
 * These tests pin the corrected behaviour: missed months are derived from
 * recorded repayments, not from an assumption.
 */
describe('loan recovery escalation', () => {
  const src = fs.readFileSync(
    path.join(__dirname, '../src/workers/loanRecoveryWorker.js'),
    'utf8',
  );

  // Comments name the removed columns to explain the bug, so strip them before
  // asserting — a guard a comment can satisfy is worthless.
  const code = src
    .split('\n')
    .filter((l) => !l.trim().startsWith('//') && !l.trim().startsWith('*') && !l.trim().startsWith('/*'))
    .join('\n');

  test('does not read columns that do not exist on loans', () => {
    // `disbursed_at` is referenced only inside a fallback chain in code and in
    // comments; the two that broke the calculation must be gone from logic.
    expect(code).not.toMatch(/loan\.payments_made/);
    expect(code).not.toMatch(/loan\.missed_months/);
  });

  test('derives missed months from recorded repayments', () => {
    // The only trustworthy source: repayments actually marked paid.
    expect(code).toMatch(/from\('loan_repayments'\)/);
    expect(code).toMatch(/in\('status', \[.*paid.*\]\)/);
    expect(code).toMatch(/paidMonths/);
  });

  test('counts one instalment per month, not per payment', () => {
    // Two part-payments in one month settle that month once; counting rows
    // would let a member close out future months by overpaying once.
    expect(code).toMatch(/Math\.min\(paidMonths\.size, expectedPayments\)/);
  });

  test('fails closed when the repayment lookup errors', () => {
    // Escalating a member on a failed lookup is worse than skipping the cycle.
    const lookupIdx = code.indexOf("from('loan_repayments')");
    const after = code.slice(lookupIdx, lookupIdx + 900);
    expect(after).toMatch(/if \(error\)/);
    expect(after).toMatch(/return 0;/);
  });

  test('the call site awaits the now-async check', () => {
    expect(code).toMatch(/await getConsecutiveMissedMonths\(loan\)/);
  });

  test('a loan with no repayments is still detectable as missed', () => {
    // The corrected function must not swing the other way and report nothing
    // for a genuinely overdue loan.
    expect(code).toMatch(/expectedPayments - paidCount/);
  });
});