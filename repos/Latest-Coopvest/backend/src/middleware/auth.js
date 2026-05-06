/**
 * Authentication Middleware
 *
 * Supabase-based authentication. Three modes:
 *   - authenticate      -> requires a valid member JWT (Supabase Auth)
 *   - optionalAuth      -> sets req.user if the JWT is valid, else continues
 *   - requireAdmin      -> valid JWT + role in ('admin', 'superadmin', 'staff')
 *   - requireService    -> valid `x-service-token` header matching
 *                          MOBILE_API_SERVICE_TOKEN (used by the admin web
 *                          portal for cross-backend proxy calls)
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required. Provide Bearer token in Authorization header.',
      });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      return res.status(401).json({ success: false, error: 'Invalid or expired token' });
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, user_id, email, name, role, is_active, is_flagged')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError || !profile) {
      logger.error('Failed to fetch user profile for role verification:', profileError);
      return res.status(401).json({ success: false, error: 'User profile not found' });
    }

    if (profile.is_active === false) {
      return res.status(403).json({ success: false, error: 'Account is disabled' });
    }

    req.user = {
      id: profile.id,
      email: profile.email,
      userId: profile.user_id,
      name: profile.name,
      role: profile.role || 'member',
      isFlagged: profile.is_flagged === true,
    };

    req.token = token;
    next();
  } catch (error) {
    logger.error('Authentication error:', error);
    res.status(401).json({ success: false, error: 'Authentication failed' });
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) return next();

    const token = authHeader.split(' ')[1];
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return next();

    const { data: profile } = await supabase
      .from('profiles')
      .select('id, user_id, email, name, role')
      .eq('id', user.id)
      .maybeSingle();

    if (profile) {
      req.user = {
        id: profile.id,
        email: profile.email,
        userId: profile.user_id,
        name: profile.name,
        role: profile.role || 'member',
      };
      req.token = token;
    }
    next();
  } catch (_) {
    next();
  }
};

const requireAdmin = (req, res, next) => {
  return authenticate(req, res, () => {
    if (req.user && ['admin', 'superadmin', 'staff'].includes(req.user.role)) {
      return next();
    }
    res.status(403).json({ success: false, error: 'Admin access required' });
  });
};

/**
 * Service-token auth for cross-backend calls (e.g. admin web portal). The
 * caller provides a shared secret in the `x-service-token` header. The
 * request is treated as if it came from a system actor and has full admin
 * privileges on read-only bulk endpoints. Never expose this token to a
 * browser; the admin web backend stores it in an env var and uses it from
 * its server process only.
 */
const requireService = (req, res, next) => {
  const expected = process.env.MOBILE_API_SERVICE_TOKEN;
  const provided = req.headers['x-service-token'] || req.headers['X-Service-Token'];

  if (!expected) {
    return res.status(503).json({
      success: false,
      error: 'Service token auth is not configured on this backend',
    });
  }
  if (!provided || provided !== expected) {
    return res.status(401).json({ success: false, error: 'Invalid or missing service token' });
  }

  req.service = { name: 'admin-web', role: 'service' };
  next();
};

module.exports = {
  authenticate,
  optionalAuth,
  requireAdmin,
  requireService,
};
