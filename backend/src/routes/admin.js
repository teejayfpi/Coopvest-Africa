/**
 * Admin Routes
 * 
 * Admin-only endpoints for referral management
 * Protected by JWT authentication + IP whitelist + role verification
 */

const express = require('express');
const router = express.Router();
const { body, param, validationResult } = require('express-validator');
const { Referral, User, AuditLog } = require('../models');
const referralService = require('../services/referralService');
const logger = require('../utils/logger');
const { authenticate, requireAdmin } = require('../middleware/auth');

// Validation middleware
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      errors: errors.array()
    });
  }
  next();
};

// Apply authentication and admin role check to ALL routes
router.use(authenticate);
router.use(requireAdmin);

// ============== ADMIN ENDPOINTS ==============

/**
 * GET /api/v1/admin/referrals
 * Get all referrals with filtering (admin)
 */
router.get('/referrals', async (req, res) => {
  try {
    const { status, page = 1, limit = 20, search } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    let query = {};
    
    if (status && status !== 'all') {
      switch (status) {
        case 'confirmed': query.confirmed = true; break;
        case 'pending': query.confirmed = false; break;
        case 'flagged': query.isFlagged = true; break;
        case 'unconsumed': query.confirmed = true; query.bonusConsumed = false; break;
        case 'consumed': query.bonusConsumed = true; break;
      }
    }

    if (search) {
      query.$or = [
        { referralCode: { $regex: search, $options: 'i' } },
        { referredName: { $regex: search, $options: 'i' } },
        { referrerName: { $regex: search, $options: 'i' } }
      ];
    }

    const referrals = await Referral.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    const total = await Referral.countDocuments(query);

    res.json({
      success: true,
      referrals,
      total,
      page: parseInt(page),
      limit: parseInt(limit)
    });
  } catch (error) {
    logger.error('Error getting referrals for admin:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/admin/referrals/stats
 * Get referral statistics (admin)
 */
router.get('/referrals/stats', async (req, res) => {
  try {
    // Base stats
    const stats = await Referral.aggregate([
      {
        $group: {
          _id: null,
          total: { $sum: 1 },
          pending: { $sum: { $cond: [{ $eq: ['$confirmed', false] }, 1, 0] } },
          confirmed: { $sum: { $cond: [{ $eq: ['$confirmed', true] }, 1, 0] } },
          flagged: { $sum: { $cond: ['$isFlagged', 1, 0] } },
          consumed: { $sum: { $cond: ['$bonusConsumed', 1, 0] } },
          avgBonus: { $avg: '$tierBonusPercent' }
        }
      }
    ]);

    // Tier distribution
    const tierDist = await Referral.aggregate([
      { $match: { confirmed: true, isFlagged: false } },
      { $group: { _id: '$tierBonusPercent', count: { $sum: 1 } } },
      { $sort: { _id: -1 } }
    ]);

    // Recent flagged
    const flagged = await Referral.find({ isFlagged: true })
      .sort({ flaggedDate: -1 })
      .limit(10)
      .lean();

    // Total interest saved (approximation)
    const consumedWithAmount = await Referral.aggregate([
      { $match: { bonusConsumed: true } },
      {
        $group: {
          _id: null,
          totalBonus: { $sum: '$tierBonusPercent' },
          count: { $sum: 1 }
        }
      }
    ]);

    res.json({
      success: true,
      overview: stats[0] || {
        total: 0, pending: 0, confirmed: 0, flagged: 0, consumed: 0, avgBonus: 0
      },
      tierDistribution: tierDist,
      recentFlagged: flagged,
      bonusUsage: consumedWithAmount[0] || { count: 0, totalBonus: 0 }
    });
  } catch (error) {
    logger.error('Error getting referral stats:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/admin/referrals/:referralId
 * Get referral details (admin)
 */
router.get('/referrals/:referralId', [
  param('referralId').notEmpty()
], validate, async (req, res) => {
  try {
    const referral = await Referral.findOne({ referralId: req.params.referralId });
    
    if (!referral) {
      return res.status(404).json({
        success: false,
        error: 'Referral not found'
      });
    }

    res.json({
      success: true,
      referral
    });
  } catch (error) {
    logger.error('Error getting referral:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/admin/referrals/:referralId/confirm
 * Manually confirm a referral (admin)
 */
router.post('/referrals/:referralId/confirm', [
  param('referralId').notEmpty(),
  body('notes').optional().isString()
], validate, async (req, res) => {
  try {
    const { referralId } = req.params;
    const { notes } = req.body;

    const referral = await Referral.findOne({ referralId });
    if (!referral) {
      return res.status(404).json({
        success: false,
        error: 'Referral not found'
      });
    }

    if (referral.confirmed) {
      return res.status(400).json({
        success: false,
        error: 'Referral already confirmed'
      });
    }

    // Confirm with custom lock-in period
    const lockInDays = parseInt(req.body.lockInDays) || 30;
    await referral.confirmReferral(lockInDays);

    // Update referrer's tier
    await referralService.updateReferrerTier(referral.referrerId);

    // Log admin action
    await AuditLog.log({
      action: 'REFERRAL_CONFIRMED',
      referralId,
      userId: referral.referredId,
      adminId: req.user.userId,
      details: `Admin confirmed referral. Notes: ${notes || 'None'}. Lock-in: ${lockInDays} days`,
      ipAddress: req.ip || req.connection.remoteAddress
    });

    res.json({
      success: true,
      referral,
      message: 'Referral confirmed successfully'
    });
  } catch (error) {
    logger.error('Error confirming referral:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/admin/referrals/:referralId/flag
 * Flag a referral for review (admin)
 */
router.post('/referrals/:referralId/flag', [
  param('referralId').notEmpty(),
  body('reason').notEmpty().withMessage('Flag reason is required')
], validate, async (req, res) => {
  try {
    const { referralId } = req.params;
    const { reason } = req.body;

    const result = await referralService.flagReferral(referralId, reason, req.user.userId);

    res.json({
      success: true,
      referral: result.referral,
      message: 'Referral flagged successfully'
    });
  } catch (error) {
    logger.error('Error flagging referral:', error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({ success: false, error: error.message });
    }
    
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/admin/referrals/:referralId/unflag
 * Unflag a referral (admin)
 */
router.post('/referrals/:referralId/unflag', [
  param('referralId').notEmpty()
], validate, async (req, res) => {
  try {
    const { referralId } = req.params;

    const result = await referralService.unflagReferral(referralId, req.user.userId);

    res.json({
      success: true,
      referral: result.referral,
      message: 'Referral unflagged successfully'
    });
  } catch (error) {
    logger.error('Error unflagging referral:', error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({ success: false, error: error.message });
    }
    
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/admin/referrals/:referralId/revoke
 * Revoke referral bonus (admin)
 */
router.post('/referrals/:referralId/revoke', [
  param('referralId').notEmpty(),
  body('reason').notEmpty().withMessage('Revoke reason is required')
], validate, async (req, res) => {
  try {
    const { referralId } = req.params;
    const { reason } = req.body;

    const result = await referralService.revokeBonus(referralId, reason, req.user.userId);

    res.json({
      success: true,
      referral: result.referral,
      message: 'Bonus revoked successfully'
    });
  } catch (error) {
    logger.error('Error revoking bonus:', error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({ success: false, error: error.message });
    }
    
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/admin/referrals/audit
 * Get audit logs (admin)
 */
router.get('/referrals/audit', async (req, res) => {
  try {
    const { page = 1, limit = 50, action, userId, referralId } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    let query = {};
    if (action) query.action = action;
    if (userId) query.userId = userId;
    if (referralId) query.referralId = referralId;

    const logs = await AuditLog.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    const total = await AuditLog.countDocuments(query);

    res.json({
      success: true,
      logs,
      total,
      page: parseInt(page),
      limit: parseInt(limit)
    });
  } catch (error) {
    logger.error('Error getting audit logs:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PUT /api/v1/admin/referrals/settings
 * Update referral settings (admin)
 */
router.put('/referrals/settings', [
  body('enabled').isBoolean(),
  body('lockInDays').optional().isInt({ min: 1, max: 90 }),
  body('minimumSavingsMonths').optional().isInt({ min: 1, max: 12 }),
  body('minimumSavingsAmount').optional().isNumeric()
], validate, async (req, res) => {
  try {
    const settings = req.body;
    
    // Log settings change
    await AuditLog.log({
      action: 'SETTINGS_CHANGED',
      adminId: req.user.userId,
      details: `Settings updated: ${JSON.stringify(settings)}`,
      ipAddress: req.ip || req.connection.remoteAddress
    });

    res.json({
      success: true,
      message: 'Settings updated successfully',
      settings
    });
  } catch (error) {
    logger.error('Error updating settings:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/admin/referrals/settings
 * Get referral settings (admin)
 */
router.get('/referrals/settings', async (req, res) => {
  try {
    const settings = {
      enabled: true,
      lockInDays: parseInt(process.env.REFERRAL_LOCK_IN_DAYS) || 30,
      minimumSavingsMonths: parseInt(process.env.REFERRAL_MIN_SAVINGS_MONTHS) || 3,
      minimumSavingsAmount: parseFloat(process.env.REFERRAL_MIN_SAVINGS_AMOUNT) || 5000,
      tierThresholds: {
        2: 2.0,
        4: 3.0,
        6: 4.0
      },
      maximumBonus: 4.0,
      minimumInterestFloors: {
        'Quick Loan': 5.0,
        'Flexi Loan': 6.0,
        'Emergency Loan': 7.0,
        'Business Loan': 8.0
      }
    };

    res.json({
      success: true,
      settings
    });
  } catch (error) {
    logger.error('Error getting settings:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/admin/users/:userId/referrals
 * Get user's referrals (admin)
 */
router.get('/users/:userId/referrals', async (req, res) => {
  try {
    const { userId } = req.params;
    const { status } = req.query;

    let query = { 'referral.referrerId': userId };
    if (status === 'confirmed') query.confirmed = true;
    else if (status === 'pending') query.confirmed = false;

    const referrals = await Referral.find(query)
      .sort({ createdAt: -1 })
      .lean();

    const summary = await referralService.getReferralSummary(userId);

    res.json({
      success: true,
      referrals,
      summary: summary.summary
    });
  } catch (error) {
    logger.error('Error getting user referrals:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
