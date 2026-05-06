const { Router } = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { signAccess, signRefresh, verifyRefresh, hashToken, expiresAt } = require('../jwt');
const { requireAuth } = require('../middleware/auth');

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

function authResponse(user, accessToken, refreshToken) {
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

function storeRefreshToken(userId, refreshToken) {
  const id = uuidv4();
  const tokenHash = hashToken(refreshToken);
  const expAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  db.prepare('INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)').run(id, userId, tokenHash, expAt);
}

// POST /auth/register
router.post('/register', (req, res) => {
  const { email, password, name, phone, referralCode } = req.body;
  if (!email || !password || !name) {
    return res.status(400).json({ error: 'email, password, and name are required' });
  }
  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email.toLowerCase().trim());
  if (existing) {
    return res.status(409).json({ error: 'An account with this email already exists' });
  }

  const passwordHash = bcrypt.hashSync(password, 12);
  const now = new Date().toISOString();
  const userId = uuidv4();
  const refCode = generateReferralCode(name);

  let referredBy = null;
  if (referralCode) {
    const referrer = db.prepare('SELECT id FROM users WHERE referral_code = ?').get(referralCode);
    if (referrer) referredBy = referrer.id;
  }

  db.prepare(`
    INSERT INTO users (id, email, password_hash, name, phone, referral_code, referred_by, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(userId, email.toLowerCase().trim(), passwordHash, name, phone || null, refCode, referredBy, now, now);

  const otp = generateOTP();
  const otpId = uuidv4();
  const otpExpiry = new Date(Date.now() + 30 * 60 * 1000).toISOString();
  db.prepare('INSERT INTO otp_codes (id, user_id, code, type, expires_at) VALUES (?, ?, ?, ?, ?)').run(otpId, userId, otp, 'email_verification', otpExpiry);

  console.log(`[REGISTER] New user: ${email} | OTP: ${otp} (send via email in production)`);

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  const accessToken = signAccess({ sub: userId });
  const refreshToken = signRefresh({ sub: userId });
  storeRefreshToken(userId, refreshToken);

  res.status(201).json(authResponse(user, accessToken, refreshToken));
});

// POST /auth/login
router.post('/login', (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase().trim());
  if (!user) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  const valid = bcrypt.compareSync(password, user.password_hash);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  const now = new Date().toISOString();
  db.prepare('UPDATE users SET updated_at = ? WHERE id = ?').run(now, user.id);

  const accessToken = signAccess({ sub: user.id });
  const refreshToken = signRefresh({ sub: user.id });
  storeRefreshToken(user.id, refreshToken);

  const updatedUser = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
  res.json(authResponse(updatedUser, accessToken, refreshToken));
});

// POST /auth/google
router.post('/google', (req, res) => {
  res.status(501).json({ error: 'Google sign-in requires Firebase Admin SDK configuration. Use email/password for now.' });
});

// POST /auth/verify-email
router.post('/verify-email', requireAuth, (req, res) => {
  const { code } = req.body;
  if (!code) return res.status(400).json({ error: 'OTP code is required' });

  const otp = db.prepare(`
    SELECT * FROM otp_codes
    WHERE user_id = ? AND code = ? AND type = 'email_verification' AND used = 0 AND expires_at > ?
  `).get(req.user.id, code.toString(), new Date().toISOString());

  if (!otp) {
    return res.status(400).json({ error: 'Invalid or expired verification code' });
  }

  const now = new Date().toISOString();
  db.prepare('UPDATE otp_codes SET used = 1 WHERE id = ?').run(otp.id);
  db.prepare('UPDATE users SET email_verified = 1, updated_at = ? WHERE id = ?').run(now, req.user.id);

  res.json({ message: 'Email verified successfully' });
});

// POST /auth/resend-verification
router.post('/resend-verification', (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email is required' });

  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase().trim());
  if (!user) return res.status(404).json({ error: 'No account found with this email' });

  db.prepare("UPDATE otp_codes SET used = 1 WHERE user_id = ? AND type = 'email_verification'").run(user.id);

  const otp = generateOTP();
  const otpId = uuidv4();
  const otpExpiry = new Date(Date.now() + 30 * 60 * 1000).toISOString();
  db.prepare('INSERT INTO otp_codes (id, user_id, code, type, expires_at) VALUES (?, ?, ?, ?, ?)').run(otpId, user.id, otp, 'email_verification', otpExpiry);

  console.log(`[RESEND VERIFICATION] ${email} | OTP: ${otp}`);

  res.json({ message: 'Verification code sent to your email' });
});

// POST /auth/refresh
router.post('/refresh', (req, res) => {
  const { refresh_token } = req.body;
  if (!refresh_token) return res.status(400).json({ error: 'refresh_token is required' });

  let payload;
  try {
    payload = verifyRefresh(refresh_token);
  } catch {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }

  const tokenHash = hashToken(refresh_token);
  const stored = db.prepare(`
    SELECT * FROM refresh_tokens
    WHERE user_id = ? AND token_hash = ? AND revoked = 0 AND expires_at > ?
  `).get(payload.sub, tokenHash, new Date().toISOString());

  if (!stored) {
    return res.status(401).json({ error: 'Refresh token not found or revoked' });
  }

  db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE id = ?').run(stored.id);

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.sub);
  if (!user) return res.status(401).json({ error: 'User not found' });

  const newAccess = signAccess({ sub: user.id });
  const newRefresh = signRefresh({ sub: user.id });
  storeRefreshToken(user.id, newRefresh);

  res.json(authResponse(user, newAccess, newRefresh));
});

// POST /auth/logout
router.post('/logout', (req, res) => {
  const { refresh_token } = req.body || {};
  if (refresh_token) {
    const tokenHash = hashToken(refresh_token);
    db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?').run(tokenHash);
  }
  res.json({ message: 'Logged out successfully' });
});

// GET /auth/me
router.get('/me', requireAuth, (req, res) => {
  res.json({ user: userResponse(req.user) });
});

// POST /auth/kyc/submit
router.post('/kyc/submit', requireAuth, (req, res) => {
  const id = uuidv4();
  const now = new Date().toISOString();
  db.prepare('INSERT OR REPLACE INTO kyc_submissions (id, user_id, data, submitted_at) VALUES (?, ?, ?, ?)').run(id, req.user.id, JSON.stringify(req.body), now);
  db.prepare("UPDATE users SET kyc_status = 'under_review', updated_at = ? WHERE id = ?").run(now, req.user.id);
  res.json({ message: 'KYC submitted successfully. Under review.' });
});

// GET /auth/kyc/status
router.get('/kyc/status', requireAuth, (req, res) => {
  res.json({ status: req.user.kyc_status });
});

// POST /auth/request-password-reset
router.post('/request-password-reset', (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email is required' });

  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase().trim());
  if (user) {
    db.prepare("UPDATE otp_codes SET used = 1 WHERE user_id = ? AND type = 'password_reset'").run(user.id);
    const otp = generateOTP();
    const otpId = uuidv4();
    const otpExpiry = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    db.prepare('INSERT INTO otp_codes (id, user_id, code, type, expires_at) VALUES (?, ?, ?, ?, ?)').run(otpId, user.id, otp, 'password_reset', otpExpiry);
    console.log(`[PASSWORD RESET] ${email} | OTP: ${otp}`);
  }

  res.json({ message: 'If an account with this email exists, a reset code has been sent' });
});

// POST /auth/reset-password
router.post('/reset-password', (req, res) => {
  const { code, new_password } = req.body;
  if (!code || !new_password) return res.status(400).json({ error: 'code and new_password are required' });
  if (new_password.length < 6) return res.status(400).json({ error: 'Password must be at least 6 characters' });

  const otp = db.prepare(`
    SELECT * FROM otp_codes
    WHERE code = ? AND type = 'password_reset' AND used = 0 AND expires_at > ?
  `).get(code.toString(), new Date().toISOString());

  if (!otp) return res.status(400).json({ error: 'Invalid or expired reset code' });

  const now = new Date().toISOString();
  const passwordHash = bcrypt.hashSync(new_password, 12);
  db.prepare('UPDATE otp_codes SET used = 1 WHERE id = ?').run(otp.id);
  db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(passwordHash, now, otp.user_id);
  db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?').run(otp.user_id);

  res.json({ message: 'Password reset successfully. Please log in.' });
});

// POST /auth/change-password
router.post('/change-password', requireAuth, (req, res) => {
  const { current_password, new_password } = req.body;
  if (!current_password || !new_password) return res.status(400).json({ error: 'current_password and new_password are required' });
  if (new_password.length < 6) return res.status(400).json({ error: 'New password must be at least 6 characters' });

  const valid = bcrypt.compareSync(current_password, req.user.password_hash);
  if (!valid) return res.status(401).json({ error: 'Current password is incorrect' });

  const now = new Date().toISOString();
  const passwordHash = bcrypt.hashSync(new_password, 12);
  db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(passwordHash, now, req.user.id);

  res.json({ message: 'Password changed successfully' });
});

module.exports = router;
