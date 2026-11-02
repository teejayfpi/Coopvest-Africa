const { getClientIP, cleanIP, isIPInRange, parseWhitelist } = require('../src/middleware/ipWhitelist');

/**
 * IP-derivation tests.
 *
 * These exist because client-IP resolution decides two security controls: the
 * rate limiters and the admin IP whitelist. Reading the left-most
 * X-Forwarded-For entry — as the code did — lets any caller pick their own IP.
 */

describe('getClientIP', () => {
  test('prefers Express req.ip over the X-Forwarded-For header', () => {
    // req.ip is what Express computed using the `trust proxy` hop count. A
    // forged left-most header entry must not override it.
    const req = {
      ip: '203.0.113.9',
      headers: { 'x-forwarded-for': '1.2.3.4, 203.0.113.9' },
      socket: { remoteAddress: '10.0.0.1' },
    };
    expect(getClientIP(req)).toBe('203.0.113.9');
  });

  test('falls back to the right-most header entry, never the forged left-most', () => {
    const req = {
      headers: { 'x-forwarded-for': '1.2.3.4, 203.0.113.9' },
      socket: { remoteAddress: '10.0.0.1' },
    };
    // Right-most is what the trusted proxy appended; 1.2.3.4 is caller-supplied.
    expect(getClientIP(req)).toBe('203.0.113.9');
  });

  test('uses the socket address when no proxy headers are present', () => {
    const req = { headers: {}, socket: { remoteAddress: '198.51.100.7' } };
    expect(getClientIP(req)).toBe('198.51.100.7');
  });
});

describe('cleanIP', () => {
  test('strips the IPv4-mapped IPv6 prefix', () => {
    expect(cleanIP('::ffff:192.168.1.1')).toBe('192.168.1.1');
  });

  test('strips a port from a bare IPv4 address', () => {
    expect(cleanIP('192.168.1.1:8080')).toBe('192.168.1.1');
  });

  test('leaves a bracketed IPv6 address intact (the old startsWith[ bug)', () => {
    // `!ip.startsWith['[']` indexed the function with '[' and was always
    // falsy, so the guard never excluded anything.
    expect(cleanIP('[::1]:8080')).toBe('[::1]:8080');
  });

  test('defaults empty input to loopback', () => {
    expect(cleanIP('')).toBe('127.0.0.1');
    expect(cleanIP(undefined)).toBe('127.0.0.1');
  });
});

describe('whitelist matching', () => {
  test('matches an exact address', () => {
    expect(isIPInRange('203.0.113.9', '203.0.113.9')).toBe(true);
    expect(isIPInRange('203.0.113.10', '203.0.113.9')).toBe(false);
  });

  test('matches a CIDR range', () => {
    expect(isIPInRange('203.0.113.200', '203.0.113.0/24')).toBe(true);
    expect(isIPInRange('203.0.114.1', '203.0.113.0/24')).toBe(false);
  });

  test('an empty whitelist parses to an empty list (filtering off)', () => {
    const prev = process.env.ADMIN_IP_WHITELIST;
    delete process.env.ADMIN_IP_WHITELIST;
    expect(parseWhitelist()).toEqual([]);
    if (prev !== undefined) process.env.ADMIN_IP_WHITELIST = prev;
  });
});
