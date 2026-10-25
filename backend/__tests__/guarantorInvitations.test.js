/**
 * Guarantor invitation lifecycle rules.
 *
 * The reminder and expiry decisions must agree, and the trap is a row that both
 * reminds and expires on the same sweep. These tests pin the boundary: once the
 * deadline has passed it expires, it does not remind.
 */

const {
  deadlineFrom,
  isReminderDue,
  isExpired,
  DEFAULT_CONSENT_WINDOW_DAYS,
  REMINDER_LEAD_HOURS,
} = require('../src/lib/guarantorInvitations');

const HOUR = 60 * 60 * 1000;

function invite(overrides) {
  return { status: 'pending', consent_deadline: null, reminder_sent_at: null, ...overrides };
}

describe('deadlineFrom', () => {
  test('defaults to the consent window and honours an override', () => {
    const now = new Date('2026-01-01T00:00:00Z');
    const dflt = new Date(deadlineFrom(now));
    expect(Math.round((dflt - now) / (24 * HOUR))).toBe(DEFAULT_CONSENT_WINDOW_DAYS);
    const custom = new Date(deadlineFrom(now, 3));
    expect(Math.round((custom - now) / (24 * HOUR))).toBe(3);
  });
});

describe('isReminderDue', () => {
  const now = new Date('2026-01-10T00:00:00Z');

  test('is not due when the deadline is far off', () => {
    const d = new Date(now.getTime() + 5 * 24 * HOUR).toISOString();
    expect(isReminderDue(invite({ consent_deadline: d }), now)).toBe(false);
  });

  test('is due once inside the lead window', () => {
    const d = new Date(now.getTime() + (REMINDER_LEAD_HOURS - 1) * HOUR).toISOString();
    expect(isReminderDue(invite({ consent_deadline: d }), now)).toBe(true);
  });

  test('is not due again once already reminded', () => {
    const d = new Date(now.getTime() + 1 * HOUR).toISOString();
    expect(isReminderDue(invite({ consent_deadline: d, reminder_sent_at: now.toISOString() }), now)).toBe(false);
  });

  test('never reminds a row with no deadline (legacy QR row)', () => {
    expect(isReminderDue(invite({}), now)).toBe(false);
  });

  test('does not remind a row that has already lapsed — it expires instead', () => {
    const d = new Date(now.getTime() - 1 * HOUR).toISOString();
    expect(isReminderDue(invite({ consent_deadline: d }), now)).toBe(false);
  });

  test('does not remind a row that is no longer pending', () => {
    const d = new Date(now.getTime() + 1 * HOUR).toISOString();
    expect(isReminderDue(invite({ status: 'consented', consent_deadline: d }), now)).toBe(false);
  });
});

describe('isExpired', () => {
  const now = new Date('2026-01-10T00:00:00Z');

  test('is expired once past the deadline', () => {
    const d = new Date(now.getTime() - HOUR).toISOString();
    expect(isExpired(invite({ consent_deadline: d }), now)).toBe(true);
  });

  test('is not expired before the deadline', () => {
    const d = new Date(now.getTime() + HOUR).toISOString();
    expect(isExpired(invite({ consent_deadline: d }), now)).toBe(false);
  });

  test('a row with no deadline never expires', () => {
    expect(isExpired(invite({}), now)).toBe(false);
  });

  test('a consented row does not expire', () => {
    const d = new Date(now.getTime() - HOUR).toISOString();
    expect(isExpired(invite({ status: 'consented', consent_deadline: d }), now)).toBe(false);
  });

  test('reminder and expiry are mutually exclusive at the boundary', () => {
    const past = new Date(now.getTime() - 1 * HOUR).toISOString();
    const row = invite({ consent_deadline: past });
    expect(isReminderDue(row, now) && isExpired(row, now)).toBe(false);
  });
});
