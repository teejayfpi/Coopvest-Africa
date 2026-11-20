/**
 * One phone number, one member — the HTTP surface.
 *
 * The rule has three layers and this file covers the two the API owns:
 *
 *   * GET /auth/phone-availability — what the sign-up form calls before it
 *     creates an auth user, so a duplicate is caught while the member is still
 *     on the phone field;
 *   * POST /auth/register — the guard that runs even when a client skips the
 *     pre-check, and the shared wording so the member sees one sentence.
 *
 * The third layer is the unique index on profiles.phone_normalized (migration
 * 066). It cannot be exercised here; it is what makes the rule hold when two
 * requests race past both checks above. `findPhoneOwner` itself, including its
 * pre-migration fallback, is covered in phoneRegistry.test.js.
 */

const request = require('supertest');
const express = require('express');

// The profiles lookup. Answers with whatever the current test says the number
// owns; `columnMissing` models the database before migration 066.
jest.mock('../src/config/supabase', () => {
  const state = { owner: null, columnMissing: false, queries: [], upsertError: null, ownerSequence: null };

  const makeQuery = (table) => {
    const q = { table, filters: [] };
    const chain = () => q;

    const answer = () => {
      const usesNormalized = q.filters.some(([kind, col]) => kind === 'eq' && col === 'phone_normalized');
      if (usesNormalized && state.columnMissing) {
        return { data: null, error: { code: '42703', message: 'column profiles.phone_normalized does not exist' } };
      }
      if (state.upsertError) return { data: null, error: state.upsertError };
      // A test can model the race: free when the pre-check runs, taken by the
      // time signUp has failed, so only the error handler sees the owner.
      if (state.ownerSequence && state.ownerSequence.length) {
        const next = state.ownerSequence.shift();
        return { data: next, error: null };
      }
      const listQuery = q.filters.some(([kind]) => kind === 'in');
      return { data: listQuery ? (state.owner ? [state.owner] : []) : state.owner, error: null };
    };

    Object.assign(q, {
      select: chain,
      eq: (col, val) => { q.filters.push(['eq', col, val]); return q; },
      in: (col, val) => { q.filters.push(['in', col, val]); return q; },
      update: chain,
      insert: chain,
      upsert: chain,
      limit: chain,
      order: chain,
      range: chain,
      single: () => Promise.resolve(answer()),
      maybeSingle: () => Promise.resolve(answer()),
      then: (resolve) => resolve(answer()),
    });

    state.queries.push(q);
    return q;
  };

  return {
    __state: state,
    from: makeQuery,
    auth: { admin: { deleteUser: jest.fn(), updateUserById: jest.fn() } },
  };
});

// Register signs up through a throwaway client built from the SDK directly, so
// that seam has to be mocked at the package boundary.
jest.mock('@supabase/supabase-js', () => {
  const auth = {
    signUp: jest.fn(),
    admin: { deleteUser: jest.fn(), updateUserById: jest.fn() },
  };
  return { __auth: auth, createClient: () => ({ auth }) };
});

jest.mock('../src/middleware/auth', () => ({
  authenticate: (req, _res, next) => {
    req.user = { id: 'caller-profile', user_id: 'caller-user', role: 'member', phone: '08011112222' };
    next();
  },
  decodeSessionId: () => null,
  requireAdmin: (req, _res, next) => {
    req.user = { id: 'admin-profile', role: 'super_admin', email: 'admin@example.com' };
    next();
  },
}));

jest.mock('../src/services/referralService', () => ({ attributeReferral: jest.fn() }));
jest.mock('../src/lib/activationGate', () => ({ gateStatusFor: () => ({ canProceed: true }) }));

const supabase = require('../src/config/supabase');
const { __auth: authSdk } = require('@supabase/supabase-js');
const authRouter = require('../src/routes/auth');
const adminRouter = require('../src/routes/adminApi');
const { PHONE_TAKEN_MESSAGE } = require('../src/lib/phoneRegistry');

const state = supabase.__state;

const app = express();
app.use(express.json());
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/admin', adminRouter);

beforeEach(() => {
  state.owner = null;
  state.columnMissing = false;
  state.queries.length = 0;
  state.upsertError = null;
  state.ownerSequence = null;
  authSdk.signUp.mockReset();
  authSdk.admin.deleteUser.mockReset();
});

const TAKEN = 'This phone number has already been used to register';

