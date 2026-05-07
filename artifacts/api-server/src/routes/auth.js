const { Router } = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const supabase = require('../supabase');
const { signAccess, signRefresh, verifyRefresh, hashToken, expiresAt } = require('../jwt');
const { requireAuth } = require('../middleware/auth');
const { sendOTPEmail } = require('../email');

const router = Router();

function userResponse(user) {
  return {
    userId: user.id,
    id: user.id,
    email: user.email,
    name: user.name,
    phone: user.phone || null,
    kycVerified: user.kyc_status === 'approved',
    kyc_status: user.kyc_status,
    membershipStatus: user.membership_status,
    membership_status: user.membership_status,
    referralCode: user.referral_code,
    referral_code: user.referral_code,
    emailVerified: !!user.email_verified,
    createdAt: user.created_at,
    updatedAt: user.updated_at,
  };
}

function authResp(user, accessToken, refreshToken) {
  return {
    token: accessToken,
    access_token: accessToken,
    refresh_token: refreshToken,
    user: userResponse(user),
    expires_at: expiresAt(7),
  };
}

function generateReferralCode(name) {
  const prefix = (name || 'USR').replace(/\s+/g, '').substring(0, 4).toUpperCase();
  const suffix = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `${prefix}${suffix}`;
}

function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function storeRefreshToken(userId, refreshToken) {
  const tokenHash = hashToken(refreshToken);
  const expAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  await supabase.from('refresh_tokens').insert({ user_id: userId, token_hash: tokenHash, expires_at: expAt });
}

async function storeOTP(userId, type, otp, minutesTTL = 30) {
  await supabase.from('otp_codes').update({ used: true }).eq('user_id', userId).eq('type', type);
  const expAt = new Date(Date.now() + minutesTTL * 60 * 1000).toISOString();
  await supabase.from('otp_codes').insert({ user_id: userId, code: otp, type, expires_at: expAt });
}

// POST /auth/register
router.post('/register', async (req, res) => {
  const { email, password, name, phone, referralCode } = req.body;
  if (!email || !password || !name) {
    return res.status(400).json({ error: 'email, password, and name are required' });
  }
  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const { data: existing } = await supabase
    .from('users').select('id').eq('email', email.toLowerCase().trim()).single();
  if (existing) {
    return res.status(409).json({ error: 'An account with this email already exists' });
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const refCode = generateReferralCode(name);

  let referredBy = null;
  if (referralCode) {
    const { data: referrer } = await supabase.from('users').select('id').eq('referral_code', referralCode).single();
    if (referrer) referredBy = referrer.id;
  }

  const { data: user, error } = await supabase.from('users').insert({
    email: email.toLowerCase().trim(),
    password_hash: passwordHash,
    name,
    phone: phone || null,
    referral_code: refCode,
    referred_by: referredBy,
  }).select().single();

  if (error) {
    console.error('[REGISTER] DB error:', error.message);
    return res.status(500).json({ error: 'Failed to create account. Please try again.' });
  }

  const otp = generateOTP();
  await storeOTP(user.id, 'email_verification', otp, 30);
  await sendOTPEmail({ to: user.email, name: user.name, otp, type: 'email_verification' });

  const accessToken = signAccess({ sub: user.id });
  const refreshToken = signRefresh({ sub: user.id });
  await storeRefreshToken(user.id, refreshToken);

  res.status(201).json(authResp(user, accessToken, refreshToken));
});

// POST /auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  const { data: user } = await supabase
    .from('users').select('*').eq('email', email.toLowerCase().trim()).single();
  if (!user) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  await supabase.from('users').update({ updated_at: new Date().toISOString() }).eq('id', user.id);

  const accessToken = signAccess({ sub: user.id });
  const refreshToken = signRefresh({ sub: user.id });
  await storeRefreshToken(user.id, refreshToken);

  const { data: updatedUser } = await supabase.from('users').select('*').eq('id', user.id).single();
  res.json(authResp(updatedUser, accessToken, refreshToken));
});

// POST /auth/google
router.post('/google', (_req, res) => {
  res.status(501).json({ error: 'Google sign-in requires Firebase Admin SDK. Use email/password for now.' });
});

// POST /auth/verify-email  (public — no auth required)
router.post('/verify-email', async (req, res) => {
  const { email, otp, code } = req.body;
  const otpCode = (otp || code || '').toString();
  if (!email || !otpCode) {
    return res.status(400).json({ error: 'email and otp are required' });
  }

  const { data: user } = await supabase
    .from('users').select('id').eq('email', email.toLowerCase().trim()).single();
  if (!user) return res.status(404).json({ error: 'No account found with this email' });

  const { data: storedOtp } = await supabase.from('otp_codes')
    .select('*')
    .eq('user_id', user.id)
    .eq('code', otpCode)
    .eq('type', 'email_verification')
    .eq('used', false)
    .gt('expires_at', new Date().toISOString())
    .single();

  if (!storedOtp) return res.status(400).json({ error: 'Invalid or expired verification code' });

  await supabase.from('otp_codes').update({ used: true }).eq('id', storedOtp.id);
  await supabase.from('users').update({ email_verified: true }).eq('id', user.id);

  res.json({ message: 'Email verified successfully' });
});

