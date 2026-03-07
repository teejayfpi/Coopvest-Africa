/**
 * Rollover Routes
 * 
 * Loan extension/rollover endpoints
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { User, Loan, Rollover, AuditLog } = require('../models');
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
 * GET /api/v1/rollover/eligibility
 * Check if user is eligible for rollover
 */
router.get('/eligibility', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Get active loans
    const activeLoans = await Loan.find({ userId, status: 'active' });

    const eligibilityList = activeLoans.map(loan => ({
      loanId: loan.loanId,
      amount: loan.amount,
      tenureMonths: loan.tenureMonths,
      monthlyRepayment: loan.monthlyRepayment,
      remainingBalance: loan.amount * 0.7, // Simplified calculation
      remainingMonths: Math.max(1, loan.tenureMonths - 2),
      isEligible: loan.status === 'active',
      requirements: {
        noMissedPayments: true,
        kycVerified: true,
        minimumMembership: 3 // months
      }
    }));

    res.json({
      success: true,
      eligible: eligibilityList.length > 0,
      loans: eligibilityList
    });
  } catch (error) {
    logger.error('Check eligibility error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/rollover/request
 * Request loan rollover/extension
 */
router.post('/request', authenticate, [
  body('loanId').notEmpty(),
  body('requestedTenure').isInt({ min: 1, max: 24 }),
  body('reason').optional().isLength({ max: 500 })
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { loanId, requestedTenure, reason } = req.body;

    const loan = await Loan.findOne({ loanId, userId });

    if (!loan) {
      return res.status(404).json({
        success: false,
        error: 'Loan not found'
      });
    }

    if (loan.status !== 'active') {
      return res.status(400).json({
        success: false,
        error: 'Only active loans can be rolled over'
      });
    }

    const rolloverId = `ROL-${uuidv4().substring(0, 8).toUpperCase()}`;

    const rollover = new Rollover({
      rolloverId,
      loanId,
      userId,
      originalLoan: {
        amount: loan.amount,
        tenureMonths: loan.tenureMonths,
        interestRate: loan.baseInterestRate,
        monthlyRepayment: loan.monthlyRepayment,
        remainingBalance: loan.amount * 0.7,
        remainingMonths: Math.max(1, loan.tenureMonths - 2)
      },
      requestedTenure,
      requestedReason: reason || '',
      status: 'pending'
    });

    await rollover.save();

    // Log audit
    await AuditLog.log({
      action: 'ROLLOVER_REQUESTED',
      userId,
      loanId,
      details: `Rollover requested for ${requestedTenure} months`
    });

    res.status(201).json({
      success: true,
      rollover: {
        rolloverId: rollover.rolloverId,
        loanId: rollover.loanId,
        requestedTenure: rollover.requestedTenure,
        status: rollover.status
      },
      message: 'Rollover request submitted for review'
    });
  } catch (error) {
    logger.error('Request rollover error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/rollover/history
 * Get user's rollover history
 */
router.get('/history', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    const rollovers = await Rollover.find({ userId }).sort({ createdAt: -1 });

    const history = rollovers.map(r => ({
      rolloverId: r.rolloverId,
      loanId: r.loanId,
      requestedTenure: r.requestedTenure,
      status: r.status,
      submittedAt: r.submittedAt,
      approvedAt: r.approvedAt
    }));

    res.json({
      success: true,
      history,
      total: history.length
    });
  } catch (error) {
    logger.error('Get rollover history error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/rollover/:rolloverId
 * Get rollover details
 */
router.get('/:rolloverId', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { rolloverId } = req.params;

    const rollover = await Rollover.findOne({ rolloverId, userId });

    if (!rollover) {
      return res.status(404).json({
        success: false,
        error: 'Rollover not found'
      });
    }

    res.json({
      success: true,
      rollover: {
        rolloverId: rollover.rolloverId,
        loanId: rollover.loanId,
        originalLoan: rollover.originalLoan,
        requestedTenure: rollover.requestedTenure,
        newTerms: rollover.newTerms,
        status: rollover.status,
        submittedAt: rollover.submittedAt,
        reviewedAt: rollover.reviewedAt
      }
    });
  } catch (error) {
    logger.error('Get rollover details error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/rollover/:rolloverId/cancel
 * Cancel rollover request
 */
router.post('/:rolloverId/cancel', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { rolloverId } = req.params;

    const rollover = await Rollover.findOneAndUpdate(
      { rolloverId, userId, status: 'pending' },
      { $set: { status: 'cancelled' } },
      { new: true }
    );

    if (!rollover) {
      return res.status(404).json({
        success: false,
        error: 'Pending rollover not found'
      });
    }

    res.json({
      success: true,
      message: 'Rollover cancelled successfully'
    });
  } catch (error) {
    logger.error('Cancel rollover error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
