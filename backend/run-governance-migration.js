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

// Reuse the same connection as pg_migrate.js (project pooler + service role).
const connectionString =
  process.env.SUPABASE_DB_URL ||
  'postgresql://postgres.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55b2F1enFlenB4ZW9ubXJ4eGdpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDI4MjczNSwiZXhwIjoyMDg5ODU4NzM1fQ.zCX5ZMW42kwjszRmT6HREZOCjTs5z7ZlXidK4BM-coM@db.nyoauzqezpxeonmrxxgi.supabase.co:5432/postgres';

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
