/**
 * Referral Routes
 * 
 * All referral-related API endpoints
 */

const express = require('express');
const router = express.Router();
const { body, param, query, validationResult } = require('express-validator');
const referralService = require('../services/referralService');
const qrCodeService = require('../services/qrCodeService');
const AuditLog = require('../models/AuditLog');
const { Referral } = require('../models');
const logger = require('../utils/logger');

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

// ============== USER ENDPOINTS ==============

/**
 * GET /api/v1/referrals/summary
 * Get user's referral summary
 */
router.get('/summary', async (req, res) => {
  try {
    const userId = req.user?.userId || req.headers['x-user-id'];
    
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const result = await referralService.getReferralSummary(userId);
    
    res.json({
      success: true,
      summary: result.summary
    });
  } catch (error) {
    logger.error('Error getting referral summary:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals/my-code
 * Get user's referral code
 */
router.get('/my-code', async (req, res) => {
  try {
    const userId = req.user?.userId || req.headers['x-user-id'];
    
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { User } = require('../models');
    const user = await User.findOne({ userId });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    res.json({
      success: true,
      referralCode: user.referral.myReferralCode
    });
  } catch (error) {
    logger.error('Error getting referral code:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals
 * Get all user's referrals
 */
router.get('/', async (req, res) => {
  try {
    const userId = req.user?.userId || req.headers['x-user-id'];
    const status = req.query.status || 'all';
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    // Build query
    const query = { referrerId: userId };
    if (status === 'confirmed') {
      query.confirmed = true;
    } else if (status === 'pending') {
      query.confirmed = false;
    } else if (status === 'flagged') {
      query.isFlagged = true;
    }

    const referrals = await Referral.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    const total = await Referral.countDocuments(query);

    res.json({
      success: true,
      referrals,
      total,
      page,
      limit
    });
  } catch (error) {
    logger.error('Error getting referrals:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals/:referralId
 * Get specific referral details
 */
router.get('/:referralId', 
  param('referralId').notEmpty(),
  validate,
  async (req, res) => {
    try {
      const { referralId } = req.params;
      const userId = req.user?.userId || req.headers['x-user-id'];

      const referral = await Referral.findOne({ 
        referralId,
        $or: [{ referrerId: userId }, { referredId: userId }]
      });

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
  }
);

/**
 * GET /api/v1/referrals/:referralId/status
 * Check referral status and qualification
 */
router.get('/:referralId/status',
  param('referralId').notEmpty(),
  validate,
  async (req, res) => {
    try {
      const { referralId } = req.params;
      
      const result = await referralService.checkReferralStatus(referralId);
      
      res.json({
        success: true,
        ...result
      });
    } catch (error) {
      logger.error('Error checking referral status:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
);

/**
 * POST /api/v1/referrals/register
 * Register a new referral
 */
router.post('/register', [
  body('referralCode').notEmpty().withMessage('Referral code is required'),
  body('referredUserId').notEmpty().withMessage('Referred user ID is required'),
  body('referredUserName').notEmpty().withMessage('Referred user name is required')
], validate, async (req, res) => {
  try {
    const { referralCode, referredUserId, referredUserName } = req.body;
    
    const result = await referralService.registerReferral(
      referralCode.toUpperCase(),
      referredUserId,
      referredUserName
    );

    res.status(201).json({
      success: true,
      referral: result.referral,
      message: result.message
    });
  } catch (error) {
    logger.error('Error registering referral:', error);
    
    if (error.message.includes('Self-referrals') || 
        error.message.includes('Invalid referral code') ||
        error.message.includes('already exists')) {
      return res.status(400).json({
        success: false,
        error: error.message
      });
    }
    
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/referrals/:referralId/confirm
 * Confirm a referral (when qualification criteria are met)
 */
router.post('/:referralId/confirm',
  param('referralId').notEmpty(),
  validate,
  async (req, res) => {
    try {
      const { referralId } = req.params;
      
      // Get referred user ID from request body or find it
      const referredUserId = req.body.referredUserId;
      
      if (!referredUserId) {
        return res.status(400).json({
          success: false,
          error: 'Referred user ID is required'
        });
      }

      const result = await referralService.confirmReferral(referralId, referredUserId);

      res.json({
        success: true,
        referral: result.referral,
        message: result.message,
        lockInEndDate: result.lockInEndDate
      });
    } catch (error) {
      logger.error('Error confirming referral:', error);
      
      if (error.message.includes('not found') || 
          error.message.includes('already confirmed') ||
          error.message.includes('does not meet')) {
        return res.status(400).json({
          success: false,
          error: error.message
        });
      }
      
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
);

/**
 * POST /api/v1/referrals/apply-bonus
 * Apply referral bonus to a loan
 */
router.post('/apply-bonus', [
  body('loanId').notEmpty().withMessage('Loan ID is required'),
  body('loanType').notEmpty().withMessage('Loan type is required'),
  body('loanAmount').isNumeric().withMessage('Loan amount must be a number'),
  body('tenureMonths').isInt({ min: 1 }).withMessage('Tenure must be a positive integer')
], validate, async (req, res) => {
  try {
    const { loanId, loanType, loanAmount, tenureMonths } = req.body;
    const userId = req.user?.userId || req.headers['x-user-id'];

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const result = await referralService.applyBonusToLoan(userId, loanId, loanType);

    if (!result.success) {
      return res.status(400).json(result);
    }

    // Calculate interest with bonus
    const calculation = referralService.calculateInterestWithBonus(
      loanType,
      loanAmount,
      tenureMonths,
      result.bonusPercent
    );

    res.json({
      success: true,
      bonusApplied: true,
      bonusPercent: result.bonusPercent,
      effectiveInterestRate: result.effectiveInterestRate,
      calculation,
      message: result.message
    });
  } catch (error) {
    logger.error('Error applying bonus:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/referrals/calculate-interest
 * Calculate loan interest with referral bonus
 */
router.post('/calculate-interest', [
  body('loanType').notEmpty().withMessage('Loan type is required'),
  body('loanAmount').isNumeric().withMessage('Loan amount must be a number'),
  body('tenureMonths').isInt({ min: 1 }).withMessage('Tenure must be a positive integer')
], validate, async (req, res) => {
  try {
    const { loanType, loanAmount, tenureMonths } = req.body;
    const userId = req.user?.userId || req.headers['x-user-id'];

    let bonusPercent = 0;
    let isBonusAvailable = false;

    // Get user's current bonus if authenticated
    if (userId) {
      try {
        const summary = await referralService.getReferralSummary(userId);
        bonusPercent = summary.summary.currentTierBonus;
        isBonusAvailable = summary.summary.isBonusAvailable;
      } catch (e) {
        // User might not exist, continue with no bonus
      }
    }

    const calculation = referralService.calculateInterestWithBonus(
      loanType,
      loanAmount,
      tenureMonths,
      isBonusAvailable ? bonusPercent : 0
    );

    res.json({
      success: true,
      calculation,
      bonusAvailable: isBonusAvailable,
      bonusPercent
    });
  } catch (error) {
    logger.error('Error calculating interest:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals/share-link
 * Get referral share link
 */
router.get('/share-link', async (req, res) => {
  try {
    const userId = req.user?.userId || req.headers['x-user-id'];

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const result = await referralService.getShareLink(userId);

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    logger.error('Error getting share link:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals/audit
 * Get user's referral audit log
 */
router.get('/audit', async (req, res) => {
  try {
    const userId = req.user?.userId || req.headers['x-user-id'];

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const limit = parseInt(req.query.limit) || 50;
    const logs = await AuditLog.getUserActivity(userId, limit);

    res.json({
      success: true,
      logs,
      total: logs.length
    });
  } catch (error) {
    logger.error('Error getting audit log:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// ============== ADMIN ENDPOINTS ==============

/**
 * GET /api/v1/referrals/admin/all
 * Get all referrals (admin only)
 */
router.get('/admin/all', async (req, res) => {
  try {
    // In production, verify admin role here
    const status = req.query.status || 'all';
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    let query = {};
    if (status === 'confirmed') query.confirmed = true;
    else if (status === 'pending') query.confirmed = false;
    else if (status === 'flagged') query.isFlagged = true;

    const referrals = await Referral.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    const total = await Referral.countDocuments(query);

    res.json({
      success: true,
      referrals,
      total,
      page,
      limit
    });
  } catch (error) {
    logger.error('Error getting all referrals:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals/admin/stats
 * Get referral statistics (admin only)
 */
router.get('/admin/stats', async (req, res) => {
  try {
    // In production, verify admin role here
    
    const pipeline = [
      {
        $group: {
          _id: null,
          totalReferrals: { $sum: 1 },
          pendingReferrals: {
            $sum: { $cond: [{ $eq: ['$confirmed', false] }, 1, 0] }
          },
          confirmedReferrals: {
            $sum: { $cond: [{ $eq: ['$confirmed', true] }, 1, 0] }
          },
          flaggedReferrals: {
            $sum: { $cond: [{ $eq: ['$isFlagged', true] }, 1, 0] }
          },
          consumedBonuses: {
            $sum: { $cond: ['$bonusConsumed', 1, 0] }
          },
          avgTierBonus: { $avg: '$tierBonusPercent' }
        }
      }
    ];

    const [stats] = await Referral.aggregate(pipeline);

    // Get referrals by tier
    const tierStats = await Referral.aggregate([
      { $match: { confirmed: true, isFlagged: false } },
      {
        $group: {
          _id: '$tierBonusPercent',
          count: { $sum: 1 }
        }
      },
      { $sort: { _id: -1 } }
    ]);

    res.json({
      success: true,
      totalReferrals: stats?.totalReferrals || 0,
      pendingReferrals: stats?.pendingReferrals || 0,
      confirmedReferrals: stats?.confirmedReferrals || 0,
      flaggedReferrals: stats?.flaggedReferrals || 0,
      consumedBonuses: stats?.consumedBonuses || 0,
      averageTierBonus: stats?.avgTierBonus?.toFixed(2) || '0.00',
      referralsByTier: tierStats
    });
  } catch (error) {
    logger.error('Error getting referral stats:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// ============== QR CODE ENDPOINTS ==============

/**
 * GET /api/v1/referrals/qr/:referralCode
 * Generate QR code for a referral code (returns PNG image)
 */
router.get('/qr/:referralCode', async (req, res) => {
  try {
    const { referralCode } = req.params;
    const size = parseInt(req.query.size) || 300;
    const format = req.query.format || 'png';

    // Validate referral code format
    if (!referralCode || referralCode.length < 5) {
      return res.status(400).json({
        success: false,
        error: 'Invalid referral code format'
      });
    }

    // Generate QR code
    if (format === 'svg') {
      const result = await qrCodeService.generateSVG(
        `${process.env.API_BASE_URL || 'https://coopvest.app'}/register?ref=${referralCode}`,
        { width: size }
      );

      res.setHeader('Content-Type', 'image/svg+xml');
      res.setHeader('Cache-Control', 'public, max-age=86400'); // Cache for 24 hours
      res.send(result.svg);
    } else {
      const result = await qrCodeService.generateBuffer(
        `${process.env.API_BASE_URL || 'https://coopvest.app'}/register?ref=${referralCode}`,
        { width: size }
      );

      res.setHeader('Content-Type', 'image/png');
      res.setHeader('Cache-Control', 'public, max-age=86400'); // Cache for 24 hours
      res.send(result.buffer);
    }
  } catch (error) {
    logger.error('Error generating QR code:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals/qr-data/:referralCode
 * Get QR code as base64 data URL (JSON response)
 */
router.get('/qr-data/:referralCode', async (req, res) => {
  try {
    const { referralCode } = req.params;
    const size = parseInt(req.query.size) || 300;
    const color = req.query.color || '#1B5E20';

    // Validate referral code format
    if (!referralCode || referralCode.length < 5) {
      return res.status(400).json({
        success: false,
        error: 'Invalid referral code format'
      });
    }

    // Generate QR code as data URL
    const result = await qrCodeService.generateReferralQR(referralCode, {
      size,
      color: {
        dark: color,
        light: '#FFFFFF'
      }
    });

    res.json({
      success: true,
      referralCode: result.referralCode,
      registrationUrl: result.registrationUrl,
      qrCode: result.qrCode, // Base64 data URL
      format: 'png',
      size: result.size,
      expiresAt: null // Permanent QR code
    });
  } catch (error) {
    logger.error('Error generating QR code data URL:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/referrals/qr/generate
 * Generate QR code with custom options (JSON body)
 */
router.post('/qr/generate', [
  body('referralCode').notEmpty().withMessage('Referral code is required'),
  body('size').optional().isInt({ min: 100, max: 1000 }),
  body('color').optional().isHexColor()
], validate, async (req, res) => {
  try {
    const { referralCode, size = 300, color = '#1B5E20' } = req.body;

    // Generate QR code
    const result = await qrCodeService.generateReferralQR(referralCode, {
      size,
      color: {
        dark: color,
        light: '#FFFFFF'
      }
    });

    res.json({
      success: true,
      referralCode: result.referralCode,
      registrationUrl: result.registrationUrl,
      qrCode: result.qrCode,
      format: 'png',
      size: result.size
    });
  } catch (error) {
    logger.error('Error generating QR code:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/referrals/qr/temporary
 * Generate temporary QR code with expiry time
 */
router.post('/qr/temporary', [
  body('referralCode').notEmpty().withMessage('Referral code is required'),
  body('expiryMinutes').optional().isInt({ min: 5, max: 1440 })
], validate, async (req, res) => {
  try {
    const { referralCode, expiryMinutes = 60 } = req.body;

    // Generate temporary QR code
    const result = await qrCodeService.generateTemporaryQR(
      referralCode,
      expiryMinutes
    );

    res.json({
      success: true,
      referralCode: result.referralCode,
      temporaryId: result.temporaryId,
      expiresAt: result.expiresAt,
      qrCode: result.qrCode,
      format: 'png',
      message: `QR code expires at ${new Date(result.expiresAt).toLocaleString()}`
    });
  } catch (error) {
    logger.error('Error generating temporary QR code:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/referrals/qr/stats
 * Get QR code generation stats and options
 */
router.get('/qr/stats', async (req, res) => {
  try {
    const stats = qrCodeService.getQRStats();
    
    res.json({
      success: true,
      ...stats,
      baseUrl: process.env.API_BASE_URL || 'https://coopvest.app',
      endpoints: {
        generate: {
          'GET /qr/:code': 'Get QR code as PNG image',
          'GET /qr-data/:code': 'Get QR code as base64 data URL',
          'POST /qr/generate': 'Generate with custom options',
          'POST /qr/temporary': 'Generate temporary QR with expiry'
        },
        parameters: {
          size: '100-1000px (default: 300)',
          color: 'Hex color code (default: #1B5E20)',
          format: 'png or svg',
          expiryMinutes: '5-1440 (default: 60)'
        }
      }
    });
  } catch (error) {
    logger.error('Error getting QR stats:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/referrals/qr/batch
 * Generate QR codes for multiple referral codes
 */
router.post('/qr/batch', [
  body('referralCodes').isArray({ min: 1, max: 100 }).withMessage('referralCodes must be an array'),
  body('referralCodes.*').isString().notEmpty()
], validate, async (req, res) => {
  try {
    const { referralCodes, size = 300 } = req.body;

    // Generate batch QR codes
    const result = await qrCodeService.generateBatchReferralQRCodes(
      referralCodes,
      { size }
    );

    res.json({
      success: true,
      totalGenerated: result.totalGenerated,
      qrCodes: result.qrCodes.map(qr => ({
        referralCode: qr.referralCode,
        qrCode: qr.qrCode,
        format: qr.format,
        size: qr.size
      }))
    });
  } catch (error) {
    logger.error('Error generating batch QR codes:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;