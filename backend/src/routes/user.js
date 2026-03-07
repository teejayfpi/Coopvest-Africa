/**
 * User Profile Routes
 * 
 * User profile and settings management endpoints
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { User, Wallet } = require('../models');
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
 * GET /api/v1/user/profile
 * Get current user's profile
 */
router.get('/profile', authenticate, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.user.userId });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Get wallet info
    const wallet = await Wallet.findOne({ userId: req.user.userId });

    res.json({
      success: true,
      user: {
        userId: user.userId,
        email: user.email,
        name: user.name,
        phone: user.phone,
        referralCode: user.referral.myReferralCode,
        referralCount: user.referral.referralCount,
        kycVerified: user.kyc.verified,
        emailVerified: user.emailVerification.isVerified,
        savings: user.savings,
        walletBalance: wallet?.balance || 0,
        role: user.role,
        isActive: user.isActive,
        createdAt: user.createdAt
      }
    });
  } catch (error) {
    logger.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PUT /api/v1/user/profile
 * Update user profile
 */
router.put('/profile', authenticate, [
  body('name').optional().isLength({ min: 2, max: 100 }),
  body('phone').optional().isMobilePhone()
], validate, async (req, res) => {
  try {
    const { name, phone } = req.body;
    const userId = req.user.userId;

    const updateData = {};
    if (name) updateData.name = name;
    if (phone) updateData.phone = phone;

    const user = await User.findOneAndUpdate(
      { userId },
      { $set: updateData },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    res.json({
      success: true,
      user: {
        userId: user.userId,
        email: user.email,
        name: user.name,
        phone: user.phone
      },
      message: 'Profile updated successfully'
    });
  } catch (error) {
    logger.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PUT /api/v1/user/password
 * Change password
 */
router.put('/password', authenticate, [
  body('currentPassword').notEmpty(),
  body('newPassword').isLength({ min: 8 }).matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
], validate, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.userId;

    const user = await User.findOne({ userId }).select('+password');

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json({
        success: false,
        error: 'Current password is incorrect'
      });
    }

    user.password = newPassword;
    await user.save();

    res.json({
      success: true,
      message: 'Password changed successfully'
    });
  } catch (error) {
    logger.error('Change password error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PUT /api/v1/user/settings
 * Update user settings (notifications, etc.)
 */
router.put('/settings', authenticate, async (req, res) => {
  try {
    const { notifications, language, currency } = req.body;
    const userId = req.user.userId;

    // For now, we'll just log the settings update
    // In production, you'd store these in a UserSettings model
    logger.info(`User ${userId} updated settings:`, {
      notifications,
      language,
      currency
    });

    res.json({
      success: true,
      message: 'Settings updated successfully',
      settings: {
        notifications: notifications ?? true,
        language: language ?? 'en',
        currency: currency ?? 'NGN'
      }
    });
  } catch (error) {
    logger.error('Update settings error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/user/dashboard
 * Get user dashboard data
 */
router.get('/dashboard', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findOne({ userId });
    const wallet = await Wallet.findOne({ userId });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    res.json({
      success: true,
      dashboard: {
        user: {
          name: user.name,
          kycVerified: user.kyc.verified,
          emailVerified: user.emailVerification.isVerified
        },
        wallet: {
          balance: wallet?.balance || 0,
          currency: wallet?.currency || 'NGN'
        },
        savings: {
          totalSaved: user.savings.totalSaved,
          monthlySavings: user.savings.monthlySavings,
          consecutiveMonths: user.savings.consecutiveMonths
        },
        referral: {
          code: user.referral.myReferralCode,
          count: user.referral.referralCount
        }
      }
    });
  } catch (error) {
    logger.error('Get dashboard error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
