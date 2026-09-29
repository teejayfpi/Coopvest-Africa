/**
 * `notifications.message` is NOT NULL. `sendInApp` used to write only `body`,
 * so every insert failed with 23502 — and because notify failures are treated
 * as non-fatal, the error was swallowed and no notification (admin alerts
 * included) was ever stored. The mobile model reads `body` first and falls
 * back to `message`; the admin dashboard reads `message`. Both must be written.
 *
 * These tests capture the actual insert payload so the column can't regress.
 */
const insertedRows = [];

jest.mock('../src/config/supabase', () => {
  const makeQuery = (table) => {
    const query = {
      insert: (payload) => {
        insertedRows.push({ table, payload });
        return query;
      },
      select: () => query,
      eq: () => query,
      in: () => query,
      maybeSingle: () => Promise.resolve({ data: null, error: null }),
      single: () => Promise.resolve({ data: null, error: null }),
      then: (resolve) => resolve({ data: [], error: null }),
    };
    return query;
  };
  return { from: (table) => makeQuery(table) };
});

const notifyService = require('../src/services/notifyService');

beforeEach(() => {
  insertedRows.length = 0;
});

describe('notifications insert payload', () => {
  test('sendInApp writes the NOT NULL message column as well as body', async () => {
    await notifyService.sendInApp({
      profileId: 'p1',
      title: 'Payment Received',
      body: 'A member paid ₦5,000 by card.',
      type: 'transaction',
      category: 'success',
    });

    const row = insertedRows.find((r) => r.table === 'notifications');
    expect(row).toBeDefined();
    expect(row.payload.message).toBe('A member paid ₦5,000 by card.');
    expect(row.payload.body).toBe('A member paid ₦5,000 by card.');
  });

  test('notifyAdmins reaches the notifications table with a message value', async () => {
    // getAdminRecipients returns [] from the mock, so no row is expected; the
    // assertion below guards the shape whenever a row is written.
    await notifyService.notifyAdmins({
      title: 'New Website Enquiry',
      body: 'A visitor submitted an enquiry.',
      type: 'system',
      category: 'action_required',
    });

    for (const r of insertedRows.filter((x) => x.table === 'notifications')) {
      expect(r.payload.message).toBeTruthy();
      expect(r.payload.body).toBeTruthy();
    }
  });
});
