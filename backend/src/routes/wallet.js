/**
 * Wallet Routes
 * 
 * Wallet and transaction related endpoints
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { Wallet, User, AuditLog } = require('../models');
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
 * GET /api/v1/wallet/balance
 * Get user's wallet balance and recent transactions
 */
router.get('/balance', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    let wallet = await Wallet.findOne({ userId });
    
    if (!wallet) {
      wallet = new Wallet({
        userId,
        balance: 0,
        transactions: []
      });
      await wallet.save();
    }

    res.json({
      success: true,
      balance: wallet.balance,
      currency: wallet.currency,
      recentTransactions: wallet.transactions.slice(-5).reverse(),
      lastUpdated: wallet.lastUpdated
    });
  } catch (error) {
    logger.error('Error getting wallet balance:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/wallet/transactions
 * Get user's transaction history
 */
router.get('/transactions', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20, type } = req.query;

    const wallet = await Wallet.findOne({ userId });

    if (!wallet) {
      return res.json({
        success: true,
        transactions: [],
        total: 0,
        pagination: { page: 1, limit: 20 }
      });
    }

    let transactions = wallet.transactions.reverse();
    
    if (type && type !== 'all') {
      transactions = transactions.filter(t => t.type === type);
    }

    const startIndex = (page - 1) * limit;
    const paginatedTransactions = transactions.slice(startIndex, startIndex + parseInt(limit));

    res.json({
      success: true,
      transactions: paginatedTransactions,
      total: transactions.length,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: transactions.length
      }
    });
  } catch (error) {
    logger.error('Error getting transactions:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/wallet/deposit
 * Add funds to wallet (simulated)
 */
router.post('/deposit', authenticate, [
  body('amount').isFloat({ min: 100 }),
  body('paymentMethod').optional().isIn(['bank_transfer', 'card', 'mobile_money']),
  body('description').optional().isLength({ max: 200 })
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { amount, paymentMethod, description } = req.body;

    let wallet = await Wallet.findOne({ userId });

    if (!wallet) {
      wallet = new Wallet({ userId });
    }

    const transactionId = `TXN-${uuidv4().substring(0, 8).toUpperCase()}`;
    const transaction = {
      transactionId,
      type: 'deposit',
      amount: amount,
      currency: 'NGN',
      status: 'completed',
      description: description || 'Wallet deposit',
      reference: `REF-${Date.now()}`,
      metadata: { paymentMethod },
      createdAt: new Date()
    };

    wallet.balance += amount;
    wallet.transactions.push(transaction);
    await wallet.save();

    // Update user savings
    await User.findOneAndUpdate(
      { userId },
      {
        $inc: {
          'savings.totalSaved': amount,
          'savings.monthlySavings': amount
        },
        $set: { 'savings.lastSavingsDate': new Date() }
      }
    );

    // Log audit
    await AuditLog.log({
      action: 'WALLET_DEPOSIT',
      userId,
      details: `Deposited ₦${amount} to wallet`
    });

    res.json({
      success: true,
      transaction: {
        transactionId,
        amount,
        balance: wallet.balance,
        createdAt: transaction.createdAt
      },
      message: 'Deposit successful'
    });
  } catch (error) {
    logger.error('Deposit error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/wallet/withdraw
 * Withdraw funds from wallet
 */
router.post('/withdraw', authenticate, [
  body('amount').isFloat({ min: 100 }),
  body('bankAccount').notEmpty()
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { amount, bankAccount } = req.body;

    let wallet = await Wallet.findOne({ userId });

    if (!wallet) {
      return res.status(400).json({
        success: false,
        error: 'Wallet not found'
      });
    }

    if (wallet.balance < amount) {
      return res.status(400).json({
        success: false,
        error: 'Insufficient balance'
      });
    }

    const transactionId = `TXN-${uuidv4().substring(0, 8).toUpperCase()}`;
    const transaction = {
      transactionId,
      type: 'withdrawal',
      amount: amount,
      currency: 'NGN',
      status: 'pending',
      description: `Withdrawal to ${bankAccount}`,
      reference: `REF-${Date.now()}`,
      createdAt: new Date()
    };

    wallet.balance -= amount;
    wallet.transactions.push(transaction);
    await wallet.save();

    // Log audit
    await AuditLog.log({
      action: 'WALLET_WITHDRAWAL',
      userId,
      details: `Withdrew ₦${amount} from wallet`
    });

    res.json({
      success: true,
      transaction: {
        transactionId,
        amount,
        status: 'pending',
        estimatedProcessingTime: '24-48 hours'
      },
      message: 'Withdrawal request submitted'
    });
  } catch (error) {
    logger.error('Withdrawal error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/wallet/transfer
 * Transfer funds to another user
 */
router.post('/transfer', authenticate, [
  body('recipientId').notEmpty(),
  body('amount').isFloat({ min: 100 }),
  body('description').optional().isLength({ max: 200 })
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { recipientId, amount, description } = req.body;

    if (userId === recipientId) {
      return res.status(400).json({
        success: false,
        error: 'Cannot transfer to yourself'
      });
    }

    // Check recipient exists
    const recipient = await User.findOne({ userId: recipientId });
    if (!recipient) {
      return res.status(404).json({
        success: false,
        error: 'Recipient not found'
      });
    }

    let senderWallet = await Wallet.findOne({ userId });
    if (!senderWallet || senderWallet.balance < amount) {
      return res.status(400).json({
        success: false,
        error: 'Insufficient balance'
      });
    }

    let recipientWallet = await Wallet.findOne({ userId: recipientId });
    if (!recipientWallet) {
      recipientWallet = new Wallet({ userId: recipientId });
    }

    const transactionId = `TXN-${uuidv4().substring(0, 8).toUpperCase()}`;

    // Deduct from sender
    senderWallet.balance -= amount;
    senderWallet.transactions.push({
      transactionId,
      type: 'transfer',
      amount: -amount,
      currency: 'NGN',
      status: 'completed',
      description: description || `Transfer to ${recipient.name}`,
      reference: `REF-${Date.now()}`,
      metadata: { recipientId },
      createdAt: new Date()
    });
    await senderWallet.save();

    // Add to recipient
    recipientWallet.balance += amount;
    recipientWallet.transactions.push({
      transactionId: `TXN-${uuidv4().substring(0, 8).toUpperCase()}`,
      type: 'transfer',
      amount: amount,
      currency: 'NGN',
      status: 'completed',
      description: `Transfer from ${senderWallet.userId}`,
      reference: `REF-${Date.now()}`,
      metadata: { senderId: userId },
      createdAt: new Date()
    });
    await recipientWallet.save();

    // Log audit
    await AuditLog.log({
      action: 'WALLET_TRANSFER',
      userId,
      details: `Transferred ₦${amount} to ${recipientId}`
    });

    res.json({
      success: true,
      transaction: {
        transactionId,
        amount,
        recipient: recipient.name,
        status: 'completed'
      },
      message: 'Transfer successful'
    });
  } catch (error) {
    logger.error('Transfer error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/wallet/statement
 * Get wallet statement
 */
router.get('/statement', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { startDate, endDate, format } = req.query;

    const wallet = await Wallet.findOne({ userId });

    if (!wallet) {
      return res.json({
        success: true,
        statement: {
          openingBalance: 0,
          closingBalance: 0,
          transactions: []
        }
      });
    }

    let transactions = wallet.transactions;

    if (startDate) {
      const start = new Date(startDate);
      transactions = transactions.filter(t => new Date(t.createdAt) >= start);
    }

    if (endDate) {
      const end = new Date(endDate);
      transactions = transactions.filter(t => new Date(t.createdAt) <= end);
    }

    const openingBalance = wallet.balance - transactions.reduce((sum, t) => sum + (t.type === 'deposit' ? t.amount : -t.amount), 0);

    res.json({
      success: true,
      statement: {
        openingBalance,
        closingBalance: wallet.balance,
        transactions: transactions.reverse(),
        generatedAt: new Date()
      }
    });
  } catch (error) {
    logger.error('Get statement error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
