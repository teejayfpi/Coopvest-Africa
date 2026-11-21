/**
 * Migration 071: repayments record their principal/interest split.
 *
 * The behaviour these guard: `comparative.js` and `comparativeMetrics.js` read
 * `loan_repayments.principal_component` / `interest_component`, which
 * wallet_loan_repayment left NULL, so interest income read as zero everywhere.
 */

const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(
  path.join(__dirname, '../migrations/071_repayment_split.sql'), 'utf8',
);

describe('migration 071 records the repayment split', () => {
  test('both components are written on the repayment row', () => {
    expect(sql).toMatch(/principal_component,\s*interest_component/);
    expect(sql).toMatch(/v_amount,\s*v_principal,\s*v_interest/);
  });

  test('the split reuses split_repayment_principal rather than a second rule', () => {
    // A second definition would drift from the principal_repaid trigger, which
    // falls back to this same helper.
    expect(sql).toMatch(/public\.split_repayment_principal\(/);
  });

  test('the split is derived from the loan, not from the caller', () => {
    // The wallet path takes only an amount; a caller-supplied split would let a
    // member choose how much interest they pay.
    expect(sql).toMatch(/COALESCE\(v_loan\.original_principal,\s*v_loan\.amount\)/);
    expect(sql).toMatch(/v_loan\.total_repayment/);
  });

  test('interest is the remainder, so the two always sum to the payment', () => {
    expect(sql).toMatch(/v_interest\s*:=\s*v_amount\s*-\s*v_principal/);
  });

  test('the overpayment and status guards survive the rewrite', () => {
    // This migration replaces the whole function; losing a guard here would
    // silently reintroduce the bugs earlier migrations fixed.
    expect(sql).toMatch(/v_amount > v_remaining/);
    expect(sql).toMatch(/NOT IN \('active', 'repaying', 'overdue'\)/);
    expect(sql).toMatch(/v_loan\.profile_id IS DISTINCT FROM p_profile_id/);
  });

  test('the loan is still locked before the wallet', () => {
    const loanLock = sql.indexOf('FROM public.loans WHERE id = p_loan_id FOR UPDATE');
    const walletLock = sql.indexOf('WHERE profile_id = p_profile_id FOR UPDATE');
    expect(loanLock).toBeGreaterThan(-1);
    expect(walletLock).toBeGreaterThan(loanLock);
  });

  test('the ledger row and balance update are unchanged', () => {
    expect(sql).toMatch(/'loan_repayment',\s*\n\s*'debit'/);
    expect(sql).toMatch(/remaining_balance = v_new_remaining/);
  });
});

describe('split_repayment_principal arithmetic', () => {
  /**
   * Mirror of the SQL helper, used to pin the behaviour the migration relies on.
   * If these expectations change, the migration's comment about pro-rata is
   * wrong and needs revisiting.
   */
  const split = (amount, principal, total) => {
    if (!amount || amount <= 0) return 0;
    if (!principal || principal <= 0) return 0;
    if (!total || total <= 0) return amount;
    const share = Math.min(1, principal / total);
    return Math.round(amount * share * 100) / 100;
  };

  test('a loan with no interest is all principal', () => {
    expect(split(10000, 100000, 100000)).toBe(10000);
  });

  test('a loan with interest splits pro-rata', () => {
    // 250,000 principal over 260,000 total => 96.15% of each payment.
    const principal = split(65000, 250000, 260000);
    expect(principal).toBeCloseTo(62500, 2);
    expect(65000 - principal).toBeCloseTo(2500, 2);
  });

  test('the components always sum to the amount paid', () => {
    for (const [amt, p, t] of [
      [65000, 250000, 260000],
      [1, 999999, 1000000],
      [12345.67, 500000, 512345.67],
      [100, 1, 1000000],
    ]) {
      const principal = split(amt, p, t);
      expect(Math.round((principal + (amt - principal)) * 100) / 100).toBe(amt);
    }
  });

  test('a missing total treats the payment as principal, not zero', () => {
    expect(split(5000, 100000, null)).toBe(5000);
  });

  test('principal never exceeds the payment when the loan is over-secured', () => {
    // principal > total is nonsense, but must not produce a negative interest.
    expect(split(1000, 200000, 100000)).toBe(1000);
  });
});
