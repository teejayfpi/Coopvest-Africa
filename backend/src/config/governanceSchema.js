/**
 * Idempotent startup schema bootstrap.
 *
 * Ensures the Super Admin governance tables (admin_approvals, security_alerts,
 * admin_activity, security_settings) and login_history enrichment columns exist,
 * and that the website contact enquiry queue (contact_messages) exists.
 * Runs at server startup. Uses the Supabase transaction pooler with the service
 * role token as the password (same connection backend/pg_migrate.js uses).
 *
 * The migration SQL uses CREATE TABLE IF NOT EXISTS / ADD COLUMN IF NOT EXISTS,
 * so repeated runs are safe no-ops. Failures are non-fatal: the server still
 * starts, and admin API endpoints degrade gracefully when tables are absent.
 *
 * NOTE: only the migrations listed in MIGRATIONS are applied here. Every other
 * migration in backend/migrations/ still has to be applied by hand, so a new
 * table that a route depends on will not exist in production just because its
 * SQL file was merged.
 */

// Applied on every boot. Add to this list only when the SQL is fully idempotent
// — it runs on production on each start, not once.
const MIGRATIONS = [
  '012_super_admin_governance.sql',
  // Without this the public /api/contact ingest cannot store an enquiry, so the
  // website contact form returns 502 and nothing is recorded anywhere.
  '049_contact_messages.sql',
];

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

let ran = false;

// Connection candidates, tried in order. The first that connects wins.
//
// The project's old connection strings referenced
// `aws-0-us-east-1-975937489815.pooler.supabase.com`, which is now NXDOMAIN —
// Supabase's pooler hostname dropped the account-number suffix. The current
// pooler host is `aws-0-us-east-1.pooler.supabase.com` (resolves to IPv4).
//
// Supabase pooler username conventions (we try both, since the repo has used
// each at different times):
//   - `postgres.<project-ref>` with the DB password as the password (current
//     Supabase dashboard format).
//   - `postgres.<DB_PASSWORD>` with no separate password (legacy format used
//     by backend/run_migration_now.js). The DB password is `Temiloluwa@1963`.
//
// 1. An explicit SUPABASE_DB_URL if provided (highest priority — lets the
//    operator override with any working connection string).
// 2. transaction pooler (port 6543) — project-ref username.
// 3. transaction pooler (port 6543) — password-as-username (legacy).
// 4. session pooler (port 5432) — project-ref username.
// 5. direct connection (db.<ref>.supabase.co:5432, IPv6 only) — bare `postgres`
//    user with the DB password.
const DB_PASSWORD = process.env.SUPABASE_DB_PASSWORD || 'Temiloluwa@1963';
const REF = 'nyoauzqezpxeonmrxxgi';
const POOLER_HOST = 'aws-0-us-east-1.pooler.supabase.com';
const CONNECTION_CANDIDATES = [
  `postgresql://postgres.${REF}:${encodeURIComponent(DB_PASSWORD)}@${POOLER_HOST}:6543/postgres`,
  `postgresql://${encodeURIComponent(`postgres.${DB_PASSWORD}`)}@${POOLER_HOST}:6543/postgres`,
  `postgresql://postgres.${REF}:${encodeURIComponent(DB_PASSWORD)}@${POOLER_HOST}:5432/postgres`,
  `postgresql://postgres:${encodeURIComponent(DB_PASSWORD)}@db.${REF}.supabase.co:5432/postgres`,
];

async function ensureGovernanceSchema() {
  if (ran) return;
  ran = true;

  const connectionString = process.env.SUPABASE_DB_URL;
  const candidates = connectionString ? [connectionString, ...CONNECTION_CANDIDATES] : CONNECTION_CANDIDATES;

  // One connection for every migration; the pooler handshake is the slow part.
  let client = null;
  let connectedWith = null;
  for (const cs of candidates) {
    const c = new Client({ connectionString: cs, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 12000 });
    try {
      await c.connect();
      client = c;
      connectedWith = cs.replace(/:[^:@]+@/, ':***@'); // mask password in logs
      break;
    } catch (err) {
      try { await c.end(); } catch (_) {}
      logger.warn(`governance schema: connection candidate failed: ${err.message}`);
    }
  }
  if (!client) {
    logger.warn('governance schema bootstrap skipped: could not connect to the database via any connection string');
    logger.warn(`Schema may be incomplete until these are applied by hand: ${MIGRATIONS.join(', ')}.`);
    return;
  }

  try {
    for (const name of MIGRATIONS) {
      await applyMigration(client, name);
    }
  } finally {
    try { await client.end(); } catch (_) {}
  }
}

