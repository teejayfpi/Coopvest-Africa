/**
 * Auth Routes
 * 
 * Authentication endpoints with Supabase integration
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
// const { User } = require('../models'); // Removed for Supabase migration
const logger = require('../utils/logger');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

/**
 * POST /api/v1/auth/register
 * Register a new user with Supabase
 */
router.post('/register', [
  body('email').isEmail().withMessage('Valid email is required'),
  body('phone').notEmpty().withMessage('Phone number is required'),
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
        data: {
          name,
          phone,
          userId,
          role: 'user',
          referralCode: referralCode || null
        }
      }
    });

    if (error) {
      return res.status(400).json({
        success: false,
        error: error.message
      });
    }

    // MongoDB mirroring removed - project now uses Supabase for all data persistence
    // Supabase trigger automatically creates a profile row in public.profiles

    res.status(201).json({
      success: true,
      user: {
        userId: userId,
        email: data.user.email,
        name: name,
        emailVerified: data.user.email_confirmed_at ? true : false
      },
      session: data.session,
      message: 'User registered successfully. Please check your email for verification.'
    });
  } catch (error) {
    logger.error('Registration error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/auth/login
 * Login user with Supabase
 */
router.post('/login', [
  body('email').isEmail(),
  body('password').notEmpty()
], validate, async (req, res) => {
  try {
    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email: email.toLowerCase(),
      password
    });

    if (error) {
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
    }

    const user = data.user;

    res.json({
      success: true,
      user: {
        userId: user.user_metadata.userId || user.id,
        email: user.email,
        name: user.user_metadata.name,
        role: user.user_metadata.role,
        emailVerified: user.email_confirmed_at ? true : false
      },
      token: data.session.access_token,
      refreshToken: data.session.refresh_token
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/auth/logout
 * Logout user
 */
router.post('/logout', authenticate, async (req, res) => {
  try {
    // Server-side logout: sign out the specific user's session
    // Using admin API to invalidate the user's sessions
    const { error } = await supabase.auth.admin.signOut(req.token);
    if (error) {
      // Fallback: even if admin signOut fails, the client should discard the token
      logger.warn('Admin signOut failed, client should discard token:', error.message);
    }

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    logger.error('Logout error:', error);
    // Still return success - client should discard token regardless
    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  }
});

/**
 * GET /api/v1/auth/me
 * Get current user profile
 */
router.get(['/me', '/profile'], authenticate, async (req, res) => {
  try {
    // req.user is already populated by authenticate middleware
    res.json({
      success: true,
      user: req.user
    });
  } catch (error) {
    logger.error('Get profile error:', error);
    res.status(401).json({
      success: false,
      error: 'Invalid token'
    });
  }
});

module.exports = router;
