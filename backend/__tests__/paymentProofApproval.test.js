const fs = require('fs');
const path = require('path');

/**
 * Approving a payment proof silently posted nothing for every approval ever
 * made. Three inserts in `handle_payment_proof_approval()` failed on every
 * call, each wrapped in `exception when others then null`, so the approval
 * looked successful while savings, the wallet transaction and the ledger all
 * stayed empty.
 *
 * These assertions pin the specific mistakes, because a regression here costs a
 * member their money and produces no error to notice.
 */
describe('payment proof approval trigger', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../migrations/078_payment_proof_creates_savings.sql'),
    'utf8'
  );

  const body = sql.slice(sql.indexOf('CREATE OR REPLACE FUNCTION'));

  test('creates the savings row before crediting it', () => {
    // `savings` is created lazily by the API, so a first-time payer has no row
    // and a bare UPDATE matches zero rows without raising.
    const credit = body.indexOf('update public.savings');
    expect(credit).toBeGreaterThan(-1);
    expect(body.slice(0, credit)).toMatch(/perform public\.ensure_savings_row\(new\.profile_id\)/);
  });

  test('supplies transaction_id, which is NOT NULL with no default', () => {
    const insert = body.slice(body.indexOf('insert into public.transactions'));
    const columns = insert.slice(0, insert.indexOf(') values'));
    expect(columns).toMatch(/transaction_id/);
  });

  test('uses values the transactions CHECK constraints accept', () => {
    const insert = body.slice(body.indexOf('insert into public.transactions'));
    const values = insert.slice(insert.indexOf(') values'), insert.indexOf(');'));

    // category must be credit|debit; status must not be 'successful'.
    expect(values).toMatch(/'credit'/);
    expect(values).not.toMatch(/'successful'/);
    expect(values).toMatch(/'completed'/);

    // type must come from the fixed list; 'credit' is not one of them.
    expect(values).not.toMatch(/new\.profile_id,\s*'credit'/);
    expect(values).toMatch(/'(savings_deposit|investment|deposit)'/);
  });

  test('casts the uuid before comparing it to loan_repayments.reference (text)', () => {
    expect(body).toMatch(/loan_repayments where reference = new\.id::text/);
  });

  test('reports failures instead of discarding them', () => {
    // A silent `then null` is what hid all of the above.
    expect(body).not.toMatch(/exception when others then\s+null\s*;/i);
    expect(body).toMatch(/raise warning/);
  });
});
