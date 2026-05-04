/**
 * Auth Routes
 *
 * All authentication endpoints — Supabase-backed.
 * Response shapes are aligned with the Flutter AuthResponse.fromJson contract:
 *   { token, refresh_token, user: { userId, id, email, name, phone, ... }, expires_at }
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
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
 * Build the user object returned to the Flutter app.
 * Merges Supabase auth.user metadata with the public.profiles row.
 */
const buildUserPayload = (authUser, profile) => ({
  userId: profile?.user_id || authUser.user_metadata?.userId || authUser.id,
  id: authUser.id,
  email: authUser.email,
  name: profile?.name || authUser.user_metadata?.name || '',
  phone: profile?.phone || authUser.user_metadata?.phone || null,
  role: profile?.role || authUser.user_metadata?.role || 'member',
  kycStatus: profile?.kyc_verified ? 'approved' : 'pending',
  membershipStatus: profile?.is_active === false ? 'inactive' : 'active',
  emailVerified: authUser.email_confirmed_at ? true : false,
  created_at: profile?.created_at || authUser.created_at,
  updated_at: profile?.updated_at || authUser.updated_at || authUser.created_at,
});

/**
 * Build a standardised success response that AuthResponse.fromJson can parse.
 */
const buildAuthResponse = (session, userPayload) => ({
  success: true,
  token: session.access_token,
  refresh_token: session.refresh_token,
  expires_at: session.expires_at
    ? new Date(session.expires_at * 1000).toISOString()
    : new Date(Date.now() + 3600 * 1000).toISOString(),
  user: userPayload,
});

/**
 * Ensure a profile row exists for a Supabase auth user.
 * Creates one if missing (idempotent via ON CONFLICT DO NOTHING).
 */
