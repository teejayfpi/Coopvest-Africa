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
/**
 * The fine was charged once per worker tick, not once per loan.
 *
 * Stage 2 matched `missedMonths === 2` and inserted an unconditional
 * `member_fees` row. The worker polls daily, so a loan sitting at exactly two
 * missed months gained a fresh ₦3,000 obligation every morning — roughly
 * ₦90,000 against a ₦3,000 policy fine. `penalty_applied` was written on each
 * run but never read anywhere, so it could not act as a guard.
 *
 * These pin the two properties that make it safe: the fine is idempotent, and
 * a loan that passes from 2 to 3 missed months still gets its stage-3
 * escalation.
 */
describe('late repayment fine is charged once per loan', () => {
  const src = fs.readFileSync(
    path.join(__dirname, '../src/workers/loanRecoveryWorker.js'),
    'utf8',
  );

  test('stage 2 is guarded by a durable check, not just the loan flag', () => {
    expect(src).toMatch(/hasOutstandingLateFine/);
    expect(src).toMatch(/const alreadyFined =/);
    expect(src).toMatch(/if \(!alreadyFined\)/);
  });

  test('the durable check reads the fee obligation itself', () => {
    // `penalty_applied` is reset by admin restructure while the fee row stays,
    // so the row is the only source that cannot be cleared by accident.
    const idx = src.indexOf('async function hasOutstandingLateFine');
    const body = src.slice(idx, idx + 700);
    expect(body).toMatch(/from\('member_fees'\)/);
    expect(body).toMatch(/fee_type', 'fine'/);
  });

  test('a failed fine lookup errs towards not charging again', () => {
    const idx = src.indexOf('async function hasOutstandingLateFine');
    const body = src.slice(idx, idx + 700);
    expect(body).toMatch(/if \(error\)/);
    expect(body).toMatch(/return true;/);
  });

  test('the fine insert is error-checked', () => {
    // A swallowed insert error notified the member of a fee that was never
    // recorded on their account.
    const idx = src.indexOf("from('member_fees').insert");
    expect(idx).toBeGreaterThan(-1);
    expect(src.slice(idx, idx + 700)).toMatch(/if \(fineErr\)/);
  });

  test('stage 2 keeps matching past the second month', () => {
    expect(src).toMatch(/missedMonths >= 2/);
    expect(src).not.toMatch(/missedMonths === 2/);
  });

  test('stage 3 is not chained behind stage 2', () => {
    // With stage 2 matching >= 2, an `else if` would make stage 3 unreachable.
    const idx = src.indexOf('STAGE 3');
    expect(src.slice(idx, idx + 400)).toMatch(/^\s*if \(missedMonths >= 3\)/m);
  });

  test('admin is not re-notified on every tick', () => {
    expect(src).toMatch(/if \(!alreadyFined\) await notifyAdminOfDefault\(loan, 2\)/);
  });
});

/**
 * Migration 072 — a defaulted member must be able to repay.
 *
 * The worker sets `in_recovery` at the third missed month, and the repayment
 * RPC accepted only active/repaying/overdue. Nothing moved a loan out of
 * `in_recovery`, so a member in recovery could never repay, and — because
 * `is_flagged` blocks login outright — was locked out of the app as well.
 *
 * The same migration closes a loan at zero balance. Previously only the admin
 * payment-proof path set `completed`, so a loan repaid from the wallet stayed
 * `active` and kept escalating through the recovery worker.
 */
describe('repayment can settle a loan in recovery', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../migrations/072_recovery_repayment_and_settlement.sql'),
    'utf8',
  );

  test('in_recovery is an accepted repayment status', () => {
    expect(sql).toMatch(/NOT IN \('active', 'repaying', 'overdue', 'in_recovery'\)/);
  });

  test('a zero balance closes the loan', () => {
    expect(sql).toMatch(/WHEN v_new_remaining <= 0 THEN 'completed'/);
  });

  test('settling clears the default flag so login is restored', () => {
    expect(sql).toMatch(/is_flagged = false, flag_reason = NULL/);
    // Only when no other loan is still in arrears — one settled loan must not
    // unlock a member who has another in recovery.
    expect(sql).toMatch(/status IN \('overdue', 'defaulted', 'in_recovery'\)/);
  });

  test('the overpayment guard is preserved', () => {
    expect(sql).toMatch(/exceeds the outstanding loan balance/);
  });

  test('the principal/interest split is preserved', () => {
    expect(sql).toMatch(/split_repayment_principal/);
    expect(sql).toMatch(/v_interest := v_amount - v_principal/);
  });
});