/**
 * Apply one migration over an open client.
 *
 * governanceSchema.js lives in backend/src/config/, so the migrations dir is two
 * levels up: backend/migrations/. (A single '..' would resolve to
 * backend/src/migrations, which does not exist — this was the original bug that
 * silently skipped the bootstrap on every deploy.)
 */
async function applyMigration(client, name) {
  const sqlPath = path.join(__dirname, '..', '..', 'migrations', name);
  let sql;
  try {
    sql = fs.readFileSync(sqlPath, 'utf8');
  } catch (readErr) {
    logger.warn(`schema: migration ${name} not found, skipping`);
    return;
  }

  // Split the migration into individual statements so a failure on one CREATE
  // TABLE (e.g. a pre-existing partial schema) does not roll back the others.
  // Every statement is idempotent (IF NOT EXISTS / IF EXISTS), so re-runs are
  // safe. We execute each in its own implicit transaction.
  const statements = splitSqlStatements(sql);

  let applied = 0;
  const failed = [];
  logger.info(`schema: applying ${name} (${statements.length} statements)`);
  for (const stmt of statements) {
    try {
      await client.query(stmt);
      applied++;
    } catch (err) {
      const msg = String(err.message || '');
      if (/already exists|duplicate|conflict/i.test(msg)) { applied++; continue; }
      failed.push(`${msg} [stmt: ${stmt.replace(/\s+/g, ' ').slice(0, 60)}...]`);
    }
  }
  logger.info(`✅ schema ${name}: ${applied}/${statements.length} statements ok` +
    (failed.length ? ` (${failed.length} skipped)` : ''));
  if (failed.length) {
    logger.warn(`schema ${name} skipped statements: ${failed.join(' | ').slice(0, 800)}`);
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

module.exports = { ensureGovernanceSchema, runGovernanceDiagnostics };

// On-demand diagnostic runner (ignores the `ran` cache). Tries every connection
// candidate, applies each statement, and returns a structured result so the
// Super Admin can see exactly which connection worked and which statements
// failed. Used by the /api/admin/governance-bootstrap-debug endpoint.
async function runGovernanceDiagnostics() {
  const sqlPath = path.join(__dirname, '..', '..', 'migrations', '012_super_admin_governance.sql');
  let sql;
  try {
    sql = fs.readFileSync(sqlPath, 'utf8');
  } catch (e) {
    return { ok: false, error: 'migration file not found', detail: e.message };
  }
  const statements = splitSqlStatements(sql);
  const connectionString = process.env.SUPABASE_DB_URL;
  const candidates = connectionString ? [connectionString, ...CONNECTION_CANDIDATES] : CONNECTION_CANDIDATES;
  const attempts = [];
  let client = null;
  let usedCandidate = null;
  for (const cs of candidates) {
    const masked = cs.replace(/:[^:@]+@/, ':***@');
    const c = new Client({ connectionString: cs, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 12000 });
    try {
      await c.connect();
      attempts.push({ url: masked, ok: true });
      client = c;
      usedCandidate = masked;
      break;
    } catch (err) {
      attempts.push({ url: masked, ok: false, error: err.message });
      try { await c.end(); } catch (_) {}
    }
  }
  if (!client) {
    return { ok: false, error: 'no connection candidate succeeded', attempts };
  }
  const applied = [];
  const failed = [];
  const start = Date.now();
  try {
    for (const stmt of statements) {
      try {
        await client.query(stmt);
        applied.push(stmt.replace(/\s+/g, ' ').slice(0, 50));
      } catch (err) {
        const msg = String(err.message || '');
        if (/already exists|duplicate|conflict/i.test(msg)) { applied.push('(idempotent) ' + stmt.replace(/\s+/g, ' ').slice(0, 40)); continue; }
        failed.push({ error: msg, stmt: stmt.replace(/\s+/g, ' ').slice(0, 80) });
      }
    }
    return {
      ok: true,
      connectedVia: usedCandidate,
      attempts,
      statementCount: statements.length,
      appliedCount: applied.length,
      failedCount: failed.length,
      elapsedMs: Date.now() - start,
      applied: applied.slice(0, 50),
      failed: failed.slice(0, 20),
    };
  } finally {
    try { await client.end(); } catch (_) {}
  }
}

