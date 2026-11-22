/**
 * `GET /loans/eligibility` must report the same verdict the application gate
 * enforces.
 *
 * The app used to infer eligibility from the first page of contribution rows,
 * so a member with several rows per month could be told they were short while
 * the server considered them eligible. The card on the dashboard was worse: it
 * read membership tenure only, so a member six months in with no contributions
 * at all saw "Eligible" and a working Apply button, then collected a 403.
 *
 * These tests drive the route with real contribution rows so the numbers in the
 * response are the ones the rule actually produces, not strings in a file.
 */

const request = require('supertest');
const express = require('express');

// ── fixtures ─────────────────────────────────────────────────────────────────
const PROFILE_ID = 'member-profile-id';

let profileCreatedAt;
let contributionRows;
let depositRows;

function mockQuery(table) {
  const q = {
    _table: table,
    select: () => q,
    eq: () => q,
    in: () => q,
    order: () => q,
    limit: () => q,
    range: () => q,
    maybeSingle: () => {
      if (table === 'profiles') {
        return Promise.resolve({ data: { created_at: profileCreatedAt }, error: null });
      }
      return Promise.resolve({ data: null, error: null });
    },
    single: () => Promise.resolve({ data: null, error: null }),
    then: (resolve) => {
      if (table === 'contributions') {
        return resolve({ data: contributionRows, error: null });
      }
      if (table === 'transactions') {
        return resolve({ data: depositRows, error: null });
      }
      return resolve({ data: [], error: null, count: 0 });
    },
  };
  return q;
}

jest.mock('../src/config/supabase', () => ({ from: (table) => mockQuery(table) }));

jest.mock('../src/middleware/auth', () => ({
  authenticate: (req, _res, next) => {
    req.user = { id: 'member-profile-id', role: 'member' };
    next();
  },
}));

const loansRouter = require('../src/routes/loans');

const app = express();
app.use(express.json());
app.use('/api/v1/loans', loansRouter);

/** 'YYYY-MM' for N months before now, newest last. */
function monthKey(offsetFromNow) {
  const d = new Date();
  d.setDate(1);
  d.setMonth(d.getMonth() - offsetFromNow);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function monthsAgo(n) {
  const d = new Date();
  d.setMonth(d.getMonth() - n);
  return d.toISOString();
}

function contributionsFor(offsets, status = 'successful') {
  return offsets.map((o) => ({
    status,
    contribution_month: monthKey(o),
    created_at: monthsAgo(o),
  }));
}

beforeEach(() => {
  profileCreatedAt = monthsAgo(12);
  contributionRows = [];
  depositRows = [];
});

describe('GET /loans/eligibility', () => {
  test('reports an eligible member with six consecutive months', async () => {
    contributionRows = contributionsFor([5, 4, 3, 2, 1, 0]);

    const res = await request(app).get('/api/v1/loans/eligibility');

    expect(res.status).toBe(200);
    expect(res.body.eligible).toBe(true);
    expect(res.body.consecutiveMonths).toBe(6);
    expect(res.body.consecutiveRequired).toBe(6);
    expect(res.body.membershipMet).toBe(true);
    expect(res.body.reason).toBeNull();
  });

  test('refuses a member with tenure but no contributions', async () => {
    // The exact production case the dashboard card got wrong.
    contributionRows = [];

    const res = await request(app).get('/api/v1/loans/eligibility');

    expect(res.status).toBe(200);
    expect(res.body.eligible).toBe(false);
    expect(res.body.membershipMet).toBe(true);
    expect(res.body.consecutiveMonths).toBe(0);
    expect(res.body.reason).toBeTruthy();
    expect(res.body.guidance).toBeTruthy();
    expect(res.body.termsSection.id).toBe('loan_policy');
  });

  test('counts a gap and reports the longest unbroken run', async () => {
    // Six months of history with a missed month: only three in a row.
    contributionRows = contributionsFor([5, 4, 3, 1, 0]);

    const res = await request(app).get('/api/v1/loans/eligibility');

    expect(res.body.eligible).toBe(false);
    expect(res.body.consecutiveMonths).toBe(3);
  });

  test('a lapsed member is told the run broke, not that they never paid', async () => {
    contributionRows = contributionsFor([11, 10, 9, 8, 7, 6]);

    const res = await request(app).get('/api/v1/loans/eligibility');

    expect(res.body.eligible).toBe(false);
    expect(res.body.consecutiveMonths).toBe(6);
    expect(res.body.isCurrent).toBe(false);
    expect(res.body.reason).toMatch(/current|behind|missed/i);
  });

  test('reports membership short of the minimum', async () => {
    profileCreatedAt = monthsAgo(2);
    contributionRows = contributionsFor([1, 0]);

    const res = await request(app).get('/api/v1/loans/eligibility');

    expect(res.body.eligible).toBe(false);
    expect(res.body.membershipMet).toBe(false);
    expect(res.body.membershipMonths).toBeLessThan(6);
  });

  test('counts settled statuses the server writes', async () => {
    // The app's parser mapped these to `pending`; the rule must not.
    for (const status of ['successful', 'completed', 'approved', 'confirmed', 'paid']) {
      contributionRows = contributionsFor([0], status);

      const res = await request(app).get('/api/v1/loans/eligibility');

      expect(res.body.consecutiveMonths).toBe(1);
      expect(res.body.isCurrent).toBe(true);
    }
  });

  test('ignores unpaid statuses', async () => {
    contributionRows = contributionsFor([0], 'pending');

    const res = await request(app).get('/api/v1/loans/eligibility');

    expect(res.body.consecutiveMonths).toBe(0);
    expect(res.body.eligible).toBe(false);
  });

  test('the response shape matches what the app parses', async () => {
    contributionRows = contributionsFor([5, 4, 3, 2, 1, 0]);

    const res = await request(app).get('/api/v1/loans/eligibility');

    for (const key of [
      'success',
      'enforced',
      'eligible',
      'membershipMonths',
      'membershipRequired',
      'membershipMet',
      'consecutiveMonths',
      'consecutiveRequired',
      'isCurrent',
      'policyVersion',
    ]) {
      expect(res.body).toHaveProperty(key);
    }
  });
});
