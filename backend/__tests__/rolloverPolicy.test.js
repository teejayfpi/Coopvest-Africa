const fs = require('fs');
const path = require('path');

/**
 * The rollover rule, as agreed:
 *
 *   A member may REQUEST a rollover once they have repaid at least 70% of the
 *   original loan PRINCIPAL, with no serious default, an account in good
 *   standing, and within the savings-based loan limit. The outstanding balance
 *   is settled from the new loan and only the net amount is disbursed.
 *
 * Two things about that are easy to get wrong and are asserted here:
 *
 *  1. The threshold is on PRINCIPAL, not total amount paid. Interest, fees and
 *     penalties inflate "amount paid", so a member could otherwise look eligible
 *     without having repaid 70% of what they borrowed.
 *  2. Eligibility is permission to APPLY, never approval.
 *
 * The SQL is the source of truth; these tests check it says what was agreed,
 * since a silent change to the threshold would be invisible from the API shape.
 */
describe('rollover policy (migration 039)', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../migrations/039_rollover_principal_70.sql'),
    'utf8',
  );

  // Comments are stripped before matching. The migration documents the bugs it
  // replaces, so a guard that a comment can satisfy would be worthless — the
  // same trap the rollover flow guard hit.
  const code = sql
    .split('\n')
    .filter((l) => !l.trim().startsWith('--'))
    .join('\n');

  test('the threshold is 70 percent', () => {
    expect(code).toMatch(/'loan\.rollover_min_principal_pct',\s*'70'/);
  });

  test('the threshold is configurable, not hard-coded in the logic', () => {
    // The rule must read the setting, so the business can change 70 without a
    // code change.
    expect(code).toMatch(/FROM public\.system_settings WHERE key = 'loan\.rollover_min_principal_pct'/);
  });

  test('eligibility is computed from principal, not total amount paid', () => {
    // The percentage must come from the principal position.
    expect(code).toMatch(/repayment_percentage/);
    expect(code).toMatch(/principal_repaid/);
    expect(code).toMatch(/original_principal/);
    // And the removed approach must not reappear in executable SQL.
    expect(code).not.toMatch(/total_repaid/);
  });

  test('principal and interest are split pro-rata on simple interest', () => {
    // total_repayment = principal + principal x rate, so the principal share is
    // original_principal / total_repayment.
    expect(code).toMatch(/p_original_principal \/ p_total_repayment/);
  });

  test('a full repayment credits exactly 100% of principal', () => {
    // The property that makes the pro-rata split correct: paying the whole
    // total_repayment must reach 100%, not 99% from rounding.
    expect(code).toMatch(/LEAST\(1, p_original_principal \/ p_total_repayment\)/);
  });

  test('all five agreed rules are enforced', () => {
    const codes = [
      'INSUFFICIENT_PRINCIPAL_REPAID',   // 70% of principal
      'SERIOUS_DEFAULT',                 // no serious default
      'OUTSTANDING_OBLIGATIONS',         // account in good standing
      'ROLLOVER_LIMIT_REACHED',          // cap on consecutive rollovers
      'LOAN_NOT_ACTIVE',                 // must still be refinanceable
    ];
    for (const code of codes) {
      expect({ code, present: sql.includes(code) }).toEqual({ code, present: true });
    }
  });

  test('eligibility reports every rule separately, not just a yes/no', () => {
    // The app shows a checklist, so each condition needs its own flag.
    for (const flag of [
      'has_minimum_principal_repaid',
      'has_no_serious_default',
      'account_in_good_standing',
      'within_rollover_limit',
    ]) {
      expect({ flag, present: sql.includes(flag) }).toEqual({ flag, present: true });
    }
  });

  test('the new loan settles the old and disburses only the net', () => {
    // The core of the refinancing model.
    expect(sql).toMatch(/'new_loan_amount'/);
    expect(sql).toMatch(/'existing_balance_settled'/);
    expect(sql).toMatch(/'net_amount_to_member'/);
    expect(sql).toMatch(/p_requested_amount - v_settlement/);
  });

  test('a rollover creates a new loan rather than mutating the old one', () => {
    // Rule 4: Loan #001 -> Rollover -> Loan #002, for the audit trail.
    expect(sql).toMatch(/INSERT INTO public\.loans/);
    expect(sql).toMatch(/parent_loan_id/);
    expect(sql).toMatch(/is_rollover/);
    expect(sql).toMatch(/rollover_count/);
    // And the old loan is closed, not left active with a stale balance.
    expect(sql).toMatch(/status = 'rolled_over'/);
    expect(sql).toMatch(/remaining_balance = 0/);
  });

  test('a request that leaves nothing to disburse is refused', () => {
    // Otherwise it is a repayment with extra steps.
    expect(sql).toMatch(/NO_NET_DISBURSEMENT/);
  });

  test('the new loan must still pass the savings-based limit', () => {
    expect(sql).toMatch(/EXCEEDS_LOAN_LIMIT/);
    expect(sql).toMatch(/v_max_loan/);
  });

  test('execution is single-use', () => {
    expect(sql).toMatch(/already been executed/);
    expect(sql).toMatch(/applied_at IS NOT NULL/);
  });

  test('repeated rollovers are capped', () => {
    expect(sql).toMatch(/'loan\.rollover_max_consecutive'/);
    expect(sql).toMatch(/rollover_count, 0\) >= v_max_cycles/);
  });
});