/**
 * The startup bootstrap is the only path that applies SQL automatically, and it
 * fails quietly by design — the server must still start if the database is
 * unreachable. That makes two mistakes easy to ship unnoticed:
 *
 *   1. A migration listed in MIGRATIONS that is not in the repository. The
 *      bootstrap logs "not found, skipping" and the schema it describes never
 *      exists. Coopvest-Africa listed 012_super_admin_governance.sql without
 *      carrying the file, so its governance tables were never created there.
 *   2. A credential in the source. `governanceSchema.js` held the production
 *      database password as a fallback, which both leaked it and shadowed a
 *      rotated password on any deployment that lost the env var.
 */

const fs = require('fs');
const path = require('path');

const backendRoot = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(backendRoot, 'src/config/governanceSchema.js'), 'utf8');

/** The migration names the bootstrap applies, in order. */
function listedMigrations() {
  const block = source.slice(source.indexOf('const MIGRATIONS = ['), source.indexOf('];', source.indexOf('const MIGRATIONS = [')));
  return [...block.matchAll(/'([0-9]{3}_[a-z_]+\.sql)'/g)].map((m) => m[1]);
}

describe('every listed migration exists', () => {
  test('the MIGRATIONS list is not empty (guards the parser itself)', () => {
    expect(listedMigrations().length).toBeGreaterThan(0);
  });

  test.each(listedMigrations())('%s is present in migrations/', (name) => {
    expect(fs.existsSync(path.join(backendRoot, 'migrations', name))).toBe(true);
  });

  test('a missing migration is logged as an error, not a warning', () => {
    // It means the schema is incomplete, which is a bug — not a transient
    // condition like an unreachable database.
    expect(source).toContain('is listed in MIGRATIONS but not found');
    expect(source).toMatch(/logger\.error\(`schema: migration \$\{name\} is listed/);
  });
});

describe('no credential is embedded in the source', () => {
  test('the database password is read from the environment only', () => {
    expect(source).toContain('const DB_PASSWORD = process.env.SUPABASE_DB_PASSWORD;');
    // No `|| 'something'` fallback, which would be a live credential.
    expect(source).not.toMatch(/DB_PASSWORD\s*=\s*process\.env\.SUPABASE_DB_PASSWORD\s*\|\|/);
  });

  test('no password or token literal appears in the file', () => {
    expect(source).not.toMatch(/Temiloluwa/i);
    expect(source).not.toMatch(/postgresql:\/\/[^'`\s]*:[^'`\s@$]{6,}@/);
    expect(source).not.toMatch(/(ghp_|sbp_|vcp_|rnd_)[A-Za-z0-9]{20,}/);
  });

  test('a missing credential skips the bootstrap with a clear message', () => {
    expect(source).toContain('governance schema bootstrap skipped: set SUPABASE_DB_URL or SUPABASE_DB_PASSWORD');
  });
});

describe('the wider repository carries no plaintext password', () => {
  test('no tracked source file contains the retired database password', () => {
    // Reads the files directly rather than shelling out, so this is portable.
    const roots = [path.join(backendRoot, 'src'), path.join(backendRoot, 'migrations')];
    const offenders = [];
    const walk = (dir) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (/\.(js|sql|json|yml|yaml)$/.test(entry.name) && fs.readFileSync(full, 'utf8').match(/Temiloluwa/i)) {
          offenders.push(full);
        }
      }
    };
    roots.forEach(walk);
    expect(offenders).toEqual([]);
  });
});
