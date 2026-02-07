/**
 * Email Verification Routes
 * 
 * Endpoints for email verification functionality with cooldown support
 */

const express = require('express');
const router = express.Router();
const { query, body, validationResult } = require('express-validator');
const emailVerificationService = require('../services/emailVerificationService');
const logger = require('../utils/logger');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

/**
 * POST /api/v1/auth/send-verification-email
 * Send verification email to user's email address
 */
router.post('/send-verification-email', [
  query('email').isEmail().withMessage('Valid email is required')
], validate, async (req, res) => {
  try {
    const { email } = req.query;
    const frontendUrl = req.body.frontendUrl || process.env.FRONTEND_URL || 'http://localhost:3000';

    // Create a mock user object for the service
    const mockUser = { email };
    const result = await emailVerificationService.sendVerificationEmail(
      mockUser,
      frontendUrl
    );

    // In development, return the verification link
    if (result.devLink) {
      return res.json({
        success: true,
        message: result.message,
        devLink: result.devLink,
        cooldownSeconds: result.cooldown,
        note: 'This link is only visible in development mode'
      });
    }

    if (!result.success) {
      return res.status(429).json({
        success: false,
        error: result.error,
        remainingSeconds: result.remainingSeconds,
        canResendAt: result.canResendAt
      });
    }

    res.json({
      success: true,
      message: result.message,
      cooldownSeconds: result.cooldown
    });
  } catch (error) {
    logger.error('Send verification email error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/auth/verify-email
 * Verify email with token
 */
router.get('/verify-email', [
  query('email').isEmail().withMessage('Valid email is required'),
  query('token').notEmpty().withMessage('Verification token is required')
], validate, async (req, res) => {
  try {
    const { email, token } = req.query;

    const result = await emailVerificationService.verifyEmail(email, token);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    res.json({
      success: true,
      message: result.message,
      user: result.user
    });
  } catch (error) {
    logger.error('Verify email error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/auth/resend-verification-email
 * Resend verification email with cooldown
 */
router.post('/resend-verification-email', [
  query('email').isEmail().withMessage('Valid email is required')
], validate, async (req, res) => {
  try {
    const { email } = req.query;
    const frontendUrl = req.body.frontendUrl || process.env.FRONTEND_URL || 'http://localhost:3000';

    const result = await emailVerificationService.resendVerificationEmail(email, frontendUrl);

    if (!result.success) {
      return res.status(429).json({
        success: false,
        error: result.error,
        remainingSeconds: result.remainingSeconds,
        canResendAt: result.canResendAt
      });
    }

    // In development, return the verification link
    if (result.devLink) {
      return res.json({
        success: true,
        message: result.message,
        devLink: result.devLink,
        cooldownSeconds: result.cooldown,
        note: 'This link is only visible in development mode'
      });
    }

    res.json({
      success: true,
      message: result.message,
      cooldownSeconds: result.cooldown
    });
  } catch (error) {
    logger.error('Resend verification email error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/auth/check-email-verification
 * Check if email is verified
 */
router.get('/check-email-verification', [
  query('email').isEmail().withMessage('Valid email is required')
], validate, async (req, res) => {
  try {
    const { email } = req.query;

    const result = await emailVerificationService.isEmailVerified(email);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    res.json({
      success: true,
      isVerified: result.isVerified
    });
  } catch (error) {
    logger.error('Check email verification error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/auth/email-verification-status
 * Get detailed verification status including cooldown info
 */
router.get('/email-verification-status', [
  query('email').isEmail().withMessage('Valid email is required')
], validate, async (req, res) => {
  try {
    const { email } = req.query;

    const result = await emailVerificationService.getVerificationStatus(email);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    logger.error('Get verification status error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/auth/verify-otp
 * Verify email with 6-digit OTP
 */
router.post('/verify-otp', [
  body('email').isEmail().withMessage('Valid email is required'),
  body('otp').optional().isLength({ min: 6, max: 6 }).withMessage('6-digit verification code is required'),
  body('code').optional().isLength({ min: 6, max: 6 }).withMessage('6-digit verification code is required')
], validate, async (req, res) => {
  try {
    const { email, otp, code } = req.body;
    const verificationCode = otp || code;

    if (!verificationCode) {
      return res.status(400).json({ success: false, error: 'Verification code is required' });
    }

    const result = await emailVerificationService.verifyOTP(email, verificationCode);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    res.json({
      success: true,
      message: result.message,
      user: result.user
    });
  } catch (error) {
    logger.error('Verify OTP error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/auth/resend-otp
 * Alias for resend-verification-email to match frontend expectations
 */
router.post('/resend-otp', [
  body('email').isEmail().withMessage('Valid email is required')
], validate, async (req, res) => {
  try {
    const { email } = req.body;
    const frontendUrl = req.body.frontendUrl || process.env.FRONTEND_URL || 'http://localhost:3000';

    const result = await emailVerificationService.resendVerificationEmail(email, frontendUrl);

    if (!result.success) {
      return res.status(429).json({
        success: false,
        error: result.error,
        remainingSeconds: result.remainingSeconds,
        canResendAt: result.canResendAt
      });
    }

    // In development, return the OTP
    if (result.otp) {
      return res.json({
        success: true,
        message: result.message,
        otp: result.otp,
        cooldownSeconds: result.cooldown,
        note: 'This code is only visible in development mode'
      });
    }

    res.json({
      success: true,
      message: result.message,
      cooldownSeconds: result.cooldown
    });
  } catch (error) {
    logger.error('Resend OTP error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
