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

  // Split the migration into individual statements so a failure on one CREATE
  // TABLE (e.g. a pre-existing partial schema) does not roll back the others.
  // Every statement is idempotent (IF NOT EXISTS / IF EXISTS), so re-runs are
  // safe. We execute each in its own implicit transaction.
  const statements = splitSqlStatements(sql);

  let applied = 0;
  const failed = [];
  try {
    await client.connect();
    for (const stmt of statements) {
      try {
        await client.query(stmt);
        applied++;
      } catch (err) {
        // Ignore "already exists" / "duplicate" errors — the statement is
        // idempotent but PG can still surface them for objects created by
        // concurrent runs. Anything else is logged and we continue.
        const msg = String(err.message || '');
        if (/already exists|duplicate|conflict/i.test(msg)) { applied++; continue; }
        failed.push(`${msg} [stmt: ${stmt.slice(0, 60)}...]`);
      }
    }
    logger.info(`✅ governance schema applied: ${applied}/${statements.length} statements ok` +
      (failed.length ? ` (${failed.length} skipped)` : ''));
    if (failed.length) {
      logger.warn(`governance schema skipped statements: ${failed.join(' | ').slice(0, 800)}`);
    }
  } catch (err) {
    logger.warn(`governance schema bootstrap skipped (connect/query error): ${err.message}`);
    logger.warn('Admin governance endpoints may return errors until 012_super_admin_governance.sql is applied.');
  } finally {
    try { await client.end(); } catch (_) {}
  }
}

// Split a multi-statement SQL string into individual statements, honouring
// dollar-quoted strings ($$...$$) and single-line/block comments so that
// semicolons inside function bodies are not treated as statement terminators.
function splitSqlStatements(sql) {
  const out = [];
  let buf = '';
  let i = 0;
  let inLineComment = false;
  let inBlockComment = false;
  let inDollar = false;
  let dollarTag = '';
  let inSingle = false;
  while (i < sql.length) {
    const ch = sql[i];
    const next = sql[i + 1] || '';
    if (inLineComment) { buf += ch; if (ch === '\n') inLineComment = false; i++; continue; }
    if (inBlockComment) { buf += ch; if (ch === '*' && next === '/') { buf += next; i += 2; inBlockComment = false; continue; } i++; continue; }
    if (inDollar) {
      buf += ch;
      if (ch === '$' && sql.slice(i + 1, i + 1 + dollarTag.length) === dollarTag && sql[i + 1 + dollarTag.length] === '$') {
        buf += dollarTag + '$';
        i += 2 + dollarTag.length;
        inDollar = false;
        dollarTag = '';
        continue;
      }
      i++; continue;
    }
    if (inSingle) { buf += ch; if (ch === "'") inSingle = false; i++; continue; }
    if (ch === '-' && next === '-') { inLineComment = true; buf += ch; i++; continue; }
    if (ch === '/' && next === '*') { inBlockComment = true; buf += ch + next; i += 2; continue; }
    if (ch === "'") { inSingle = true; buf += ch; i++; continue; }
    if (ch === '$') {
      const m = /^\$[A-Za-z_0-9]*\$/.exec(sql.slice(i));
      if (m) { inDollar = true; dollarTag = m[0].slice(1, -1); buf += m[0]; i += m[0].length; continue; }
    }
    if (ch === ';') {
      const stmt = buf.trim();
      if (stmt) out.push(stmt);
      buf = '';
      i++;
      continue;
    }
    buf += ch; i++;
  }
  const last = buf.trim();
  if (last) out.push(last);
  return out;
}

module.exports = { ensureGovernanceSchema };

