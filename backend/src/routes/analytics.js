/**
 * Analytics Routes
 * API endpoints for user analytics and reporting
 */

const express = require('express');
const router = express.Router();
const { Transaction, SavingsGoal, InvestmentPool, Wallet } = require('../models');
const { auth: authMiddleware } = require('../middleware/auth');

// All routes require authentication
router.use(authMiddleware);

/**
 * GET /api/v1/analytics/overview
 * Get overall financial overview
 */
router.get('/overview', async (req, res) => {
  try {
    const { period = '30d' } = req.query;

    // Calculate date range
    const days = parseInt(period) || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // Get wallet balance
    const wallet = await Wallet.findOne({ user: req.user.id });
    const walletBalance = wallet?.balance || 0;

    // Get active savings
    const activeSavings = await SavingsGoal.find({
      user: req.user.id,
      status: { $in: ['active', 'completed'] }
    });
    const totalSavings = activeSavings.reduce((sum, s) => sum + (s.currentAmount || 0), 0);

    // Get investments
    const investments = await InvestmentPool.find({
      'members.user': req.user.id,
      status: 'active'
    });
    const totalInvestments = investments.reduce((sum, i) => {
      const userInvestment = i.members.find(m => m.user.toString() === req.user.id);
      return sum + (userInvestment?.amount || 0);
    }, 0);

    // Get recent transactions
    const recentTransactions = await Transaction.find({
      user: req.user.id,
      createdAt: { $gte: startDate },
      status: 'completed'
    })
      .sort({ createdAt: -1 })
      .limit(10);

    // Calculate period stats
    const periodTransactions = await Transaction.getSummary(req.user.id, startDate);
    const periodCredits = periodTransactions.totalCredits || 0;
    const periodDebits = periodTransactions.totalDebits || 0;

    res.json({
      success: true,
      data: {
        wallet: {
          balance: walletBalance,
          currency: 'NGN'
        },
        savings: {
          total: totalSavings,
          activeGoals: activeSavings.filter(s => s.status === 'active').length,
          completedGoals: activeSavings.filter(s => s.status === 'completed').length
        },
        investments: {
          total: totalInvestments,
          activePools: investments.length
        },
        period: {
          days,
          credits: periodCredits,
          debits: periodDebits,
          netFlow: periodCredits - periodDebits
        },
        recentTransactions
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
 * GET /api/v1/analytics/savings
 * Get savings analytics
 */
router.get('/savings', async (req, res) => {
  try {
    const { months = 6 } = req.query;

    // Get all savings goals
    const goals = await SavingsGoal.find({ user: req.user.id });

    // Calculate totals
    const totalSaved = goals.reduce((sum, g) => sum + (g.currentAmount || 0), 0);
    const totalTarget = goals.reduce((sum, g) => sum + (g.targetAmount || 0), 0);
    const activeGoals = goals.filter(g => g.status === 'active');
    const completedGoals = goals.filter(g => g.status === 'completed');

    // Get monthly breakdown
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - parseInt(months));

    const monthlyStats = await SavingsGoal.aggregate([
      {
        $match: {
          user: req.user._id,
          createdAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: {
            year: { $year: '$createdAt' },
            month: { $month: '$createdAt' }
          },
          totalDeposited: { $sum: '$currentAmount' },
          goalCount: { $sum: 1 }
        }
      },
      {
        $sort: { '_id.year': 1, '_id.month': 1 }
      }
    ]);

    // Calculate progress
    const goalsWithProgress = activeGoals.map(g => ({
      id: g._id,
      name: g.name,
      target: g.targetAmount,
      current: g.currentAmount,
      progress: g.targetAmount > 0 ? ((g.currentAmount / g.targetAmount) * 100).toFixed(1) : 0,
      remaining: Math.max(0, g.targetAmount - g.currentAmount),
      targetDate: g.targetDate,
      daysRemaining: g.targetDate
        ? Math.ceil((new Date(g.targetDate) - new Date()) / (1000 * 60 * 60 * 24))
        : null
    }));

    res.json({
      success: true,
      data: {
        summary: {
          totalSaved,
          totalTarget,
          completionRate: goals.length > 0 ? ((completedGoals.length / goals.length) * 100).toFixed(1) : 0,
          activeGoals: activeGoals.length,
          completedGoals: completedGoals.length
        },
        monthlyBreakdown: monthlyStats,
        goalsWithProgress
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
 * GET /api/v1/analytics/investments
 * Get investment analytics
 */
router.get('/investments', async (req, res) => {
  try {
    // Get active investments
    const investments = await InvestmentPool.find({
      'members.user': req.user.id,
      status: { $in: ['active', 'completed'] }
    });

    // Calculate totals
    let totalInvested = 0;
    let totalReturns = 0;
    let totalProfit = 0;

    const investmentDetails = investments.map(inv => {
      const userMember = inv.members.find(m => m.user.toString() === req.user.id);
      const invested = userMember?.amount || 0;
      const currentValue = userMember?.currentValue || invested;
      const profit = currentValue - invested;

      totalInvested += invested;
      totalReturns += currentValue;
      totalProfit += profit;

      return {
        id: inv._id,
        name: inv.name,
        category: inv.category,
        invested,
        currentValue,
        profit,
        returnPercentage: invested > 0 ? ((profit / invested) * 100).toFixed(2) : 0,
        maturityDate: inv.maturityDate,
        status: inv.status
      };
    });

    // Performance by category
    const byCategory = {};
    investmentDetails.forEach(inv => {
      if (!byCategory[inv.category]) {
        byCategory[inv.category] = { invested: 0, returns: 0, profit: 0, count: 0 };
      }
      byCategory[inv.category].invested += inv.invested;
      byCategory[inv.category].returns += inv.currentValue;
      byCategory[inv.category].profit += inv.profit;
      byCategory[inv.category].count += 1;
    });

    res.json({
      success: true,
      data: {
        summary: {
          totalInvested,
          totalReturns,
          totalProfit,
          overallReturn: totalInvested > 0 ? ((totalProfit / totalInvested) * 100).toFixed(2) : 0,
          activeInvestments: investments.filter(i => i.status === 'active').length,
          completedInvestments: investments.filter(i => i.status === 'completed').length
        },
        details: investmentDetails,
        byCategory: Object.entries(byCategory).map(([category, data]) => ({
          category,
          ...data,
          returnPercentage: data.invested > 0 ? ((data.profit / data.invested) * 100).toFixed(2) : 0
        }))
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
 * GET /api/v1/analytics/transactions
 * Get transaction analytics
 */
router.get('/transactions', async (req, res) => {
  try {
    const { months = 6 } = req.query;

    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - parseInt(months));

    // Get transaction breakdown by type
    const byType = await Transaction.aggregate([
      {
        $match: {
          user: req.user._id,
          status: 'completed',
          createdAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: '$type',
          totalAmount: { $sum: '$amount' },
          count: { $sum: 1 }
        }
      },
      { $sort: { totalAmount: -1 } }
    ]);

    // Get daily totals for chart
    const dailyTotals = await Transaction.aggregate([
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
            date: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
            category: '$category'
          },
          total: { $sum: '$amount' }
        }
      },
      { $sort: { '_id.date': 1 } }
    ]);

    // Format daily totals
    const chartData = {};
    dailyTotals.forEach(item => {
      const date = item._id.date;
      if (!chartData[date]) {
        chartData[date] = { date, credits: 0, debits: 0 };
      }
      if (item._id.category === 'credit') {
        chartData[date].credits = item.total;
      } else {
        chartData[date].debits = item.total;
      }
    });

    res.json({
      success: true,
      data: {
        byType: byType.map(t => ({
          type: t._id,
          totalAmount: t.totalAmount,
          count: t.count
        })),
        chartData: Object.values(chartData)
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
 * GET /api/v1/analytics/performance
 * Get overall performance metrics
 */
router.get('/performance', async (req, res) => {
  try {
    const { year = new Date().getFullYear() } = req.query;

    const startDate = new Date(year, 0, 1);
    const endDate = new Date(year, 11, 31, 23, 59, 59);

    // Get yearly transaction summary
    const yearlySummary = await Transaction.getSummary(req.user.id, startDate, endDate);

    // Get monthly breakdown
    const monthlyBreakdown = await Transaction.aggregate([
      {
        $match: {
          user: req.user._id,
          status: 'completed',
          createdAt: { $gte: startDate, $lte: endDate }
        }
      },
      {
        $group: {
          _id: { month: { $month: '$createdAt' } },
          credits: {
            $sum: {
              $cond: [{ $eq: ['$category', 'credit'] }, '$amount', 0]
            }
          },
          debits: {
            $sum: {
              $cond: [{ $eq: ['$category', 'debit'] }, '$amount', 0]
            }
          },
          transactionCount: { $sum: 1 }
        }
      },
      { $sort: { '_id.month': 1 } }
    ]);

    // Get savings performance
    const savingsStartOfYear = await SavingsGoal.aggregate([
      {
        $match: {
          user: req.user._id,
          createdAt: { $lt: startDate }
        }
      },
      {
        $group: {
          _id: null,
          total: { $sum: '$currentAmount' }
        }
      }
    ]);

    const savingsEndOfYear = await SavingsGoal.aggregate([
      {
        $match: {
          user: req.user._id,
          createdAt: { $lte: endDate }
        }
      },
      {
        $group: {
          _id: null,
          total: { $sum: '$currentAmount' }
        }
      }
    ]);

    const savingsGrowth = (savingsEndOfYear[0]?.total || 0) - (savingsStartOfYear[0]?.total || 0);

    res.json({
      success: true,
      data: {
        year: parseInt(year),
        transactions: {
          credits: yearlySummary.totalCredits || 0,
          debits: yearlySummary.totalDebits || 0,
          netFlow: (yearlySummary.totalCredits || 0) - (yearlySummary.totalDebits || 0),
          count: yearlySummary.transactionCount || 0
        },
        savings: {
          growth: savingsGrowth,
          endBalance: savingsEndOfYear[0]?.total || 0
        },
        monthlyBreakdown: monthlyBreakdown.map(m => ({
          month: m._id.month,
          credits: m.credits,
          debits: m.debits,
          netFlow: m.credits - m.debits,
          transactions: m.transactionCount
        }))
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