const ensureProfile = async (authUser, extra = {}) => {
  const userId = extra.userId || `USR-${Date.now().toString(36).toUpperCase()}`;
  const { data: existing } = await supabase
    .from('profiles')
    .select('id, user_id, email, name, phone, role, kyc_verified, is_active, created_at, updated_at')
    .eq('id', authUser.id)
    .maybeSingle();

  if (existing) return existing;

  const { data: created, error } = await supabase
    .from('profiles')
    .insert({
      id: authUser.id,
      user_id: userId,
      email: authUser.email,
      name: extra.name || authUser.user_metadata?.name || '',
      phone: extra.phone || authUser.user_metadata?.phone || null,
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
// ─────────────────────────────────────────────────────────────────────────────
router.post('/register', [
  body('email').isEmail().withMessage('Valid email is required'),
  body('name').notEmpty().withMessage('Name is required'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
], validate, async (req, res) => {
  try {
    const { email, phone, name, password, referralCode } = req.body;
    const userId = `USR-${Date.now().toString(36).toUpperCase()}`;

    const { data, error } = await supabase.auth.signUp({
      email: email.toLowerCase(),
      password,
      options: {
        data: { name, phone: phone || null, userId, role: 'member', referralCode: referralCode || null },
      },
    });

    if (error) {
      return res.status(400).json({ success: false, error: error.message });
    }

    const authUser = data.user;

    // Supabase may not have a DB trigger — always ensure the profile row exists.
    const profile = await ensureProfile(authUser, { userId, name, phone: phone || null });

    // If no session (email confirmation required), return minimal response.
    if (!data.session) {
      return res.status(201).json({
        success: true,
        requiresEmailVerification: true,
        message: 'Registration successful. Please check your email to verify your account.',
        user: buildUserPayload(authUser, profile),
        token: null,
        refresh_token: null,
      });
    }

    return res.status(201).json(buildAuthResponse(data.session, buildUserPayload(authUser, profile)));
  } catch (err) {
    logger.error('Registration error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/login
// ─────────────────────────────────────────────────────────────────────────────
router.post('/login', [
  body('email').isEmail().withMessage('Valid email is required'),
  body('password').notEmpty().withMessage('Password is required'),
], validate, async (req, res) => {
  try {
    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email: email.toLowerCase(),
      password,
    });

    if (error) {
      return res.status(401).json({ success: false, error: 'Invalid email or password' });
    }

    const authUser = data.user;

    // Fetch profile (create if missing — handles legacy accounts)
    const profile = await ensureProfile(authUser, {
      name: authUser.user_metadata?.name,
      phone: authUser.user_metadata?.phone,
    });

    return res.json(buildAuthResponse(data.session, buildUserPayload(authUser, profile)));
  } catch (err) {
    logger.error('Login error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/refresh
// ─────────────────────────────────────────────────────────────────────────────
router.post('/refresh', [
  body('refresh_token').notEmpty().withMessage('refresh_token is required'),
], validate, async (req, res) => {
  try {
    const { refresh_token } = req.body;

    const { data, error } = await supabase.auth.refreshSession({ refresh_token });
    if (error || !data.session) {
      return res.status(401).json({ success: false, error: 'Invalid or expired refresh token' });
    }

    const authUser = data.user;
    const { data: profile } = await supabase
      .from('profiles')
      .select('id, user_id, email, name, phone, role, kyc_verified, is_active, created_at, updated_at')
      .eq('id', authUser.id)
      .maybeSingle();

    return res.json(buildAuthResponse(data.session, buildUserPayload(authUser, profile)));
  } catch (err) {
    logger.error('Refresh token error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/google
// ─────────────────────────────────────────────────────────────────────────────
router.post('/google', [
  body('idToken').notEmpty().withMessage('idToken is required'),
], validate, async (req, res) => {
  try {
    const { idToken } = req.body;

    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token: idToken,
    });

    if (error || !data.session) {
      return res.status(401).json({ success: false, error: error?.message || 'Google sign-in failed' });
    }

    const authUser = data.user;
    const profile = await ensureProfile(authUser, {
      name: authUser.user_metadata?.full_name || authUser.user_metadata?.name,
      phone: authUser.user_metadata?.phone,
    });

    return res.json(buildAuthResponse(data.session, buildUserPayload(authUser, profile)));
  } catch (err) {
    logger.error('Google sign-in error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/logout
// ─────────────────────────────────────────────────────────────────────────────
router.post('/logout', authenticate, async (req, res) => {
  try {
    await supabase.auth.admin.signOut(req.token);
  } catch (err) {
    logger.warn('Admin signOut error (non-fatal):', err.message);
  }
  return res.json({ success: true, message: 'Logged out successfully' });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/v1/auth/me  (also /profile)
// ─────────────────────────────────────────────────────────────────────────────
router.get(['/me', '/profile'], authenticate, async (req, res) => {
  try {
    // req.user is populated by the authenticate middleware from public.profiles
    const user = {
      userId: req.user.userId,
      id: req.user.id,
      email: req.user.email,
      name: req.user.name,
      role: req.user.role,
    };

    // Enrich with full profile data
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', req.user.id)
      .maybeSingle();

    if (profile) {
      Object.assign(user, {
        phone: profile.phone,
        kycStatus: profile.kyc_verified ? 'approved' : 'pending',
        membershipStatus: profile.is_active === false ? 'inactive' : 'active',
        created_at: profile.created_at,
        updated_at: profile.updated_at,
      });
    }

    return res.json({ success: true, user });
  } catch (err) {
    logger.error('Get profile error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/verify-email
// ─────────────────────────────────────────────────────────────────────────────
router.post('/verify-email', [
  body('email').isEmail().withMessage('Valid email is required'),
  body('code').notEmpty().withMessage('Verification code is required'),
], validate, async (req, res) => {
  try {
    const { email, code } = req.body;

    const { data, error } = await supabase.auth.verifyOtp({
      email: email.toLowerCase(),
      token: code,
      type: 'email',
    });

    if (error) {
      return res.status(400).json({ success: false, error: error.message });
    }

    return res.json({ success: true, message: 'Email verified successfully', session: data.session });
  } catch (err) {
    logger.error('Verify email error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/resend-verification
// ─────────────────────────────────────────────────────────────────────────────
router.post('/resend-verification', [
  body('email').isEmail().withMessage('Valid email is required'),
], validate, async (req, res) => {
  try {
    const { email } = req.body;

    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: email.toLowerCase(),
    });

    if (error) {
      return res.status(400).json({ success: false, error: error.message });
    }

    return res.json({ success: true, message: 'Verification email resent' });
  } catch (err) {
    logger.error('Resend verification error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/request-password-reset
// ─────────────────────────────────────────────────────────────────────────────
router.post('/request-password-reset', [
  body('email').isEmail().withMessage('Valid email is required'),
], validate, async (req, res) => {
  try {
    const { email } = req.body;

    const { error } = await supabase.auth.resetPasswordForEmail(email.toLowerCase(), {
      redirectTo: process.env.PASSWORD_RESET_REDIRECT_URL || 'https://coopvest.africa/reset-password',
    });

    // Always return success — never reveal whether the email is registered (prevents enumeration).
    // Log SMTP failures internally so they can be diagnosed without leaking info to the client.
    if (error) {
      logger.warn('Password reset email failed (SMTP/config issue):', error.message);
    }

    return res.json({ success: true, message: 'If that email is registered, a reset link has been sent.' });
  } catch (err) {
    logger.error('Request password reset error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/reset-password
// Verifies the OTP from the reset email and sets the new password.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/reset-password', [
  body('email').isEmail().withMessage('Valid email is required'),
  body('code').notEmpty().withMessage('Reset code is required'),
  body('new_password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
], validate, async (req, res) => {
  try {
    const { email, code, new_password } = req.body;

    // Verify OTP first to get a session
    const { data: verifyData, error: verifyError } = await supabase.auth.verifyOtp({
      email: email.toLowerCase(),
      token: code,
      type: 'recovery',
    });

    if (verifyError || !verifyData.session) {
      return res.status(400).json({ success: false, error: verifyError?.message || 'Invalid reset code' });
    }

    // Update the password using the session obtained from verifyOtp
    const userSupabase = supabase; // service role can update directly
    const { error: updateError } = await supabase.auth.admin.updateUserById(verifyData.user.id, {
      password: new_password,
    });

    if (updateError) {
      return res.status(400).json({ success: false, error: updateError.message });
    }

    return res.json({ success: true, message: 'Password reset successfully. Please log in with your new password.' });
  } catch (err) {
    logger.error('Reset password error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/change-password
// ─────────────────────────────────────────────────────────────────────────────
router.post('/change-password', authenticate, [
  body('current_password').notEmpty().withMessage('Current password is required'),
  body('new_password').isLength({ min: 8 }).withMessage('New password must be at least 8 characters'),
], validate, async (req, res) => {
  try {
    const { current_password, new_password } = req.body;

    // Re-authenticate to verify current password
    const { data: userData } = await supabase
      .from('profiles')
      .select('email')
      .eq('id', req.user.id)
      .single();

    const { error: verifyError } = await supabase.auth.signInWithPassword({
      email: userData.email,
      password: current_password,
    });

    if (verifyError) {
      return res.status(401).json({ success: false, error: 'Current password is incorrect' });
    }

    const { error: updateError } = await supabase.auth.admin.updateUserById(req.user.id, {
      password: new_password,
    });

    if (updateError) {
      return res.status(400).json({ success: false, error: updateError.message });
    }

    return res.json({ success: true, message: 'Password changed successfully' });
  } catch (err) {
    logger.error('Change password error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
