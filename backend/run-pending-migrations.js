/**
 * Apply pending migrations from ./migrations, in filename order.
 *
 * Why this exists: `pg_migrate.js` creates one table and stops, and nothing in
 * this repository applied `migrations/*.sql`. The files were applied by hand
 * against production, so whether a fresh environment had them depended on
 * someone remembering. That is how 065–072 came to be live in production while
 * being absent from any automatic path — a fresh clone would have been missing
 * the entire money-path fix set, silently.
 *
 * Records what has run in `schema_migrations`, so re-running is a no-op and a
 * gap is visible rather than assumed.
 *
 * Usage:
 *   node run-pending-migrations.js --dry-run    # show what would run
 *   node run-pending-migrations.js --baseline   # record current files as
 *                                               # applied WITHOUT running them
 *   node run-pending-migrations.js              # apply pending files
 *
 * Connection: SUPABASE_DB_URL / DATABASE_URL (pg), or SUPABASE_ACCESS_TOKEN
 * (Supabase Management API, which is the only credential this deployment
 * actually has). Never hardcode a credential here.
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');

const dryRun = process.argv.includes('--dry-run');
const baseline = process.argv.includes('--baseline');
const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

const LEDGER_DDL = `
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  filename    TEXT PRIMARY KEY,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  checksum    TEXT
);
`;

function migrationFiles() {
  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
}

/**
 * Build a query runner.
 *
 * Two transports because production has no database password in its
 * environment: Render exposes only the service-role key and the project URL.
 * The Management API accepts the personal access token, so it is the path that
 * actually works there. `pg` is used when a direct URL is available, which is
 * what a developer machine or CI will have.
 */
function makeRunner() {
  const dbUrl = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (dbUrl) {
    const { Client } = require('pg');
    const client = new Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
    return {
      label: 'pg (SUPABASE_DB_URL)',
      async connect() { await client.connect(); },
      async query(sql) { return (await client.query(sql)).rows; },
      async close() { await client.end(); },
    };
  }

  const token = process.env.SUPABASE_ACCESS_TOKEN;
  const projectRef = process.env.SUPABASE_PROJECT_REF
    || (process.env.SUPABASE_URL || '').match(/https:\/\/([a-z0-9]+)\.supabase\.co/)?.[1];
  if (token && projectRef) {
    const run = async (sql) => {
      const res = await fetch(
        `https://api.supabase.com/v1/projects/${projectRef}/database/query`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ query: sql }),
        },
      );
      const text = await res.text();
      if (!res.ok) throw new Error(`${res.status}: ${text.slice(0, 400)}`);
      try { return JSON.parse(text); } catch { return []; }
    };
    return {
      label: `Supabase Management API (project ${projectRef})`,
      async connect() {},
      // The Management API has no client-side transactions; each batch is its
      // own unit, which is why migrations must stay idempotent.
      async query(sql) { return run(sql); },
      async close() {},
    };
  }

  throw new Error(
    'No database connection configured.\n'
    + 'Set SUPABASE_DB_URL (pooler connection string) or SUPABASE_ACCESS_TOKEN.',
  );
}

async function main() {
  const db = makeRunner();
  await db.connect();
  console.log(`Connection: ${db.label}`);

  try {
    await db.query(LEDGER_DDL);
    const rows = await db.query('SELECT filename FROM public.schema_migrations');
    const applied = new Set((rows || []).map((r) => r.filename));

    const files = migrationFiles();

    // A ledger that is empty against a database that already has schema means
    // these migrations were applied by hand before the ledger existed. Running
    // them again would replay every historical migration onto live data, and
    // several are not idempotent. Refuse, and ask for an explicit baseline
    // rather than guessing.
    if (applied.size === 0) {
      const existing = await db.query(
        "SELECT to_regclass('public.profiles') IS NOT NULL AS present",
      );
      const hasSchema = existing?.[0]?.present === true;
      if (hasSchema && !baseline) {
        console.error(
          '\nThis database already has schema, but no migration ledger.\n'
          + 'That means the migrations were applied before the ledger existed.\n\n'
          + 'Replaying all of them onto live data is not safe. Choose one:\n'
          + '  --baseline   record the current files as applied, without running them\n'
          + '               (correct if this database is up to date)\n'
          + '  --dry-run    only list what is pending\n',
        );
        process.exitCode = 1;
        return;
      }
    }

    const pending = files.filter((f) => !applied.has(f));
    console.log(`${files.length} migration file(s), ${applied.size} recorded as applied.`);

    if (baseline) {
      if (dryRun) {
        console.log(`\n--dry-run with --baseline: would record ${pending.length} file(s) as applied.`);
        return;
      }
      for (const file of pending) {
        await db.query(
          `INSERT INTO public.schema_migrations (filename) VALUES ('${file.replace(/'/g, "''")}')`
          + ' ON CONFLICT (filename) DO NOTHING',
        );
      }
      console.log(`Baselined ${pending.length} file(s) as applied (nothing executed).`);
      return;
    }

    if (pending.length === 0) {
      console.log('Nothing pending.');
      return;
    }

    console.log(`\nPending (${pending.length}):`);
    pending.forEach((f) => console.log(`  ${f}`));

    if (dryRun) {
      console.log('\n--dry-run: nothing applied.');
      return;
    }

    for (const file of pending) {
      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
      process.stdout.write(`\nApplying ${file} ... `);
      try {
        await db.query(sql);
        await db.query(
          `INSERT INTO public.schema_migrations (filename) VALUES ('${file.replace(/'/g, "''")}')`
          + ' ON CONFLICT (filename) DO NOTHING',
        );
        console.log('ok');
      } catch (err) {
        console.error(`FAILED\n  ${err.message}`);
        console.error('\nStopped at this file. Earlier files remain applied.');
        process.exitCode = 1;
        return;
      }
    }
    console.log('\nDone.');
  } finally {
    await db.close();
  }
}

main().catch((err) => {
  console.error('Migration runner:', err.message);
  process.exit(1);
});
