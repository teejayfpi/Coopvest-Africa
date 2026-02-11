/**
 * Savings Routes
 * 
 * Savings goals and contributions endpoints
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { User, Wallet, SavingsGoal, AuditLog } = require('../models');
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
 * GET /api/v1/savings/goals
 * Get all savings goals for user
 */
router.get('/goals', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const status = req.query.status || 'all';

    let query = { userId };
    if (status !== 'all') {
      query.status = status;
    }

    const goals = await SavingsGoal.find(query).sort({ createdAt: -1 });

    const goalsWithProgress = goals.map(goal => ({
      goalId: goal.goalId,
      name: goal.name,
      description: goal.description,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      monthlyContribution: goal.monthlyContribution,
      targetDate: goal.targetDate,
      category: goal.category,
      status: goal.status,
      progressPercentage: goal.progressPercentage,
      monthsRemaining: goal.monthsRemaining,
      isAchievable: goal.isAchievable(),
      createdAt: goal.createdAt
    }));

    res.json({
      success: true,
      goals: goalsWithProgress,
      total: goalsWithProgress.length
    });
  } catch (error) {
    logger.error('Get savings goals error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/savings/goals
 * Create a new savings goal
 */
router.post('/goals', authenticate, [
  body('name').isLength({ min: 2, max: 100 }),
  body('targetAmount').isFloat({ min: 100 }),
  body('targetDate').isISO8601(),
  body('category').isIn(['emergency', 'education', 'business', 'travel', 'vehicle', 'home', 'medical', 'wedding', 'other'])
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { name, description, targetAmount, targetDate, category, monthlyContribution, priority, color } = req.body;

    const goalId = `GOAL-${uuidv4().substring(0, 8).toUpperCase()}`;

    const goal = new SavingsGoal({
      goalId,
      userId,
      name,
      description: description || '',
      targetAmount,
      targetDate: new Date(targetDate),
      category,
      monthlyContribution: monthlyContribution || 0,
      priority: priority || 1,
      color: color || '#4CAF50'
    });

    await goal.save();

    res.status(201).json({
      success: true,
      goal: {
        goalId: goal.goalId,
        name: goal.name,
        targetAmount: goal.targetAmount,
        progressPercentage: goal.progressPercentage
      },
      message: 'Savings goal created successfully'
    });
  } catch (error) {
    logger.error('Create savings goal error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/savings/goals/:goalId
 * Get specific savings goal
 */
router.get('/goals/:goalId', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { goalId } = req.params;

    const goal = await SavingsGoal.findOne({ goalId, userId });

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    res.json({
      success: true,
      goal: {
        goalId: goal.goalId,
        name: goal.name,
        description: goal.description,
        targetAmount: goal.targetAmount,
        currentAmount: goal.currentAmount,
        monthlyContribution: goal.monthlyContribution,
        targetDate: goal.targetDate,
        category: goal.category,
        status: goal.status,
        progressPercentage: goal.progressPercentage,
        monthsRemaining: goal.monthsRemaining,
        isAchievable: goal.isAchievable(),
        createdAt: goal.createdAt
      }
    });
  } catch (error) {
    logger.error('Get savings goal error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PUT /api/v1/savings/goals/:goalId
 * Update savings goal
 */
router.put('/goals/:goalId', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { goalId } = req.params;
    const { name, description, targetAmount, monthlyContribution, targetDate, status } = req.body;

    const goal = await SavingsGoal.findOneAndUpdate(
      { goalId, userId },
      {
        $set: {
          ...(name && { name }),
          ...(description !== undefined && { description }),
          ...(targetAmount && { targetAmount }),
          ...(monthlyContribution !== undefined && { monthlyContribution }),
          ...(targetDate && { targetDate: new Date(targetDate) }),
          ...(status && { status })
        }
      },
      { new: true }
    );

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    res.json({
      success: true,
      goal,
      message: 'Goal updated successfully'
    });
  } catch (error) {
    logger.error('Update savings goal error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/savings/contribute
 * Add contribution to a goal
 */
router.post('/contribute', authenticate, [
  body('goalId').notEmpty(),
  body('amount').isFloat({ min: 100 })
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { goalId, amount } = req.body;

    const goal = await SavingsGoal.findOne({ goalId, userId });

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    if (goal.status !== 'active') {
      return res.status(400).json({
        success: false,
        error: 'Cannot contribute to inactive goal'
      });
    }

    // Update goal
    goal.currentAmount += amount;
    if (goal.currentAmount >= goal.targetAmount) {
      goal.status = 'completed';
      goal.completedAt = new Date();
    }

    await goal.save();

    // Update user savings
    await User.findOneAndUpdate(
      { userId },
      {
        $inc: {
          'savings.totalSaved': amount,
          'savings.consecutiveMonths': 1
        },
        $set: { 'savings.lastSavingsDate': new Date() }
      }
    );

    // Add transaction to wallet
    let wallet = await Wallet.findOne({ userId });
    if (wallet) {
      wallet.balance -= amount;
      wallet.transactions.push({
        transactionId: `TXN-${uuidv4().substring(0, 8).toUpperCase()}`,
        type: 'deposit',
        amount: amount,
        description: `Contribution to: ${goal.name}`,
        status: 'completed',
        createdAt: new Date()
      });
      await wallet.save();
    }

    // Log audit
    await AuditLog.log({
      action: 'SAVINGS_CONTRIBUTION',
      userId,
      details: `Contributed ₦${amount} to goal: ${goal.name}`
    });

    res.json({
      success: true,
      message: 'Contribution added successfully',
      goal: {
        goalId: goal.goalId,
        currentAmount: goal.currentAmount,
        progressPercentage: goal.progressPercentage,
        status: goal.status
      }
    });
  } catch (error) {
    logger.error('Add contribution error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * DELETE /api/v1/savings/goals/:goalId
 * Delete savings goal
 */
router.delete('/goals/:goalId', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { goalId } = req.params;

    const goal = await SavingsGoal.findOneAndDelete({ goalId, userId });

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    res.json({
      success: true,
      message: 'Goal deleted successfully'
    });
  } catch (error) {
    logger.error('Delete savings goal error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/savings/summary
 * Get savings summary
 */
router.get('/summary', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findOne({ userId });
    const goals = await SavingsGoal.find({ userId, status: 'active' });

    const totalTargetAmount = goals.reduce((sum, g) => sum + g.targetAmount, 0);
    const totalCurrentAmount = goals.reduce((sum, g) => sum + g.currentAmount, 0);

    res.json({
      success: true,
      summary: {
        totalSaved: user?.savings?.totalSaved || 0,
        monthlySavings: user?.savings?.monthlySavings || 0,
        consecutiveMonths: user?.savings?.consecutiveMonths || 0,
        activeGoals: goals.length,
        totalTargetAmount,
        totalCurrentAmount,
        overallProgress: totalTargetAmount > 0 ? (totalCurrentAmount / totalTargetAmount) * 100 : 0
      }
    });
  } catch (error) {
    logger.error('Get savings summary error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
