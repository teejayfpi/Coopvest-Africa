/**
 * Auth Routes — Firebase Auth backend
 *
 * Flutter signs users in directly with Firebase Auth SDK and sends the
 * Firebase ID token to this backend.  These routes:
 *   - POST /register   — create a Supabase profile row after Firebase signup
 *   - POST /sync       — sync / upsert profile after any Firebase sign-in
 *   - GET  /me         — return the current user's full profile
 *   - POST /logout     — revoke Firebase refresh tokens server-side (optional)
 *   - POST /change-password — handled entirely client-side via Firebase SDK
 *
 * Password reset, email verification, and Google sign-in are all managed
 * entirely by the Firebase Auth SDK on the Flutter client — no backend
 * endpoints are needed for those flows.
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { getFirebaseAdmin } = require('../config/firebase');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

/**
 * Build the user payload returned to the Flutter app.
 * Mirrors the shape expected by User.fromJson in auth_models.dart.
 */
const buildUserPayload = (firebaseUser, profile) => ({
  userId: profile?.user_id || firebaseUser.uid,
  id: firebaseUser.uid,
  email: firebaseUser.email || profile?.email || '',
  name: profile?.name || firebaseUser.displayName || '',
  phone: profile?.phone || firebaseUser.phoneNumber || null,
  role: profile?.role || 'member',
  kycStatus: profile?.kyc_verified ? 'approved' : 'pending',
  membershipStatus: profile?.is_active === false ? 'inactive' : 'active',
  emailVerified: firebaseUser.emailVerified || false,
  created_at: profile?.created_at || new Date().toISOString(),
  updated_at: profile?.updated_at || new Date().toISOString(),
});

/**
 * Ensure a profile row exists for a Firebase user.
 * Creates one if missing — idempotent via ON CONFLICT DO NOTHING.
 */
const ensureProfile = async (firebaseUser, extra = {}) => {
  const { data: existing } = await supabase
    .from('profiles')
    .select('id, user_id, email, name, phone, role, kyc_verified, is_active, created_at, updated_at')
    .eq('firebase_uid', firebaseUser.uid)
    .maybeSingle();

  if (existing) return existing;

  const userId = extra.userId || `USR-${Date.now().toString(36).toUpperCase()}`;

  const { data: created, error } = await supabase
    .from('profiles')
    .insert({
      firebase_uid: firebaseUser.uid,
      user_id: userId,
      email: firebaseUser.email || extra.email || '',
      name: extra.name || firebaseUser.displayName || '',
      phone: extra.phone || firebaseUser.phoneNumber || null,
      role: 'member',
      is_active: true,
    })
    .select('id, user_id, email, name, phone, role, kyc_verified, is_active, created_at, updated_at')
    .single();

  if (error) {
    logger.error('ensureProfile: insert failed:', error.message);
    return null;
  }
  return created;
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/register
// Called after Firebase createUserWithEmailAndPassword to create the backend
// profile row and set display name. The request must include a valid Firebase
// ID token in Authorization: Bearer <token>.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/register', [
  body('name').notEmpty().withMessage('Name is required'),
], validate, authenticate, async (req, res) => {
  try {
    const { name, phone, referralCode } = req.body;
    const admin = getFirebaseAdmin();

    // Update Firebase display name
    await admin.auth().updateUser(req.user.firebaseUid, {
      displayName: name,
    });

    const firebaseUser = await admin.auth().getUser(req.user.firebaseUid);
    const userId = `USR-${Date.now().toString(36).toUpperCase()}`;

    const profile = await ensureProfile(firebaseUser, {
      userId,
      name,
      phone: phone || null,
      email: firebaseUser.email,
    });

    // Store referral code if provided
    if (referralCode && profile) {
      await supabase
        .from('referrals')
        .upsert({ profile_id: profile.id, referred_by_code: referralCode }, { onConflict: 'profile_id' });
    }

    return res.status(201).json({
      success: true,
      requiresEmailVerification: !firebaseUser.emailVerified,
      message: 'Registration successful.',
      user: buildUserPayload(firebaseUser, profile),
    });
  } catch (err) {
    logger.error('Registration error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/sync
// Called after any Firebase sign-in (email/password, Google, etc.) to ensure
// the profile row exists and return the full user payload.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/sync', authenticate, async (req, res) => {
  try {
    const admin = getFirebaseAdmin();
    const firebaseUser = await admin.auth().getUser(req.user.firebaseUid);

    const profile = await ensureProfile(firebaseUser, {
      name: firebaseUser.displayName,
      email: firebaseUser.email,
      phone: firebaseUser.phoneNumber,
    });

    return res.json({
      success: true,
      user: buildUserPayload(firebaseUser, profile),
    });
  } catch (err) {
    logger.error('Sync error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/v1/auth/me  (also /profile)
// ─────────────────────────────────────────────────────────────────────────────
router.get(['/me', '/profile'], authenticate, async (req, res) => {
  try {
    const admin = getFirebaseAdmin();
    const firebaseUser = await admin.auth().getUser(req.user.firebaseUid);

    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('firebase_uid', req.user.firebaseUid)
      .maybeSingle();

    return res.json({
      success: true,
      user: buildUserPayload(firebaseUser, profile),
    });
  } catch (err) {
    logger.error('Get profile error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/logout
// Revoke all Firebase refresh tokens for the user server-side.
// The Flutter app must also call FirebaseAuth.instance.signOut().
// ─────────────────────────────────────────────────────────────────────────────
router.post('/logout', authenticate, async (req, res) => {
  try {
    const admin = getFirebaseAdmin();
    await admin.auth().revokeRefreshTokens(req.user.firebaseUid);
    return res.json({ success: true, message: 'Logged out successfully' });
  } catch (err) {
    logger.warn('Logout revoke error (non-fatal):', err.message);
    return res.json({ success: true, message: 'Logged out' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/v1/auth/kyc/status
// ─────────────────────────────────────────────────────────────────────────────
router.get('/kyc/status', authenticate, async (req, res) => {
  try {
    const { data: kyc } = await supabase
      .from('kyc')
      .select('verified, status')
      .eq('profile_id', req.user.id)
      .maybeSingle();

    const status = kyc?.verified ? 'approved' : (kyc?.status || 'pending');
    return res.json({ success: true, status });
  } catch (err) {
    logger.error('KYC status error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
