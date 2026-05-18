/**
 * Authentication Middleware
 *
 * Primary mode: Firebase Admin SDK JWT verification.
 * Fallback mode: Supabase auth (used when FIREBASE_PROJECT_ID is not set).
 *
 * Modes:
 *   - authenticate      -> requires a valid member JWT
 *   - optionalAuth      -> sets req.user if the JWT is valid, else continues
 *   - requireAdmin      -> valid JWT + role in ('admin', 'superadmin', 'staff')
 *   - requireService    -> valid `x-service-token` header matching
 *                          MOBILE_API_SERVICE_TOKEN
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

let _firebaseAdmin = null;

function getFirebaseAdmin() {
  if (_firebaseAdmin) return _firebaseAdmin;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) return null;
  try {
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      const credential = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
        ? admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON))
        : admin.credential.applicationDefault();
      admin.initializeApp({ credential, projectId });
    }
    _firebaseAdmin = admin;
    return admin;
  } catch (err) {
    logger.warn('Firebase Admin init failed — falling back to Supabase auth:', err.message);
    return null;
  }
}

async function verifyToken(token) {
  const admin = getFirebaseAdmin();

  if (admin) {
    const decoded = await admin.auth().verifyIdToken(token);
    const firebaseUid = decoded.uid;
    const email = decoded.email || null;

    let { data: profile, error } = await supabase
      .from('profiles')
      .select('id, user_id, email, name, role, is_active, is_flagged')
      .eq('firebase_uid', firebaseUid)
      .maybeSingle();

    if (error) {
      logger.error('Profile lookup by firebase_uid failed:', error.message);
    }

    if (!profile && email) {
      const res = await supabase
        .from('profiles')
        .select('id, user_id, email, name, role, is_active, is_flagged')
        .eq('email', email)
        .maybeSingle();
      profile = res.data;
    }

    return { profile, firebaseUid };
  }

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) throw new Error('Invalid or expired token');

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id, user_id, email, name, role, is_active, is_flagged')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError) {
    logger.error('Failed to fetch user profile:', profileError.message);
  }

  return { profile, supabaseUser: user };
}

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

    let profile, firebaseUid;
    try {
      const result = await verifyToken(token);
      profile = result.profile;
      firebaseUid = result.firebaseUid;
    } catch (err) {
      return res.status(401).json({ success: false, error: 'Invalid or expired token' });
    }

    if (!profile) {
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
      firebaseUid: firebaseUid || null,
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

    let profile, firebaseUid;
    try {
      const result = await verifyToken(token);
      profile = result.profile;
      firebaseUid = result.firebaseUid;
    } catch (_) {
      return next();
    }

    if (profile) {
      req.user = {
        id: profile.id,
        email: profile.email,
        userId: profile.user_id,
        name: profile.name,
        role: profile.role || 'member',
        firebaseUid: firebaseUid || null,
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
