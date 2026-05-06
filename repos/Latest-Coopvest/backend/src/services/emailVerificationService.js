/**
 * Email Verification Service (Supabase Auth wrapper)
 *
 * Supabase Auth owns the verification link and email transport. This
 * service exists as a thin compatibility layer so the existing routes in
 * `routes/emailVerification.js` don't need to change. All "sent at"
 * cooldown is deferred to Supabase itself.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const DEFAULT_COOLDOWN = 60;

async function lookupAuthUserByEmail(email) {
  try {
    const page = await supabase.auth.admin.listUsers({ page: 1, perPage: 200 });
    const list = page?.data?.users || [];
    return list.find((u) => u.email && u.email.toLowerCase() === email.toLowerCase()) || null;
  } catch (err) {
    logger.warn('listUsers lookup failed:', err.message);
    return null;
  }
}

class EmailVerificationService {
  async sendVerificationEmail(user, frontendUrl) {
    try {
      const email = user.email;
      const redirectTo = `${frontendUrl}/auth/verify-email`;
      const { error } = await supabase.auth.resend({
        type: 'signup',
        email,
        options: { emailRedirectTo: redirectTo },
      });
      if (error) {
        return { success: false, error: error.message };
      }
      return {
        success: true,
        message: 'Verification email sent.',
        cooldown: DEFAULT_COOLDOWN,
      };
    } catch (err) {
      logger.error('sendVerificationEmail error:', err);
      return { success: false, error: err.message };
    }
  }

  async resendVerificationEmail(email, frontendUrl) {
    return this.sendVerificationEmail({ email }, frontendUrl);
  }

  async verifyEmail(email, token) {
    try {
      const { data, error } = await supabase.auth.verifyOtp({
        email,
        token,
        type: 'email',
      });
      if (error) return { success: false, error: error.message };
      return {
        success: true,
        message: 'Email verified.',
        user: data?.user || null,
      };
    } catch (err) {
      logger.error('verifyEmail error:', err);
      return { success: false, error: err.message };
    }
  }

  async verifyOTP(email, code) {
    return this.verifyEmail(email, code);
  }

  async isEmailVerified(email) {
    const u = await lookupAuthUserByEmail(email);
    if (!u) return { success: false, error: 'User not found' };
    return {
      success: true,
      isVerified: !!(u.email_confirmed_at || u.confirmed_at),
    };
  }

  async getVerificationStatus(email) {
    const u = await lookupAuthUserByEmail(email);
    if (!u) return { success: false, error: 'User not found' };
    const verified = !!(u.email_confirmed_at || u.confirmed_at);
    return {
      success: true,
      isVerified: verified,
      verifiedAt: u.email_confirmed_at || u.confirmed_at || null,
      canResend: !verified,
      cooldownSeconds: DEFAULT_COOLDOWN,
    };
  }
}

module.exports = new EmailVerificationService();