describe('GET /auth/phone-availability', () => {
  test('reports a free number as available', async () => {
    const res = await request(app).get('/api/v1/auth/phone-availability').query({ phone: '08099998888' });

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ success: true, available: true });
  });

  test('reports a taken number as unavailable, in the shared wording', async () => {
    state.owner = { id: 'someone-else', email: 'other@example.com' };

    const res = await request(app).get('/api/v1/auth/phone-availability').query({ phone: '08099998888' });

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ available: false, code: 'PHONE_ALREADY_REGISTERED' });
    expect(res.body.error).toContain(TAKEN);
  });

  test('never discloses who holds the number', async () => {
    state.owner = { id: 'someone-else', email: 'other@example.com' };

    const res = await request(app).get('/api/v1/auth/phone-availability').query({ phone: '08099998888' });

    expect(JSON.stringify(res.body)).not.toContain('other@example.com');
    expect(JSON.stringify(res.body)).not.toContain('someone-else');
  });

  test('0703... and +234703... resolve to the same lookup key', async () => {
    state.owner = { id: 'someone-else', email: 'other@example.com' };

    const local = await request(app).get('/api/v1/auth/phone-availability').query({ phone: '07038193753' });
    const intl = await request(app).get('/api/v1/auth/phone-availability').query({ phone: '+2347038193753' });

    expect(local.body.available).toBe(false);
    expect(intl.body.available).toBe(false);

    const keys = state.queries
      .flatMap((q) => q.filters)
      .filter(([kind, col]) => kind === 'eq' && col === 'phone_normalized')
      .map(([, , val]) => val);
    expect(keys).toEqual(['7038193753', '7038193753']);
  });

  test('rejects a number that is not a Nigerian mobile', async () => {
    const res = await request(app).get('/api/v1/auth/phone-availability').query({ phone: '12345' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/valid Nigerian mobile number/);
  });

  test('requires a number', async () => {
    const res = await request(app).get('/api/v1/auth/phone-availability');
    expect(res.status).toBe(400);
  });

  test('still answers before migration 066 adds phone_normalized', async () => {
    state.columnMissing = true;
    state.owner = { id: 'someone-else', email: 'other@example.com' };

    const res = await request(app).get('/api/v1/auth/phone-availability').query({ phone: '07038193753' });

    expect(res.status).toBe(200);
    expect(res.body.available).toBe(false);
  });
});

describe('POST /auth/register refuses a number that is already registered', () => {
  const body = {
    email: 'new@example.com',
    name: 'New Member',
    password: 'password123',
    phone: '07038193753',
  };

  test('returns 409 and never creates the auth user', async () => {
    state.owner = { id: 'someone-else', email: 'other@example.com' };

    const res = await request(app).post('/api/v1/auth/register').send(body);

    expect(res.status).toBe(409);
    expect(res.body).toMatchObject({ code: 'PHONE_ALREADY_REGISTERED' });
    expect(res.body.error).toContain(TAKEN);
    expect(authSdk.signUp).not.toHaveBeenCalled();
  });

  test('rejects an invalid number before touching the database', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ ...body, phone: '12345' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/valid Nigerian mobile number/);
    expect(authSdk.signUp).not.toHaveBeenCalled();
  });

  test('a signUp rejected by the phone trigger returns the same 409', async () => {
    // With migration 066 applied, handle_new_user() runs as an AFTER INSERT
    // trigger on auth.users, so a duplicate makes signUp itself fail with an
    // opaque message. The member must still read the shared sentence.
    // First lookup (the pre-check) sees the number free; the second, made after
    // signUp fails, sees the member who won the race.
    state.ownerSequence = [null, { id: 'someone-else', email: 'other@example.com' }];
    authSdk.signUp.mockResolvedValue({
      data: { user: null, session: null },
      error: { message: 'Database error saving new user' },
    });

    const res = await request(app).post('/api/v1/auth/register').send({
      email: 'fresh@example.com',
      phone: '07038193753',
      name: 'Fresh Member',
      password: 'Str0ngPassw0rd!',
    });

    expect(res.status).toBe(409);
    expect(res.body.code).toBe('PHONE_ALREADY_REGISTERED');
    expect(res.body.error).toBe(PHONE_TAKEN_MESSAGE);
  });

  test('stores the number in one canonical form', async () => {
    authSdk.signUp.mockResolvedValue({
      data: { user: { id: 'new-auth-id', email: body.email, user_metadata: {} }, session: null },
      error: null,
    });

    await request(app).post('/api/v1/auth/register').send(body);

    const payload = authSdk.signUp.mock.calls[0][0];
    expect(payload.options.data.phone).toBe('+2347038193753');
  });
});

describe('POST /auth/sync will not move an account onto a taken number', () => {
  test('rejects a number held by another member', async () => {
    state.owner = { id: 'someone-else', email: 'other@example.com' };

    const res = await request(app)
      .post('/api/v1/auth/sync')
      .send({ phone: '07038193753', name: 'Caller' });

    expect(res.status).toBe(409);
    expect(res.body.code).toBe('PHONE_ALREADY_REGISTERED');
  });

  test('allows a member to keep their own number', async () => {
    // The caller already holds 08011112222; re-sending it must not be a conflict.
    state.owner = { id: 'caller-profile', email: 'caller@example.com' };

    const res = await request(app)
      .post('/api/v1/auth/sync')
      .send({ phone: '08011112222', name: 'Caller' });

    expect(res.status).not.toBe(409);
  });
});

describe('POST /admin/bulk/import-members reports a number it could not take', () => {
  test('lists the rows skipped because the number was already registered', async () => {
    state.upsertError = { code: '23505', message: 'duplicate key value violates unique constraint "idx_profiles_phone_normalized_unique"' };

    const res = await request(app)
      .post('/api/v1/admin/bulk/import-members')
      .send({ members: [{ email: 'dup@example.com', firstname: 'Dup', lastname: 'Member', phone: '07038193753' }] });

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(0);
    expect(res.body.phoneConflicts).toEqual([{ email: 'dup@example.com', phone: '07038193753' }]);
  });

  test('a successful import reports no conflicts', async () => {
    state.upsertError = null;
  state.ownerSequence = null;

    const res = await request(app)
      .post('/api/v1/admin/bulk/import-members')
      .send({ members: [{ email: 'new@example.com', firstname: 'New', lastname: 'Member', phone: '08099998888' }] });

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(1);
    expect(res.body.phoneConflicts).toEqual([]);
  });
});
