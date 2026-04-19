/**
 * Email Verification Middleware
 *
 * Uses Supabase Auth as the source of truth: a user is considered verified
 * when `auth.users.email_confirmed_at IS NOT NULL`. We also read the
 * profile row to support admin-forced overrides.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const requireEmailVerification = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, error: 'Authentication required', code: 'AUTH_REQUIRED' });
    }
    const token = authHeader.split(' ')[1];
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
      return res.status(401).json({ success: false, error: 'Invalid or expired token', code: 'AUTH_INVALID' });
    }

    const verifiedAt = user.email_confirmed_at || user.confirmed_at;
    if (!verifiedAt) {
      return res.status(403).json({
        success: false,
        error: 'Email verification required',
        code: 'EMAIL_NOT_VERIFIED',
      });
    }

    // Attach minimal user info for downstream handlers
    if (!req.user) {
      req.user = { id: user.id, email: user.email };
    }
    next();
  } catch (err) {
    logger.error('Email verification middleware error:', err);
    res.status(500).json({ success: false, error: 'Email verification check failed' });
  }
};

const optionalEmailVerification = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) return next();
    const token = authHeader.split(' ')[1];
    const { data: { user } } = await supabase.auth.getUser(token);
    req.userEmailVerified = Boolean(user?.email_confirmed_at || user?.confirmed_at);
    next();
  } catch (_) {
    req.userEmailVerified = false;
    next();
  }
};

module.exports = { requireEmailVerification, optionalEmailVerification };
