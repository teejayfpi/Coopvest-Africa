/**
 * Transactions Routes
 * API endpoints for viewing transaction history
 */

const express = require('express');
const router = express.Router();
const { Transaction } = require('../models');
const { auth: authMiddleware } = require('../middleware/auth');

// All routes require authentication
router.use(authMiddleware);

/**
 * GET /api/v1/transactions
 * Get transaction history for current user
 */
router.get('/', async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      type,
      status,
      startDate,
      endDate,
      category
    } = req.query;

    const result = await Transaction.getHistory(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
      type,
      status,
      startDate,
      endDate
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/transactions/summary
 * Get transaction summary for current user
 */
router.get('/summary', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    const summary = await Transaction.getSummary(
      req.user.id,
      startDate ? new Date(startDate) : undefined,
      endDate ? new Date(endDate) : undefined
    );

    res.json({
      success: true,
      data: {
        ...summary,
        netFlow: (summary.totalCredits || 0) - (summary.totalDebits || 0)
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/transactions/credits
 * Get only credit transactions
 */
router.get('/credits', async (req, res) => {
  try {
    const { page = 1, limit = 20, startDate, endDate } = req.query;

    const result = await Transaction.getHistory(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
      category: 'credit',
      startDate,
      endDate
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/transactions/debits
 * Get only debit transactions
 */
router.get('/debits', async (req, res) => {
  try {
    const { page = 1, limit = 20, startDate, endDate } = req.query;

    const result = await Transaction.getHistory(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
      category: 'debit',
      startDate,
      endDate
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/transactions/by-type/:type
 * Get transactions by specific type
 */
router.get('/by-type/:type', async (req, res) => {
  try {
    const { type } = req.params;
    const { page = 1, limit = 20 } = req.query;

    const validTypes = [
      'deposit', 'withdrawal', 'transfer_in', 'transfer_out',
      'investment', 'investment_return', 'savings_deposit', 'savings_withdrawal',
      'loan_disbursement', 'loan_repayment', 'referral_bonus', 'interest',
      'fee', 'refund', 'adjustment', 'rollover'
    ];

    if (!validTypes.includes(type)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid transaction type'
      });
    }

    const result = await Transaction.getHistory(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
      type
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/transactions/:id
 * Get single transaction details
 */
router.get('/:id', async (req, res) => {
  try {
    const transaction = await Transaction.findOne({
      _id: req.params.id,
      user: req.user.id
    })
      .populate('wallet')
      .populate('savingsGoal', 'name')
      .populate('investmentPool', 'name')
      .populate('loan')
      .populate('bankAccount', 'bankName accountNumber');

    if (!transaction) {
      return res.status(404).json({
        success: false,
        error: 'Transaction not found'
      });
    }

    res.json({
      success: true,
      data: transaction
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/transactions/reference/:reference
 * Get transaction by reference number
 */
router.get('/reference/:reference', async (req, res) => {
  try {
    const transaction = await Transaction.findOne({
      reference: req.params.reference,
      user: req.user.id
    })
      .populate('wallet')
      .populate('savingsGoal', 'name')
      .populate('investmentPool', 'name');

    if (!transaction) {
      return res.status(404).json({
        success: false,
        error: 'Transaction not found'
      });
    }

    res.json({
      success: true,
      data: transaction
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/transactions/monthly-stats
 * Get monthly transaction statistics
 */
router.get('/stats/monthly', async (req, res) => {
  try {
    const { months = 6 } = req.query;
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - parseInt(months));

    const stats = await Transaction.aggregate([
      {
        $match: {
          user: req.user._id,
          status: 'completed',
          createdAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: {
            year: { $year: '$createdAt' },
            month: { $month: '$createdAt' },
            category: '$category'
          },
          totalAmount: { $sum: '$amount' },
          count: { $sum: 1 }
        }
      },
      {
        $sort: { '_id.year': 1, '_id.month': 1 }
      }
    ]);

    // Format response
    const monthlyData = {};
    stats.forEach(stat => {
      const key = `${stat._id.year}-${String(stat._id.month).padStart(2, '0')}`;
      if (!monthlyData[key]) {
        monthlyData[key] = { month: key, credits: 0, debits: 0, transactions: 0 };
      }
      if (stat._id.category === 'credit') {
        monthlyData[key].credits = stat.totalAmount;
      } else {
        monthlyData[key].debits = stat.totalAmount;
      }
      monthlyData[key].transactions += stat.count;
    });

    res.json({
      success: true,
      data: Object.values(monthlyData)
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/transactions/generate-statement
 * Generate account statement for date range
 */
router.post('/statement', async (req, res) => {
  try {
    const { startDate, endDate, email } = req.body;

    if (!startDate || !endDate) {
      return res.status(400).json({
        success: false,
        error: 'Start date and end date are required'
      });
    }

    const result = await Transaction.getHistory(req.user.id, {
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      limit: 10000 // Get all transactions for statement
    });

    const summary = await Transaction.getSummary(
      req.user.id,
      new Date(startDate),
      new Date(endDate)
    );

    const statement = {
      period: { startDate, endDate },
      generatedAt: new Date().toISOString(),
      transactions: result.transactions,
      summary: {
        totalCredits: summary.totalCredits || 0,
        totalDebits: summary.totalDebits || 0,
        netFlow: (summary.totalCredits || 0) - (summary.totalDebits || 0),
        transactionCount: summary.transactionCount || 0
      }
    };

    // If email is provided, send statement via email
    if (email) {
      // TODO: Send email with statement
      // await sendStatementEmail(req.user.email, statement);
    }

    res.json({
      success: true,
      data: statement
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
