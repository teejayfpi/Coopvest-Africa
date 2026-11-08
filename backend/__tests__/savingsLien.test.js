/**
 * The savings lien against an outstanding loan.
 *
 * `savings_move(..., 'withdraw')` checked only the wallet status and the savings
 * balance, never the member's loans. A borrower could move their whole savings
 * to the wallet and withdraw it, leaving the loan unsecured — while
 * `default_recovery_policy` clause 3 already told the member their savings could
 * be recovered. The published right existed; nothing enforced it.
 *
 * Migration 065 closes that. These tests pin the parts that can silently rot:
 *
 *   1. The migration exists and still replaces `savings_move`.
 *   2. The loan statuses it treats as live debt are a subset of the real
 *      vocabulary (the CHECK constraint from migration 039). An invented status
 *      such as 'disbursed' would make the guard silently miss real loans —
 *      exactly the class of bug that left `overdue` unwritable once.
 *   3. It is NOT listed in the deploy bootstrap's MIGRATIONS. It changes what
 *      members may do with their own money, so it is applied deliberately after
 *      sign-off. Adding it to that list ships the change on the next deploy;
 *      this test makes that a conscious edit rather than an accident.
 */

const fs = require('fs');
const path = require('path');

const migrationsDir = path.join(__dirname, '..', 'migrations');
const MIGRATION = '065_savings_lien_for_outstanding_loans.sql';
const migrationPath = path.join(migrationsDir, MIGRATION);

const migration = fs.readFileSync(migrationPath, 'utf8');

/** Strip `--` comment lines so assertions test SQL, not prose. */
const sqlOnly = migration
  .split('\n')
  .filter((line) => !line.trim().startsWith('--'))
  .join('\n');

/** The canonical loan status vocabulary, read from the 039 CHECK constraint. */
function canonicalLoanStatuses() {
  const src = fs.readFileSync(
    path.join(migrationsDir, '039_rollover_principal_70.sql'),
    'utf8',
  );
  const block = src.slice(src.indexOf("CHECK (status IN ("));
  const list = block.slice(block.indexOf('(') + 1, block.indexOf(')'));
  return new Set([...list.matchAll(/'([a-z_]+)'/g)].map((m) => m[1]));
}

/** The statuses the lien treats as live debt, from its IN (...) lists. */
function lienStatuses() {
  const lists = [...sqlOnly.matchAll(/status IN \(([^)]*)\)/g)].map((m) => m[1]);
  const out = new Set();
  for (const l of lists) for (const m of l.matchAll(/'([a-z_]+)'/g)) out.add(m[1]);
  return out;
}

describe('savings lien (migration 065)', () => {
  test('the migration replaces savings_move', () => {
    expect(sqlOnly).toMatch(
      /CREATE OR REPLACE FUNCTION public\.savings_move\s*\(/,
    );
  });

  test('the guard only applies to withdrawals, never deposits', () => {
    // The lien must sit in the withdraw branch. A blanket check would freeze
    // a member's ability to save while repaying, which is the opposite of what
    // the cooperative wants.
    const withdrawBranch = sqlOnly.slice(
      sqlOnly.indexOf('ELSE', sqlOnly.indexOf("IF p_direction = 'deposit'")),
    );
    expect(withdrawBranch).toContain('v_lien');
    const depositBranch = sqlOnly.slice(
      sqlOnly.indexOf("IF p_direction = 'deposit'"),
      sqlOnly.indexOf('ELSE', sqlOnly.indexOf("IF p_direction = 'deposit'")),
    );
    expect(depositBranch).not.toContain('v_lien');
  });

  test('every status it counts is a real loan status', () => {
    const canonical = canonicalLoanStatuses();
    expect(canonical.size).toBeGreaterThan(0); // guards the parser itself
    for (const status of lienStatuses()) {
      expect(canonical).toContain(status);
    }
  });

  test('it counts exactly the live-debt statuses', () => {
    // Settlement and dead applications must not hold a member's savings:
    //   pending / under_review — not disbursed, so no debt exists yet
    //   completed / rejected / cancelled — settled or dead
    //   rolled_over — settled by a refinance; the successor loan counts instead
    // Counting 'rolled_over' too would double the lien on a refinanced member.
    expect([...lienStatuses()].sort()).toEqual([
      'active',
      'approved',
      'defaulted',
      'in_recovery',
      'overdue',
      'repaying',
    ]);
  });

  test('it is not applied automatically by the deploy bootstrap', () => {
    const bootstrap = fs.readFileSync(
      path.join(__dirname, '..', 'src', 'config', 'governanceSchema.js'),
      'utf8',
    );
    const block = bootstrap.slice(
      bootstrap.indexOf('const MIGRATIONS = ['),
      bootstrap.indexOf('];', bootstrap.indexOf('const MIGRATIONS = [')),
    );
    expect(block).not.toContain(MIGRATION);
    // When the policy is approved, add the name to that list AND delete this
    // test — the change then ships on the next deploy.
  });
});
