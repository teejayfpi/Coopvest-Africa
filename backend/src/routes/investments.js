/**
 * Investment Routes
 * 
 * Investment pool endpoints
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { InvestmentPool, User, Wallet, AuditLog } = require('../models');
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
 * GET /api/v1/investments/pools
 * Get all available investment pools
 */
router.get('/pools', authenticate, async (req, res) => {
  try {
    const { type, status } = req.query;
    
    let query = { status: 'open' };
    if (type) query.type = type;
    if (status) query.status = status;

    const pools = await InvestmentPool.find(query).sort({ createdAt: -1 });

    const poolsWithProgress = pools.map(pool => ({
      poolId: pool.poolId,
      name: pool.name,
      description: pool.description,
      type: pool.type,
      targetAmount: pool.targetAmount,
      currentAmount: pool.currentAmount,
      progressPercentage: pool.progressPercentage,
      minimumInvestment: pool.minimumInvestment,
      maximumInvestment: pool.maximumInvestment,
      expectedReturnRate: pool.expectedReturnRate,
      durationMonths: pool.durationMonths,
      riskLevel: pool.riskLevel,
      daysRemaining: pool.daysRemaining,
      status: pool.status
    }));

    res.json({
      success: true,
      pools: poolsWithProgress,
      total: poolsWithProgress.length
    });
  } catch (error) {
    logger.error('Get investment pools error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/investments/pools/:poolId
 * Get specific investment pool details
 */
router.get('/pools/:poolId', authenticate, async (req, res) => {
  try {
    const { poolId } = req.params;

    const pool = await InvestmentPool.findOne({ poolId });

    if (!pool) {
      return res.status(404).json({
        success: false,
        error: 'Investment pool not found'
      });
    }

    res.json({
      success: true,
      pool: {
        poolId: pool.poolId,
        name: pool.name,
        description: pool.description,
        type: pool.type,
        targetAmount: pool.targetAmount,
        currentAmount: pool.currentAmount,
        progressPercentage: pool.progressPercentage,
        minimumInvestment: pool.minimumInvestment,
        maximumInvestment: pool.maximumInvestment,
        expectedReturnRate: pool.expectedReturnRate,
        durationMonths: pool.durationMonths,
        riskLevel: pool.riskLevel,
        daysRemaining: pool.daysRemaining,
        startDate: pool.startDate,
        endDate: pool.endDate,
        project: pool.project,
        participantCount: pool.participantCount,
        status: pool.status
      }
    });
  } catch (error) {
    logger.error('Get investment pool error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/investments/participate
 * Participate in an investment pool
 */
router.post('/participate', authenticate, [
  body('poolId').notEmpty(),
  body('amount').isFloat({ min: 100 })
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { poolId, amount } = req.body;

    const pool = await InvestmentPool.findOne({ poolId });

    if (!pool) {
      return res.status(404).json({
        success: false,
        error: 'Investment pool not found'
      });
    }

    if (pool.status !== 'open' && pool.status !== 'funding') {
      return res.status(400).json({
        success: false,
        error: 'This pool is not accepting investments'
      });
    }

    if (amount < pool.minimumInvestment) {
      return res.status(400).json({
        success: false,
        error: `Minimum investment is ₦${pool.minimumInvestment.toLocaleString()}`
      });
    }

    if (amount > pool.maximumInvestment) {
      return res.status(400).json({
        success: false,
        error: `Maximum investment is ₦${pool.maximumInvestment.toLocaleString()}`
      });
    }

    // Check wallet balance
    const wallet = await Wallet.findOne({ userId });
    if (!wallet || wallet.balance < amount) {
      return res.status(400).json({
        success: false,
        error: 'Insufficient wallet balance'
      });
    }

    const participationId = `INV-${uuidv4().substring(0, 8).toUpperCase()}`;
    const purchasePrice = 1; // ₦1 per unit initially

    const participation = {
      participationId,
      userId,
      amount,
      units: amount * purchasePrice,
      purchasePrice,
      investedAt: new Date(),
      status: 'active',
      currentValue: amount,
      profitLoss: 0,
      profitLossPercent: 0
    };

    pool.participants.push(participation);
    pool.currentAmount += amount;
    pool.participantCount = pool.participants.filter(p => p.status === 'active').length;

    if (pool.currentAmount >= pool.targetAmount) {
      pool.status = 'funding';
    }

    await pool.save();

    // Deduct from wallet
    wallet.balance -= amount;
    wallet.transactions.push({
      transactionId: `TXN-${uuidv4().substring(0, 8).toUpperCase()}`,
      type: 'deposit',
      amount: amount,
      description: `Investment in: ${pool.name}`,
      status: 'completed',
      createdAt: new Date()
    });
    await wallet.save();

    // Log audit
    await AuditLog.log({
      action: 'INVESTMENT_PARTICIPATED',
      userId,
      details: `Invested ₦${amount} in pool: ${pool.name}`
    });

    res.json({
      success: true,
      participation: {
        participationId,
        amount,
        units: participation.units,
        poolName: pool.name,
        currentValue: amount
      },
      message: 'Investment successful'
    });
  } catch (error) {
    logger.error('Investment participation error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/investments/portfolio
 * Get user's investment portfolio
 */
router.get('/portfolio', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    const pools = await InvestmentPool.find({ 'participants.userId': userId });

    const portfolio = pools.map(pool => {
      const participation = pool.participants.find(p => p.userId === userId && p.status === 'active');
      if (!participation) return null;

      const currentValue = pool.calculateCurrentValue(userId);
      const profitLoss = currentValue - participation.amount;
      const profitLossPercent = (profitLoss / participation.amount) * 100;

      return {
        poolId: pool.poolId,
        poolName: pool.name,
        type: pool.type,
        amount: participation.amount,
        units: participation.units,
        currentValue,
        profitLoss,
        profitLossPercent: profitLossPercent.toFixed(2),
        expectedReturnRate: pool.expectedReturnRate,
        investedAt: participation.investedAt
      };
    }).filter(p => p !== null);

    const totalInvested = portfolio.reduce((sum, p) => sum + p.amount, 0);
    const totalCurrentValue = portfolio.reduce((sum, p) => sum + p.currentValue, 0);
    const totalProfitLoss = portfolio.reduce((sum, p) => sum + p.profitLoss, 0);

    res.json({
      success: true,
      portfolio: {
        investments: portfolio,
        totalInvested,
        totalCurrentValue,
        totalProfitLoss,
        totalProfitLossPercent: totalInvested > 0 ? ((totalProfitLoss / totalInvested) * 100).toFixed(2) : 0
      }
    });
  } catch (error) {
    logger.error('Get portfolio error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/investments/returns
 * Get investment returns/dividends
 */
router.get('/returns', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    // For demo purposes, return mock returns
    const returns = {
      totalDividends: 0,
      pendingDividends: 0,
      reinvestedAmount: 0,
      history: []
    };

    res.json({
      success: true,
      returns
    });
  } catch (error) {
    logger.error('Get returns error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
