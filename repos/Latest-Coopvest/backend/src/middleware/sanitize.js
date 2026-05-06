/**
 * NoSQL Injection Protection Middleware
 * 
 * Recursively strips MongoDB operator keys (starting with $) and dots from
 * user-supplied input in req.body, req.query, and req.params to prevent
 * NoSQL injection attacks.
 */

function sanitize(value) {
  if (value === null || value === undefined) return value;

  if (Array.isArray(value)) {
    return value.map(sanitize);
  }

  if (typeof value === 'object' && !(value instanceof Date)) {
    const sanitized = {};
    for (const key of Object.keys(value)) {
      // Strip keys that start with $ or contain dots (MongoDB operators)
      if (key.startsWith('$') || key.includes('.')) {
        continue;
      }
      sanitized[key] = sanitize(value[key]);
    }
    return sanitized;
  }

  return value;
}

/**
 * Express middleware that sanitizes req.body, req.query, and req.params
 */
function sanitizeMiddleware(req, res, next) {
  if (req.body) {
    req.body = sanitize(req.body);
  }
  if (req.query) {
    req.query = sanitize(req.query);
  }
  if (req.params) {
    req.params = sanitize(req.params);
  }
  next();
}

module.exports = { sanitize, sanitizeMiddleware };
