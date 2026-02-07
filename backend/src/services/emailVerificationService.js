/**
 * Email Verification Service
 * 
 * Handles email verification token generation, sending, and cooldown management
 */

const nodemailer = require('nodemailer');
const { User } = require('../models');
const logger = require('../utils/logger');

// Configuration constants
const NODE_ENV = process.env.NODE_ENV || (process.env.SMTP_HOST ? 'production' : 'development');
const RESEND_COOLDOWN_SECONDS = parseInt(process.env.EMAIL_RESEND_COOLDOWN_SECONDS) || 60; // 60 seconds default
const VERIFICATION_EXPIRY_HOURS = parseInt(process.env.EMAIL_VERIFICATION_EXPIRY_HOURS) || 24;

// Create transporter (configure with your email provider)
const createTransporter = () => {
  // Check if using Gmail
  if (process.env.SMTP_HOST && process.env.SMTP_HOST.includes('gmail.com')) {
    return nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      }
    });
  }

  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });
};

// Email templates
const getVerificationEmailTemplate = (user, token, otp, frontendUrl) => ({
  subject: 'Verify Your Coopvest Africa Account',
  html: `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: 'Inter', Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #1B5E20; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
        .button { display: inline-block; background: #1B5E20; color: white; padding: 14px 28px; 
                  text-decoration: none; border-radius: 6px; font-weight: 600; margin: 20px 0; }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        .code { background: #e8f5e9; padding: 15px; text-align: center; font-size: 32px; 
                letter-spacing: 8px; font-weight: bold; border-radius: 6px; margin: 20px 0; color: #1B5E20; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Coopvest Africa</h1>
          <p>Verify Your Email Address</p>
        </div>
        <div class="content">
          <p>Hi ${user.name},</p>
          <p>Thank you for registering with Coopvest Africa. To complete your account setup, 
             please use the verification code below:</p>
          
          <div class="code">${otp}</div>
          
          <p>Alternatively, you can click the button below to verify your email:</p>
          <p style="text-align: center;">
            <a href="${frontendUrl}/verify-email?token=${token}&email=${user.email}" 
               class="button">Verify Email Address</a>
          </p>
          <p><strong>This code and link will expire in ${VERIFICATION_EXPIRY_HOURS} hours.</strong></p>
          <p>If you didn't create an account with Coopvest Africa, please ignore this email.</p>
        </div>
        <div class="footer">
          <p>&copy; ${new Date().getFullYear()} Coopvest Africa. All rights reserved.</p>
          <p>This is an automated message, please do not reply.</p>
        </div>
      </div>
    </body>
    </html>
  `,
  text: `
    Hi ${user.name},
    
    Thank you for registering with Coopvest Africa. To complete your account setup, 
    please use the verification code below:
    
    Verification Code: ${otp}
    
    Alternatively, click the link below or copy and paste it into your browser:
    ${frontendUrl}/verify-email?token=${token}&email=${user.email}
    
    This code and link will expire in ${VERIFICATION_EXPIRY_HOURS} hours.
    
    If you didn't create an account with Coopvest Africa, please ignore this email.
    
    © ${new Date().getFullYear()} Coopvest Africa. All rights reserved.
  `
});

class EmailVerificationService {
  constructor() {
    this.transporter = null;
  }

  async getTransporter() {
    if (!this.transporter) {
      this.transporter = createTransporter();
    }
    return this.transporter;
  }

  /**
   * Check if user can resend verification email (cooldown check)
   */
  canResend(user) {
    if (!user.emailVerification.lastResendAt) {
      return { canResend: true, remainingSeconds: 0 };
    }

    const lastResend = new Date(user.emailVerification.lastResendAt);
    const cooldownEnd = new Date(lastResend.getTime() + RESEND_COOLDOWN_SECONDS * 1000);
    const now = new Date();

    if (cooldownEnd > now) {
      const remainingSeconds = Math.ceil((cooldownEnd - now) / 1000);
      return { 
        canResend: false, 
        remainingSeconds,
        message: `Please wait ${remainingSeconds} seconds before requesting a new verification email`
      };
    }

    return { canResend: true, remainingSeconds: 0 };
  }

