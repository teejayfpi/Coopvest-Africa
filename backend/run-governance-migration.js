/**
 * One-off runner: applies 012_super_admin_governance.sql to the live Supabase
 * database using the same pooled connection that pg_migrate.js uses.
 *
 * Usage: node backend/run-governance-migration.js
 *
 * The connection string mirrors backend/pg_migrate.js (service role token as
 * password against the Supabase transaction pooler). It is idempotent, so it is
 * safe to run repeatedly and on every deploy.
 */
require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// Reuse the same connection as pg_migrate.js (project pooler + database
// password), supplied by the environment.
//
// A live connection string containing the service-role key used to be the
// fallback here, which committed the project's master credential to git in
// plain text. There is no fallback now: a migration that cannot find its
// connection string should stop, not silently use a hardcoded one.
const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

if (!connectionString) {
  console.error(
    'Missing SUPABASE_DB_URL.\n'
    + 'Set it to the Supabase pooler connection string before running migrations.\n'
    + 'Never hardcode credentials here — this repository is tracked in git.',
  );
  process.exit(1);
}

async function run() {
  const sqlPath = path.join(__dirname, 'migrations', '012_super_admin_governance.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  const client = new Client({ connectionString, ssl: { rejectUnauthorized: false } });
  await client.connect();
  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');
    console.log('✅ governance migration applied');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ governance migration failed:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

run().catch((e) => { console.error('Fatal:', e.message); process.exitCode = 1; });
