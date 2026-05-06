/**
 * Tests for NoSQL Injection Sanitize Middleware
 */

const { sanitize, sanitizeMiddleware } = require('../src/middleware/sanitize');

describe('NoSQL Injection Protection', () => {
  describe('sanitize function', () => {
    test('returns primitive values unchanged', () => {
      expect(sanitize('hello')).toBe('hello');
      expect(sanitize(42)).toBe(42);
      expect(sanitize(true)).toBe(true);
      expect(sanitize(null)).toBe(null);
      expect(sanitize(undefined)).toBe(undefined);
    });

    test('strips keys starting with $', () => {
      const input = { $gt: 100, name: 'test' };
      expect(sanitize(input)).toEqual({ name: 'test' });
    });

    test('strips keys containing dots', () => {
      const input = { 'a.b': 'value', name: 'test' };
      expect(sanitize(input)).toEqual({ name: 'test' });
    });

    test('handles nested $where injection attempts', () => {
      const input = {
        email: 'test@test.com',
        password: { $gt: '' }
      };
      const result = sanitize(input);
      expect(result.email).toBe('test@test.com');
      expect(result.password).toEqual({});
    });

    test('handles $ne injection attempts', () => {
      const input = { username: { $ne: null } };
      const result = sanitize(input);
      expect(result.username).toEqual({});
    });

    test('handles deeply nested injection attempts', () => {
      const input = {
        user: {
          profile: {
            name: 'safe',
            role: { $in: ['admin'] }
          }
        }
      };
      const result = sanitize(input);
      expect(result.user.profile.name).toBe('safe');
      expect(result.user.profile.role).toEqual({});
    });

    test('sanitizes arrays', () => {
      const input = [{ $gt: 1 }, { name: 'safe' }];
      const result = sanitize(input);
      expect(result).toEqual([{}, { name: 'safe' }]);
    });

    test('preserves Date objects', () => {
      const date = new Date('2024-01-01');
      expect(sanitize(date)).toEqual(date);
    });
  });

  describe('sanitizeMiddleware', () => {
    test('sanitizes req.body', () => {
      const req = {
        body: { email: 'test@test.com', password: { $gt: '' } },
        query: {},
        params: {}
      };
      const res = {};
      const next = jest.fn();

      sanitizeMiddleware(req, res, next);

      expect(req.body.email).toBe('test@test.com');
      expect(req.body.password).toEqual({});
      expect(next).toHaveBeenCalled();
    });

    test('sanitizes req.query', () => {
      const req = {
        body: {},
        query: { status: 'active', '$where': '1==1' },
        params: {}
      };
      const res = {};
      const next = jest.fn();

      sanitizeMiddleware(req, res, next);

      expect(req.query.status).toBe('active');
      expect(req.query['$where']).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('calls next() even with empty request data', () => {
      const req = { body: null, query: null, params: null };
      const res = {};
      const next = jest.fn();

      sanitizeMiddleware(req, res, next);
      expect(next).toHaveBeenCalled();
    });
  });
});
