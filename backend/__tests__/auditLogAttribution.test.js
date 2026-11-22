const fs = require('fs');
const path = require('path');

jest.mock('../src/config/supabase', () => {
  const inserts = [];
  return {
    __inserts: inserts,
    from: () => ({
      insert: async (row) => {
        inserts.push(row);
        return { error: null };
      },
    }),
  };
});

const supabase = require('../src/config/supabase');
const { auditFor, logAction } = require('../src/lib/auditLog');

const req = (overrides = {}) => ({
  user: { id: 'f7fb1fd8-a49b-472e-9f84-1848d8eca29a', role: 'super_admin' },
  headers: { 'user-agent': 'jest', 'x-forwarded-for': '203.0.113.9, 10.0.0.1' },
  ip: '10.0.0.1',
  body: { password: 'must-not-be-stored' },
  ...overrides,
});

beforeEach(() => {
  supabase.__inserts.length = 0;
});

describe('audit writes attribute the actor', () => {
  it('records the actor from the request', async () => {
    await auditFor(req())('LOAN_APPROVED', { model: 'Loan', id: 'abc' }, { amount: 5000 });

    const row = supabase.__inserts[0];
    expect(row.actor_id).toBe('f7fb1fd8-a49b-472e-9f84-1848d8eca29a');
    expect(row.actor_role).toBe('super_admin');
    expect(row.action).toBe('LOAN_APPROVED');
    expect(row.target_model).toBe('Loan');
    expect(row.target_id).toBe('abc');
  });

  it('writes both column families so either reader works', async () => {
    await auditFor(req())('KYC_VERIFIED', { model: 'KYC', id: 'k1', profileId: 'p1' });

    const row = supabase.__inserts[0];
    expect(row.resource).toBe('KYC');
    expect(row.resource_id).toBe('k1');
    expect(row.target_profile_id).toBe('p1');
    expect(row.metadata.source).toBe('admin-web');
    expect(row.details.source).toBe('admin-web');
  });

  it('records the client ip and user agent, taking the first forwarded hop', async () => {
    await auditFor(req())('SYSTEM_SETTING_UPDATED', { model: 'SystemSetting', id: 'x' });

    const row = supabase.__inserts[0];
    expect(row.ip_address).toBe('203.0.113.9');
    expect(row.user_agent).toBe('jest');
  });

  it('never stores the request body', async () => {
    await auditFor(req())('MEMBER_PASSWORD_RESET', { model: 'Profile', id: 'p1' });

    const serialised = JSON.stringify(supabase.__inserts[0]);
    expect(serialised).not.toContain('must-not-be-stored');
  });

  it('accepts a bare string target', async () => {
    await auditFor(req())('WALLET_STATUS_CHANGED', 'wallets', { status: 'frozen' });

    const row = supabase.__inserts[0];
    expect(row.target_model).toBe('wallets');
    expect(row.resource).toBe('wallets');
  });

  it('warns instead of silently writing a null actor', async () => {
    const warn = jest.spyOn(require('../src/utils/logger'), 'warn').mockImplementation(() => {});
    await logAction(null, 'ORPHAN_ACTION', null, {});

    expect(supabase.__inserts[0].actor_id).toBeNull();
    expect(warn).toHaveBeenCalledWith(expect.stringContaining('without an actor'));
    warn.mockRestore();
  });

  it('does not throw when the insert fails', async () => {
    const broken = jest.spyOn(supabase, 'from').mockReturnValue({
      insert: async () => ({ error: new Error('db down') }),
    });
    const warn = jest.spyOn(require('../src/utils/logger'), 'warn').mockImplementation(() => {});

    await expect(auditFor(req())('LOAN_APPROVED', { model: 'Loan', id: 'x' })).resolves.toBeUndefined();
    expect(warn).toHaveBeenCalled();

    broken.mockRestore();
    warn.mockRestore();
  });
});

/**
 * The bug this guards: `logAdminAction(action, target, metadata, req)` took the
 * request as an optional fourth argument, and 44 of 60 call sites omitted it, so
 * 174 of 200 audit rows had a null actor. Nothing failed — the writes succeeded
 * with `actor_id: NULL`. These tests fail if that shape comes back.
 */
describe('no route calls an audit logger that can lose the actor', () => {
  const routesDir = path.join(__dirname, '..', 'src', 'routes');
  const routeFiles = fs
    .readdirSync(routesDir)
    .filter((f) => f.endsWith('.js'))
    .map((f) => ({ name: f, src: fs.readFileSync(path.join(routesDir, f), 'utf8') }));

  it('there is exactly one audit implementation', () => {
    const definitions = routeFiles.filter((f) =>
      /function\s+logAdminAction\s*\(/.test(f.src)
    );
    expect(definitions.map((f) => f.name)).toEqual([]);
  });

  it('no route defines its own actor-less audit writer', () => {
    // A local helper that hardcodes `actor_id: null` is the same defect wearing
    // a different name (kycAdmin did exactly this).
    const offenders = routeFiles
      .filter((f) => /actor_id:\s*null/.test(f.src))
      .map((f) => f.name);
    expect(offenders).toEqual([]);
  });

  it('every audit call site binds the request', () => {
    const offenders = [];
    for (const file of routeFiles) {
      const lines = file.src.split('\n');
      lines.forEach((line, idx) => {
        if (/logAction\(|auditFor\(/.test(line)) {
          // auditFor(req) / logAction(req, ... are fine; logAction( with any
          // other first argument is not.
          if (/logAction\(/.test(line) && !/logAction\(\s*req\b/.test(line)) {
            offenders.push(`${file.name}:${idx + 1}`);
          }
          if (/auditFor\(/.test(line) && !/auditFor\(\s*req\b/.test(line)) {
            offenders.push(`${file.name}:${idx + 1}`);
          }
        }
      });
    }
    expect(offenders).toEqual([]);
  });
});
