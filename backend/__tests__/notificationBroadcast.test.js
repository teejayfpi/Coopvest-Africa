const {
  SUPPORTED_CHANNELS,
  AUDIENCE_TYPES,
  classifyChannels,
  normalizeAudience,
} = require('../src/lib/notificationBroadcast');

/**
 * The Notification Control Center let an admin pick SMS/email/push and an
 * audience, then reported success regardless. These helpers decide what is
 * honestly deliverable, so the toast can tell the admin the truth.
 */
describe('notification broadcast channel classification', () => {
  test('push and in-app are deliverable', () => {
    expect(SUPPORTED_CHANNELS).toEqual(expect.arrayContaining(['push', 'in_app']));
  });

  test('a push-only selection is delivered with nothing unimplemented', () => {
    expect(classifyChannels(['push'])).toEqual({
      delivered: ['push'],
      notImplemented: [],
    });
  });

  test('sms and email are reported as not implemented rather than delivered', () => {
    // notifyService.sendEmail/sendSms are stubs with no provider wired up.
    // Counting them as delivered would tell the admin members were texted when
    // no SMS was ever sent.
    const result = classifyChannels(['push', 'sms', 'email']);
    expect(result.delivered).toEqual(['push']);
    expect(result.notImplemented).toEqual(['sms', 'email']);
  });

  test('an empty selection keeps the historical push default', () => {
    expect(classifyChannels([])).toEqual({ delivered: ['push'], notImplemented: [] });
    expect(classifyChannels(undefined)).toEqual({ delivered: ['push'], notImplemented: [] });
  });

  test('a request for only an unimplemented channel delivers nothing silently', () => {
    const result = classifyChannels(['sms']);
    expect(result.delivered).toEqual([]);
    expect(result.notImplemented).toEqual(['sms']);
  });
});

describe('notification broadcast audience normalisation', () => {
  test('every audience the dashboard offers is accepted', () => {
    for (const a of AUDIENCE_TYPES) {
      expect(normalizeAudience(a)).toBe(a);
    }
  });

  test('all the dashboard values are covered', () => {
    for (const a of ['all', 'active', 'defaulters', 'organizations', 'loans_pending']) {
      expect(AUDIENCE_TYPES).toContain(a);
    }
  });

  test('an unknown or missing audience falls back to all', () => {
    // Falling back keeps behaviour predictable instead of matching zero members.
    expect(normalizeAudience('nonsense')).toBe('all');
    expect(normalizeAudience(undefined)).toBe('all');
    expect(normalizeAudience('')).toBe('all');
  });
});