// POST /auth/resend-verification
router.post('/resend-verification', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email is required' });

  const { data: user } = await supabase
    .from('users').select('*').eq('email', email.toLowerCase().trim()).single();
  if (!user) return res.status(404).json({ error: 'No account found with this email' });

  const otp = generateOTP();
  await storeOTP(user.id, 'email_verification', otp, 30);
  await sendOTPEmail({ to: user.email, name: user.name, otp, type: 'email_verification' });

  res.json({ message: 'Verification code sent to your email' });
});

// POST /auth/refresh
router.post('/refresh', async (req, res) => {
  const { refresh_token } = req.body;
  if (!refresh_token) return res.status(400).json({ error: 'refresh_token is required' });

  let payload;
  try {
    payload = verifyRefresh(refresh_token);
  } catch {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }

  const tokenHash = hashToken(refresh_token);
  const { data: stored } = await supabase.from('refresh_tokens')
    .select('*')
    .eq('user_id', payload.sub)
    .eq('token_hash', tokenHash)
    .eq('revoked', false)
    .gt('expires_at', new Date().toISOString())
    .single();

  if (!stored) return res.status(401).json({ error: 'Refresh token not found or revoked' });

  await supabase.from('refresh_tokens').update({ revoked: true }).eq('id', stored.id);

  const { data: user } = await supabase.from('users').select('*').eq('id', payload.sub).single();
  if (!user) return res.status(401).json({ error: 'User not found' });

  const newAccess = signAccess({ sub: user.id });
  const newRefresh = signRefresh({ sub: user.id });
  await storeRefreshToken(user.id, newRefresh);

  res.json(authResp(user, newAccess, newRefresh));
});

// POST /auth/logout
router.post('/logout', async (req, res) => {
  const { refresh_token } = req.body || {};
  if (refresh_token) {
    const tokenHash = hashToken(refresh_token);
    await supabase.from('refresh_tokens').update({ revoked: true }).eq('token_hash', tokenHash);
  }
  res.json({ message: 'Logged out successfully' });
});

// GET /auth/me
router.get('/me', requireAuth, (req, res) => {
  res.json({ user: userResponse(req.user) });
});

// POST /auth/kyc/submit
router.post('/kyc/submit', requireAuth, async (req, res) => {
  await supabase.from('kyc_submissions').insert({ user_id: req.user.id, data: req.body });
  await supabase.from('users').update({ kyc_status: 'under_review' }).eq('id', req.user.id);
  res.json({ message: 'KYC submitted successfully. Under review.' });
});

// GET /auth/kyc/status
router.get('/kyc/status', requireAuth, (req, res) => {
  res.json({ status: req.user.kyc_status });
});

// POST /auth/request-password-reset
router.post('/request-password-reset', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email is required' });

  const { data: user } = await supabase
    .from('users').select('*').eq('email', email.toLowerCase().trim()).single();

  if (user) {
    const otp = generateOTP();
    await storeOTP(user.id, 'password_reset', otp, 15);
    await sendOTPEmail({ to: user.email, name: user.name, otp, type: 'password_reset' });
  }

  res.json({ message: 'If an account with this email exists, a reset code has been sent' });
});

// POST /auth/reset-password
router.post('/reset-password', async (req, res) => {
  const { code, new_password } = req.body;
  if (!code || !new_password) return res.status(400).json({ error: 'code and new_password are required' });
  if (new_password.length < 6) return res.status(400).json({ error: 'Password must be at least 6 characters' });

  const { data: otp } = await supabase.from('otp_codes')
    .select('*')
    .eq('code', code.toString())
    .eq('type', 'password_reset')
    .eq('used', false)
    .gt('expires_at', new Date().toISOString())
    .single();

  if (!otp) return res.status(400).json({ error: 'Invalid or expired reset code' });

  const passwordHash = await bcrypt.hash(new_password, 12);
  await supabase.from('otp_codes').update({ used: true }).eq('id', otp.id);
  await supabase.from('users').update({ password_hash: passwordHash }).eq('id', otp.user_id);
  await supabase.from('refresh_tokens').update({ revoked: true }).eq('user_id', otp.user_id);

  res.json({ message: 'Password reset successfully. Please log in.' });
});

// POST /auth/change-password
router.post('/change-password', requireAuth, async (req, res) => {
  const { current_password, new_password } = req.body;
  if (!current_password || !new_password) return res.status(400).json({ error: 'current_password and new_password are required' });
  if (new_password.length < 6) return res.status(400).json({ error: 'New password must be at least 6 characters' });

  const valid = await bcrypt.compare(current_password, req.user.password_hash);
  if (!valid) return res.status(401).json({ error: 'Current password is incorrect' });

  const passwordHash = await bcrypt.hash(new_password, 12);
  await supabase.from('users').update({ password_hash: passwordHash }).eq('id', req.user.id);

  res.json({ message: 'Password changed successfully' });
});

module.exports = router;
