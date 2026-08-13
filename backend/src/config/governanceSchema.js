/**
 * Idempotent governance schema bootstrap.
 *
 * Ensures the Super Admin governance tables (admin_approvals, security_alerts,
 * admin_activity, security_settings) and login_history enrichment columns exist.
 * Runs at server startup. Uses the Supabase transaction pooler with the service
 * role token as the password (same connection backend/pg_migrate.js uses).
 *
 * The migration SQL uses CREATE TABLE IF NOT EXISTS / ADD COLUMN IF NOT EXISTS,
 * so repeated runs are safe no-ops. Failures are non-fatal: the server still
 * starts, and admin API endpoints degrade gracefully when tables are absent.
 */

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

let ran = false;

const POOLER_CONN =
  'postgresql://postgres.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55b2F1enFlenB4ZW9ubXJ4eGdpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDI4MjczNSwiZXhwIjoyMDg5ODU4NzM1fQ.zCX5ZMW42kwjszRmT6HREZOCjTs5z7ZlXidK4BM-coM@aws-0-us-east-1-975937489815.pooler.supabase.com:6543/postgres';

async function ensureGovernanceSchema() {
  if (ran) return;
  ran = true;

  const sqlPath = path.join(__dirname, '..', 'migrations', '012_super_admin_governance.sql');
  let sql;
  try {
    sql = fs.readFileSync(sqlPath, 'utf8');
  } catch (readErr) {
    logger.warn('governance schema: migration file not found, skipping bootstrap');
    return;
  }

  const connectionString = process.env.SUPABASE_DB_URL || POOLER_CONN;
  const client = new Client({ connectionString, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 15000 });
  try {
    await client.connect();
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');
    logger.info('✅ governance schema applied (admin_approvals, security_alerts, admin_activity, security_settings)');
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    logger.warn(`governance schema bootstrap skipped: ${err.message}`);
    logger.warn('Admin governance endpoints may return errors until 012_super_admin_governance.sql is applied.');
  } finally {
    try { await client.end(); } catch (_) {}
  }
}

module.exports = { ensureGovernanceSchema };

