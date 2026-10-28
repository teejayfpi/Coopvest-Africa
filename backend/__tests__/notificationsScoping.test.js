/**
 * The member notification endpoints must never return a row that is not
 * addressed to the caller.
 *
 * `profile_id IS NULL` rows are global, not per-member: the RLS policy
 * (`profile_id = auth.uid() OR is_staff()`) makes them visible to every
 * member, and admin fan-out writes one row per recipient. Including them in
 * the member query (`... OR profile_id IS NULL`) meant a single global row —
 * a stray insert, or an admin alert written without a profile — surfaced in
 * every member's feed. These tests pin the `.eq('profile_id', ...)` filter on
 * every read path and assert the `.or(... profile_id IS NULL)` filter is gone.
 */

const request = require('supertest');
const express = require('express');

// ── fake supabase: records the filters applied to each query ─────────────────
const mockQueries = [];

function mockMakeQuery(table) {
  const q = {
    table,
    filters: [],
    select: () => q,
    eq: (col, val) => { q.filters.push(['eq', col, val]); return q; },
    or: (expr) => { q.filters.push(['or', expr]); return q; },
    in: () => q,
    order: () => q,
    range: () => q,
    limit: () => q,
    maybeSingle: () => Promise.resolve({ data: null, error: null }),
    single: () => Promise.resolve({ data: null, error: null }),
    then: (resolve) => resolve({ data: [], error: null, count: 0 }),
  };
  mockQueries.push(q);
  return q;
}

jest.mock('../src/config/supabase', () => ({ from: (table) => mockMakeQuery(table) }));

// Bypass auth: the route only needs a profile id on the request.
jest.mock('../src/middleware/auth', () => ({
  authenticate: (req, _res, next) => {
    req.user = { id: 'member-profile-id', role: 'member' };
    next();
  },
}));

const notificationsRouter = require('../src/routes/notifications');

const app = express();
app.use(express.json());
app.use('/api/v1/notifications', notificationsRouter);

function filtersFor(table) {
  return mockQueries.filter((q) => q.table === table).flatMap((q) => q.filters);
}

beforeEach(() => {
  mockQueries.length = 0;
});

describe('member notification reads are scoped to the caller', () => {
  test('GET / does not include global (profile_id IS NULL) rows', async () => {
    await request(app).get('/api/v1/notifications');

    const filters = filtersFor('notifications');
    expect(filters).toContainEqual(['eq', 'profile_id', 'member-profile-id']);
    expect(filters.some(([kind, , val]) => kind === 'or' && String(val).includes('is.null'))).toBe(false);
  });

  test('GET /unread-count does not include global rows', async () => {
    await request(app).get('/api/v1/notifications/unread-count');

    const filters = filtersFor('notifications');
    expect(filters).toContainEqual(['eq', 'profile_id', 'member-profile-id']);
    expect(filters.some(([kind]) => kind === 'or')).toBe(false);
  });

  test('GET /unread does not include global rows', async () => {
    await request(app).get('/api/v1/notifications/unread');

    const filters = filtersFor('notifications');
    expect(filters).toContainEqual(['eq', 'profile_id', 'member-profile-id']);
    expect(filters.some(([kind]) => kind === 'or')).toBe(false);
  });

  test('GET /:id does not disclose another profile\'s row', async () => {
    await request(app).get('/api/v1/notifications/some-id');

    const filters = filtersFor('notifications');
    expect(filters).toContainEqual(['eq', 'profile_id', 'member-profile-id']);
    expect(filters.some(([kind]) => kind === 'or')).toBe(false);
  });
});
