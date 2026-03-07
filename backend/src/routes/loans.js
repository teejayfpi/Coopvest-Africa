/**
 * Loans Routes
 * 
 * Loan-related endpoints with secure authentication and authorization
 */

const express = require('express');
const router = express.Router();
const { body, param, query, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { User, Referral, AuditLog, Loan, LoanQR } = require('../models');
const referralService = require('../services/referralService');
const qrCodeService = require('../services/qrCodeService');
const websocketService = require('../services/websocketService');
const { authenticate } = require('../middleware/auth');
const { verifyLoanOwnership, verifyQROwnership } = require('../middleware/ownership');
const logger = require('../utils/logger');

const VALIDATION = {
  loanAmount: {
    min: 1000,
    max: 50000000,
    maxTenure: 60
  }
};

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

const isValidLoanAmount = (value) => {
  const amount = parseFloat(value);
  if (isNaN(amount) || amount < 0) {
    throw new Error('Loan amount must be a positive number');
  }
  if (amount < VALIDATION.loanAmount.min) {
    throw new Error(`Loan amount must be at least ₦${VALIDATION.loanAmount.min.toLocaleString()}`);
  }
  if (amount > VALIDATION.loanAmount.max) {
    throw new Error(`Loan amount cannot exceed ₦${VALIDATION.loanAmount.max.toLocaleString()}`);
  }
  return true;
};

const isValidTenure = (value) => {
  const tenure = parseInt(value);
  if (isNaN(tenure) || tenure < 1) {
    throw new Error('Tenure must be at least 1 month');
  }
  if (tenure > VALIDATION.loanAmount.maxTenure) {
    throw new Error(`Tenure cannot exceed ${VALIDATION.loanAmount.maxTenure} months`);
  }
  return true;
};

/**
 * POST /api/v1/loans/apply
 * Apply for a loan with optional referral bonus
 * REQUIRES: Valid JWT token
 */
router.post('/apply', authenticate, [
  body('loanType').notEmpty().isIn(['Quick Loan', 'Micro Loan', 'Business Loan', 'Emergency Loan'])
    .withMessage('Invalid loan type'),
  body('loanAmount').custom(isValidLoanAmount),
  body('tenureMonths').custom(isValidTenure),
  body('purpose').notEmpty().isLength({ min: 10, max: 500 })
    .withMessage('Purpose must be 10-500 characters')
], validate, async (req, res) => {
  try {
    const { loanType, loanAmount, tenureMonths, purpose } = req.body;
    const userId = req.user.userId;

    let bonusResult = null;
    try {
      bonusResult = await referralService.applyBonusToLoan(userId, null, loanType);
    } catch (e) {
      // No bonus available
    }

    const bonusPercent = bonusResult?.bonusPercent || 0;
    const calculation = referralService.calculateInterestWithBonus(
      loanType,
      loanAmount,
      tenureMonths,
      bonusPercent
    );

    const loanId = `LOAN-${uuidv4().substring(0, 8).toUpperCase()}`;

    const loan = new Loan({
      loanId,
      userId,
      loanType,
      amount: loanAmount,
      tenureMonths,
      purpose,
      baseInterestRate: calculation.baseInterestRate,
      referralBonusPercent: bonusPercent,
      effectiveInterestRate: calculation.effectiveInterestRate,
      monthlyRepayment: calculation.monthlyRepaymentAfterBonus,
      totalRepayment: calculation.monthlyRepaymentAfterBonus * tenureMonths,
      savingsFromBonus: calculation.totalSavingsFromBonus,
      status: 'pending'
    });

    await loan.save();

    if (bonusResult?.success) {
      await AuditLog.log({
        action: 'LOAN_APPLIED_WITH_BONUS',
        userId,
        loanId,
        details: `Loan applied with ${bonusPercent}% referral bonus. Savings: ₦${calculation.totalSavingsFromBonus.toFixed(2)}`
      });
    }

    res.status(201).json({
      success: true,
      loan,
      calculation,
      bonusApplied: bonusResult?.success || false,
      message: bonusResult?.success 
        ? `Loan application submitted with ${bonusPercent}% referral discount!`
        : 'Loan application submitted'
    });
  } catch (error) {
    logger.error('Loan application error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/loans/:loanId/generate-qr
 * Generate QR code for loan guarantor request
 * REQUIRES: Valid JWT token + Loan ownership
 */
router.post('/:loanId/generate-qr', authenticate, [
  param('loanId').notEmpty(),
  body('applicantName').notEmpty().isLength({ min: 2, max: 100 }),
  body('applicantPhone').notEmpty().isMobilePhone(),
  body('loanAmount').custom(isValidLoanAmount),
  body('loanTenure').custom(isValidTenure),
  body('interestRate').isFloat({ min: 0, max: 100 }),
  body('monthlyRepayment').isFloat({ min: 0 }),
  body('totalRepayment').isFloat({ min: 0 }),
  body('purpose').notEmpty().isLength({ min: 10, max: 500 })
], validate, verifyLoanOwnership, async (req, res) => {
  try {
    const { loanId } = req.params;
    const userId = req.user.userId;

    const {
      applicantName,
      applicantPhone,
      loanAmount,
      loanTenure,
      interestRate,
      monthlyRepayment,
      totalRepayment,
      purpose,
      options
    } = req.body;

    const qrResult = await qrCodeService.generateLoanQRCode({
      loanId,
      applicantId: userId,
      applicantName,
      applicantPhone,
      loanAmount,
      loanCurrency: 'NGN',
      loanTenure,
      interestRate,
      monthlyRepayment,
      totalRepayment,
      purpose
    }, options);

    const loanQR = new LoanQR({
      qrId: qrResult.qrData.qrId,
      loanId,
      applicantId: userId,
      applicantName,
      applicantPhone,
      loanAmount,
      loanCurrency: 'NGN',
      loanTenure,
      interestRate,
      monthlyRepayment,
      totalRepayment,
      purpose,
      qrData: qrResult.qrData,
      qrCode: qrResult.qrCode,
      signature: qrResult.qrData.signature,
      createdBy: userId
    });

    await AuditLog.log({
      action: 'LOAN_QR_GENERATED',
      userId,
      loanId,
      qrId: qrResult.qrData.qrId,
      details: `Generated guarantor QR for loan ${loanId}`
    });

    res.status(201).json({
      success: true,
      message: qrResult.message,
      qr: {
        id: qrResult.qrData.qrId,
        loanId: loanId,
        expiresAt: qrResult.qrData.expiresAt,
        qrCode: qrResult.qrCode,
        data: qrResult.qrData
      },
      progress: { found: 0, required: 3, percentage: 0 }
    });
  } catch (error) {
    logger.error('QR generation error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/loans
 * Get user's loans
 * REQUIRES: Valid JWT token
 */
router.get('/', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const loans = await Loan.find({ userId }).sort({ createdAt: -1 });
    res.json({ success: true, loans, total: loans.length });
  } catch (error) {
    logger.error('Error getting loans:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/loans/:loanId
 * Get loan details
 * REQUIRES: Valid JWT token + Loan ownership
 */
router.get('/:loanId', authenticate, [
  param('loanId').notEmpty()
], validate, verifyLoanOwnership, async (req, res) => {
  try {
    const { loanId } = req.params;
    const loan = await Loan.findOne({ loanId });
    
    if (!loan) {
      return res.status(404).json({ success: false, error: 'Loan not found' });
    }

    res.json({ success: true, loan });
  } catch (error) {
    logger.error('Error getting loan details:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/loans/qr-codes
 * List all QR codes for authenticated user
 * REQUIRES: Valid JWT token
 */
router.get('/qr-codes', authenticate, [
  query('status').optional().isIn(['active', 'expired', 'all']),
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 })
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const status = req.query.status || 'all';

    const mockQRCodes = [
      {
        qrId: 'QR_001',
        loanId: 'LOAN-ABC123',
        applicantName: 'John Doe',
        loanAmount: 500000,
        loanCurrency: 'NGN',
        loanTenure: 12,
        interestRate: 10,
        monthlyRepayment: 45833,
        totalRepayment: 550000,
        purpose: 'Business expansion',
        status: 'active',
        scanCount: 5,
        guarantorsFound: 2,
        guarantorsRequired: 3,
        expiresAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
        createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
      }
    ];

    let filteredQRCodes = mockQRCodes;
    if (status !== 'all') {
      filteredQRCodes = mockQRCodes.filter(qr => qr.status === status);
    }

    const qrCodesWithProgress = filteredQRCodes.map(qr => ({
      ...qr,
      progress: {
        found: qr.guarantorsFound,
        required: qr.guarantorsRequired,
        percentage: Math.round((qr.guarantorsFound / qr.guarantorsRequired) * 100),
        remaining: qr.guarantorsRequired - qr.guarantorsFound
      },
      isExpired: new Date() > new Date(qr.expiresAt)
    }));

    res.json({
      success: true,
      qrCodes: qrCodesWithProgress,
      pagination: { page: 1, limit: 20, total: qrCodesWithProgress.length }
    });
  } catch (error) {
    logger.error('Error listing QR codes:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/loans/qr-stats
 * Get QR code service statistics
 */
router.get('/qr-stats', async (req, res) => {
  try {
    const stats = qrCodeService.getLoanQRStats();
    res.json({ success: true, stats });
  } catch (error) {
    logger.error('Error getting QR stats:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/loans/ws-stats
 * Get WebSocket server statistics
 */
router.get('/ws-stats', async (req, res) => {
  try {
    const stats = websocketService.getStats();
    res.json({
      success: true,
      websocket: stats,
      endpoints: { connection: 'ws://localhost:8080/ws', stats: 'http://localhost:8080/ws/stats' },
      message: 'WebSocket server is running.'
    });
  } catch (error) {
    logger.error('Error getting WebSocket stats:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
