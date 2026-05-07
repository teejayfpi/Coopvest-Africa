/**
 * Authentication Middleware — Firebase Admin SDK
 *
 * Verifies Firebase ID tokens issued by the Flutter app's firebase_auth SDK.
 * After token verification the middleware looks up the user's profile row in
 * Supabase and attaches it to req.user so every route handler has a consistent
 * user object without an extra DB call.
 *
 * Modes:
 *   authenticate   — requires a valid Firebase ID token
 *   optionalAuth   — attaches req.user when a valid token is present, else continues
 *   requireAdmin   — valid token + role in ('admin', 'superadmin', 'staff')
 *   requireService — shared secret via x-service-token header (cross-backend calls)
 */

const { getFirebaseAdmin } = require('../config/firebase');
const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required. Provide a Firebase ID token as a Bearer token.',
      });
    }

    const idToken = authHeader.split(' ')[1];
    const admin = getFirebaseAdmin();

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (err) {
      logger.warn('Firebase token verification failed:', err.code, err.message);
      return res.status(401).json({ success: false, error: 'Invalid or expired token' });
    }

    const firebaseUid = decodedToken.uid;

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, user_id, email, name, role, is_active, is_flagged')
      .eq('firebase_uid', firebaseUid)
      .maybeSingle();

    if (profileError) {
      logger.error('Profile lookup error:', profileError);
      return res.status(401).json({ success: false, error: 'User profile lookup failed' });
    }

    if (!profile) {
      return res.status(401).json({ success: false, error: 'User profile not found' });
    }

    if (profile.is_active === false) {
      return res.status(403).json({ success: false, error: 'Account is disabled' });
    }

    req.user = {
      id: profile.id,
      firebaseUid,
      email: profile.email || decodedToken.email,
      userId: profile.user_id,
      name: profile.name,
      role: profile.role || 'member',
      isFlagged: profile.is_flagged === true,
    };

    req.token = idToken;
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

    const idToken = authHeader.split(' ')[1];
    const admin = getFirebaseAdmin();

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch {
      return next();
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('id, user_id, email, name, role')
      .eq('firebase_uid', decodedToken.uid)
      .maybeSingle();

    if (profile) {
      req.user = {
        id: profile.id,
        firebaseUid: decodedToken.uid,
        email: profile.email || decodedToken.email,
        userId: profile.user_id,
        name: profile.name,
        role: profile.role || 'member',
      };
      req.token = idToken;
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
