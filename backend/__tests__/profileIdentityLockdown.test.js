/**
 * Who may change a member's identity fields.
 *
 * A member cannot rewrite their own name, phone or email: those fields feed KYC
 * matching and payout records, so self-service edits are what the product
 * disallows. The member route must therefore reject them, and staff must still
 * be able to correct a genuine typo — otherwise the lockdown creates a dead end
 * where nobody can fix a wrong name.
 *
 * These tests pin both halves of that boundary. They assert on the write that
 * reaches the database, not on status codes alone, because a route could accept
 * a field and simply forget to persist it (or persist it silently).
 */

const request = require('supertest');
const express = require('express');

// ── fake supabase: records writes per table, answers reads from `state` ──────
const mockState = {
  profile: null,
  writes: [],
  phoneOwner: null,
};

function mockMakeQuery(table) {
  const q = {
    table,
    filters: [],
    select: () => q,
    eq: (col, val) => { q.filters.push([col, val]); return q; },
    update: (payload) => { q.payload = payload; mockState.writes.push({ table, payload }); return q; },
    maybeSingle: () => Promise.resolve({ data: mockState.profile, error: null }),
    single: () => Promise.resolve({ data: mockState.profile, error: null }),
    then: (resolve) => resolve({ data: mockState.profile, error: null, count: 0 }),
  };
  return q;
}

jest.mock('../src/config/supabase', () => ({
  from: (table) => mockMakeQuery(table),
  auth: { admin: { updateUserById: jest.fn().mockResolvedValue({ error: null }) } },
}));

jest.mock('../src/lib/phoneRegistry', () => ({
  findPhoneOwner: jest.fn(async () => mockState.phoneOwner),
  PHONE_TAKEN_MESSAGE: 'This phone number is already registered.',
}));

jest.mock('../src/middleware/auth', () => ({
  authenticate: (req, _res, next) => {
    req.user = { id: 'auth-user-1', userId: 'auth-user-1', role: 'member', phone: '08011111111' };
    next();
  },
  requireRegistrationPaid: (_req, _res, next) => next(),
  requireAdmin: (req, _res, next) => {
    req.user = { ...req.user, id: 'admin-1', role: 'admin', email: 'staff@coopvest.africa' };
    next();
  },
  requireService: (_req, _res, next) => next(),
}));

jest.mock('../src/services/notifyService', () => ({
  notifyMember: jest.fn().mockResolvedValue({ ok: true }),
}));

const userRouter = require('../src/routes/user');
const adminRouter = require('../src/routes/adminApi');

const app = express();
app.use(express.json());
app.use('/api/v1/user', userRouter);
app.use('/api/v1/admin', adminRouter);

const profileRow = (over = {}) => ({
  id: 'profile-1',
  user_id: 'auth-user-1',
  email: 'member@example.com',
  name: 'Ayanlowo Adebayo',
  phone: '08011111111',
  address: null,
  profile_picture: null,
  role: 'member',
  ...over,
});

beforeEach(() => {
  mockState.profile = profileRow();
  mockState.writes = [];
  mockState.phoneOwner = null;
});

describe('member cannot edit their own identity', () => {
  it.each([
    ['name', { name: 'Someone Else' }],
    ['phone', { phone: '08099999999' }],
    ['email', { email: 'other@example.com' }],
  ])('rejects a %s change and writes nothing', async (_field, body) => {
    const res = await request(app).put('/api/v1/user/profile').send(body);

    expect(res.status).toBe(400);
    expect(mockState.writes).toHaveLength(0);
  });

  it('rejects a name change even when sent alongside a valid address', async () => {
    const res = await request(app)
      .put('/api/v1/user/profile')
      .send({ name: 'Someone Else', address: '12 Marina Road' });

    expect(res.status).toBe(400);
    expect(mockState.writes).toHaveLength(0);
  });

  it('still lets a member maintain their address', async () => {
    const res = await request(app)
      .put('/api/v1/user/profile')
      .send({ address: '12 Marina Road, Lagos' });

    expect(res.status).toBe(200);
    expect(mockState.writes).toHaveLength(1);
    expect(mockState.writes[0].payload).toEqual({ address: '12 Marina Road, Lagos' });
  });

  it('refuses an empty request instead of writing nothing silently', async () => {
    const res = await request(app).put('/api/v1/user/profile').send({});

    expect(res.status).toBe(400);
    expect(mockState.writes).toHaveLength(0);
  });
});

describe('staff can correct a member identity', () => {
  it('updates a mistyped name', async () => {
    const res = await request(app)
      .patch('/api/v1/admin/members/profile-1')
      .send({ name: 'Ayanlowo Adebayo' });

    expect(res.status).toBe(200);
    expect(mockState.writes).toHaveLength(1);
    expect(mockState.writes[0].payload).toEqual({ name: 'Ayanlowo Adebayo' });
  });

  it('normalises a corrected phone number', async () => {
    const res = await request(app)
      .patch('/api/v1/admin/members/profile-1')
      .send({ phone: '08022222222' });

    expect(res.status).toBe(200);
    expect(mockState.writes[0].payload.phone).toBe('+2348022222222');
  });

  it('refuses a phone number that belongs to another member', async () => {
    mockState.phoneOwner = { id: 'someone-else' };

    const res = await request(app)
      .patch('/api/v1/admin/members/profile-1')
      .send({ phone: '08033333333' });

    expect(res.status).toBe(409);
    expect(res.body.code).toBe('PHONE_ALREADY_REGISTERED');
    expect(mockState.writes).toHaveLength(0);
  });

  it('allows a member to keep their own phone number', async () => {
    mockState.phoneOwner = { id: 'profile-1' };

    const res = await request(app)
      .patch('/api/v1/admin/members/profile-1')
      .send({ phone: '08011111111' });

    expect(res.status).toBe(200);
    expect(mockState.writes).toHaveLength(1);
  });

  it('still toggles account flags', async () => {
    const res = await request(app)
      .patch('/api/v1/admin/members/profile-1')
      .send({ isActive: false });

    expect(res.status).toBe(200);
    expect(mockState.writes[0].payload).toEqual({ is_active: false });
  });
});