  /**
   * Send verification email to user
   */
  async sendVerificationEmail(user, frontendUrl = process.env.FRONTEND_URL) {
    try {
      // Check cooldown
      const cooldownCheck = this.canResend(user);
      if (!cooldownCheck.canResend) {
        return {
          success: false,
          error: cooldownCheck.message,
          remainingSeconds: cooldownCheck.remainingSeconds,
          canResendAt: new Date(Date.now() + cooldownCheck.remainingSeconds * 1000).toISOString()
        };
      }

      // Generate verification token and OTP
      const { token, otp } = user.generateEmailVerificationToken();
      user.emailVerification.lastResendAt = new Date();
      await user.save();

      const templates = getVerificationEmailTemplate(user, token, otp, frontendUrl);

      // In development, log the verification link and OTP instead of sending
      if (NODE_ENV === 'development' || !process.env.SMTP_HOST) {
        logger.info('📧 [DEV MODE] Email verification:', {
          email: user.email,
          otp,
          verificationLink: `${frontendUrl}/verify-email?token=${token}&email=${user.email}`
        });
        return {
          success: true,
          message: 'Verification code generated (development mode)',
          devLink: `${frontendUrl}/verify-email?token=${token}&email=${user.email}`,
          otp,
          cooldown: RESEND_COOLDOWN_SECONDS
        };
      }

      const transporter = await this.getTransporter();
      
      logger.info(`Attempting to send email to ${user.email} via ${process.env.SMTP_HOST}`);
      
      await transporter.sendMail({
        from: `"Coopvest Africa" <${process.env.SMTP_FROM || 'noreply@coopvest.com'}>`,
        to: user.email,
        subject: templates.subject,
        html: templates.html,
        text: templates.text
      });

      logger.info(`Verification email sent successfully to: ${user.email}`);
      
      return {
        success: true,
        message: 'Verification email sent successfully',
        cooldown: RESEND_COOLDOWN_SECONDS
      };
    } catch (error) {
      logger.error('Failed to send verification email:', error);
      throw error;
    }
  }

  /**
   * Verify email with token
   */
  async verifyEmail(email, token) {
    try {
      const user = await User.findOne({ email: email.toLowerCase() });

      if (!user) {
        return { success: false, error: 'User not found' };
      }

      if (user.emailVerification.isVerified) {
        return { success: false, error: 'Email already verified' };
      }

      if (!user.isEmailVerificationTokenValid(token)) {
        return { success: false, error: 'Invalid or expired verification token' };
      }

      await user.verifyEmail();
      
      logger.info(`Email verified successfully for: ${email}`);
      
      return {
        success: true,
        message: 'Email verified successfully',
        user: {
          userId: user.userId,
          email: user.email,
          name: user.name
        }
      };
    } catch (error) {
      logger.error('Email verification failed:', error);
      throw error;
    }
  }

  /**
   * Verify email with OTP
   */
  async verifyOTP(email, otp) {
    try {
      const user = await User.findOne({ email: email.toLowerCase() });

      if (!user) {
        return { success: false, error: 'User not found' };
      }

      if (user.emailVerification.isVerified) {
        return { success: false, error: 'Email already verified' };
      }

      if (!user.isOTPValid(otp)) {
        return { success: false, error: 'Invalid or expired verification code' };
      }

      await user.verifyEmail();
      
      logger.info(`Email verified successfully with OTP for: ${email}`);
      
      return {
        success: true,
        message: 'Email verified successfully',
        user: {
          userId: user.userId,
          email: user.email,
          name: user.name
        }
      };
    } catch (error) {
      logger.error('OTP verification failed:', error);
      throw error;
    }
  }

  /**
   * Resend verification email with cooldown
   */
  async resendVerificationEmail(email, frontendUrl = process.env.FRONTEND_URL) {
    try {
      const user = await User.findOne({ email: email.toLowerCase() });

      if (!user) {
        return { success: false, error: 'User not found' };
      }

      if (user.emailVerification.isVerified) {
        return { success: false, error: 'Email already verified' };
      }

      // Check cooldown before generating new token
      const cooldownCheck = this.canResend(user);
      if (!cooldownCheck.canResend) {
        return {
          success: false,
          error: cooldownCheck.message,
          remainingSeconds: cooldownCheck.remainingSeconds,
          canResendAt: new Date(Date.now() + cooldownCheck.remainingSeconds * 1000).toISOString()
        };
      }

      // Generate new token and OTP (overwrites old one)
      const { token, otp } = user.generateEmailVerificationToken();
      user.emailVerification.lastResendAt = new Date();
      await user.save();

      // Send verification email
      logger.info(`Initiating resend verification email for: ${email}`);
      return await this.sendVerificationEmail(user, frontendUrl);
    } catch (error) {
      logger.error('Resend verification email failed:', error);
      throw error;
    }
  }

  /**
   * Check if email is verified
   */
  async isEmailVerified(email) {
    try {
      const user = await User.findOne({ email: email.toLowerCase() });
      if (!user) {
        return { success: false, error: 'User not found' };
      }
      return {
        success: true,
        isVerified: user.emailVerification.isVerified
      };
    } catch (error) {
      logger.error('Check email verification status failed:', error);
      throw error;
    }
  }

  /**
   * Get email verification status with cooldown info
   */
  async getVerificationStatus(email) {
    try {
      const user = await User.findOne({ email: email.toLowerCase() });
      if (!user) {
        return { success: false, error: 'User not found' };
      }

      const cooldownCheck = this.canResend(user);
      
      return {
        success: true,
        isVerified: user.emailVerification.isVerified,
        canResend: cooldownCheck.canResend,
        remainingSeconds: cooldownCheck.remainingSeconds,
        verifiedAt: user.emailVerification.verifiedAt,
        lastSentAt: user.emailVerification.lastResendAt
      };
    } catch (error) {
      logger.error('Get verification status failed:', error);
      throw error;
    }
  }
}

module.exports = new EmailVerificationService();
