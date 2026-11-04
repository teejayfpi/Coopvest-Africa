/**
 * Tests for the admin wallet operations the dashboard has always called but
 * the API never served: freeze/unfreeze, balance adjustment, and the list
 * shape the Wallet Management page reads.
 *
 * The adjustment moves member money, so these check the guards as much as the
 * happy path. The balance itself is computed inside the SQL function under a
 * row lock; the assertions on it are structural, since there is no database in
 * a unit test.
 */

const fs = require('fs');
const path = require('path');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
const adminApi = read('src/routes/adminApi.js');
const migration = read('migrations/060_admin_wallet_operations.sql');
// The dashboard lives in a sibling repository, which a single-repo CI checkout
// does not have. Reading it unconditionally made this suite fail to load there
// (ENOENT at require time), which is why it never ran in CI. Read it when it is
// present and skip the assertions that need it otherwise — the API and SQL
// assertions above do not depend on it.
const DASHBOARD_PAGE = path.join(
  __dirname, '..', '..', '..', 'Admin-Dashboard', 'src', 'pages', 'wallet-management', 'index.tsx'
);
const page = fs.existsSync(DASHBOARD_PAGE) ? fs.readFileSync(DASHBOARD_PAGE, 'utf8') : null;
const describeWithPage = page ? describe : describe.skip;

describe('wallet routes exist', () => {
  it('serves PATCH /wallets/:id/status', () => {
    expect(adminApi).toContain("router.patch('/wallets/:id/status'");
  });

  it('serves POST /wallets/:id/adjust', () => {
    expect(adminApi).toContain("router.post('/wallets/:id/adjust'");
  });

  it('serves GET /wallets/stats before the :id routes', () => {
    const statsAt = adminApi.indexOf("router.get('/wallets/stats'");
    const statusAt = adminApi.indexOf("router.patch('/wallets/:id/status'");
    expect(statsAt).toBeGreaterThan(-1);
    // Registered first, or `/wallets/stats` would be matched as a wallet id.
    expect(statsAt).toBeLessThan(statusAt);
  });

  it('rejects a status the column does not allow', () => {
    expect(adminApi).toContain("['active', 'frozen', 'suspended'].includes(status)");
  });

  it('rejects a zero adjustment before calling the database', () => {
    const route = adminApi.slice(adminApi.indexOf("router.post('/wallets/:id/adjust'"));
    expect(route).toContain('amount === 0');
    expect(route).toContain('Number.isFinite(amount)');
  });
});

describe('wallet list shape', () => {
  it('returns the flattened fields the dashboard page reads', () => {
    const route = adminApi.slice(adminApi.indexOf("router.get('/wallets'"), adminApi.indexOf("router.get('/wallets/stats'"));
    for (const key of ['data:', 'total:', 'wallets,']) {
      expect(route).toContain(key);
    }
  });

  it('still returns `wallets`, which the Manual Deposits screen reads', () => {
    expect(adminApi).toContain('wallets,');
  });

  it('maps the member name and email the table renders', () => {
    const route = adminApi.slice(adminApi.indexOf("router.get('/wallets'"), adminApi.indexOf("router.get('/wallets/stats'"));
    expect(route).toContain('userName');
    expect(route).toContain('userEmail');
    expect(route).toContain('status: w.status');
  });

  it('treats a search with no matching member as no wallets, not all wallets', () => {
    const route = adminApi.slice(adminApi.indexOf("router.get('/wallets'"), adminApi.indexOf("router.get('/wallets/stats'"));
    expect(route).toContain('00000000-0000-0000-0000-000000000000');
  });
});

describe('balance adjustment SQL guards', () => {
  it('locks the wallet row before reading the balance', () => {
    const fn = migration.slice(migration.indexOf('FUNCTION public.admin_adjust_wallet_balance'));
    expect(fn).toContain('FOR UPDATE');
  });

  it('computes the new balance in SQL, not from a value passed in', () => {
    const fn = migration.slice(migration.indexOf('FUNCTION public.admin_adjust_wallet_balance'));
    expect(fn).toContain('v_balance_after  := v_balance_before + p_amount');
    expect(fn).not.toContain('p_balance_after');
  });

  it('requires a reason, so every movement is auditable', () => {
    const fn = migration.slice(migration.indexOf('FUNCTION public.admin_adjust_wallet_balance'));
    expect(fn).toContain('A reason of at least 3 characters is required');
  });

  it('refuses to take a balance negative', () => {
    const fn = migration.slice(migration.indexOf('FUNCTION public.admin_adjust_wallet_balance'));
    expect(fn).toContain('v_balance_after < 0');
    expect(fn).toContain('negative');
  });

  it('refuses to move money on a frozen or suspended wallet', () => {
    const fn = migration.slice(migration.indexOf('FUNCTION public.admin_adjust_wallet_balance'));
    expect(fn).toContain("v_wallet.status <> 'active'");
  });

  it('rejects a zero amount in the database too, not only in the route', () => {
    const fn = migration.slice(migration.indexOf('FUNCTION public.admin_adjust_wallet_balance'));
    expect(fn).toContain('p_amount = 0');
  });

  it('records the movement as a transaction and an audit entry', () => {
    const fn = migration.slice(migration.indexOf('FUNCTION public.admin_adjust_wallet_balance'));
    expect(fn).toContain('INSERT INTO public.transactions');
    expect(fn).toContain('INSERT INTO public.audit_logs');
    expect(fn).toContain("'adjustment'");
  });

  it('adds the status column the page filters on', () => {
    expect(migration).toContain('ADD COLUMN IF NOT EXISTS status');
    expect(migration).toContain('wallets_status_check');
  });
});

describeWithPage('dashboard page', () => {
  it('reads the stats endpoint for its summary cards', () => {
    expect(page).toContain('/api/admin/wallets/stats');
    expect(page).toContain('wallet-stats');
  });

  it('refreshes the summary cards after a freeze or an adjustment', () => {
    expect(page.match(/invalidateQueries\(\{ queryKey: \["wallet-stats"\] \}\)/g)).toHaveLength(2);
  });

  it('does not print a fake currency figure for a wallet with no history', () => {
    expect(page).toContain('lastTransactionAmount == null');
  });
});
