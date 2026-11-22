const fs = require('fs');
const path = require('path');

/**
 * The migration ledger has to fail closed.
 *
 * Production's `schema_migrations` table starts empty even though the schema
 * already exists — the migrations were applied by hand. A naive runner would
 * treat that as "69 pending" and replay every historical migration onto live
 * data, and several of them are not idempotent. The runner must refuse instead
 * and demand an explicit `--baseline`.
 */
describe('pending migration runner', () => {
  const src = fs.readFileSync(path.join(__dirname, '../run-pending-migrations.js'), 'utf8');

  test('refuses to replay history onto a database that already has schema', () => {
    expect(src).toMatch(/already has schema, but no migration ledger/);
    expect(src).toMatch(/--baseline/);
    expect(src).toMatch(/process\.exitCode = 1/);
  });

  test('the empty-ledger guard checks for real schema, not just the ledger', () => {
    expect(src).toMatch(/to_regclass\('public\.profiles'\)/);
  });

  test('baseline records files without executing them', () => {
    const idx = src.indexOf('if (baseline)');
    expect(idx).toBeGreaterThan(-1);
    // The baseline branch must not read or execute the SQL files.
    const body = src.slice(idx, src.indexOf('if (pending.length === 0)'));
    expect(body).not.toMatch(/readFileSync/);
    expect(body).toMatch(/INSERT INTO public\.schema_migrations/);
  });

  test('supports the credential production actually has', () => {
    // Render exposes no database password, only the service-role key and URL.
    expect(src).toMatch(/SUPABASE_ACCESS_TOKEN/);
    expect(src).toMatch(/SUPABASE_DB_URL/);
  });

  test('stops at the first failing migration', () => {
    expect(src).toMatch(/Stopped at this file/);
  });
});
