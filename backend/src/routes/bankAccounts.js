/**
 * Bank Accounts Routes
 * API endpoints for managing user linked bank accounts
 */

const express = require('express');
const router = express.Router();
const { BankAccount } = require('../models');
const { auth: authMiddleware } = require('../middleware/auth');

// All routes require authentication
router.use(authMiddleware);

/**
 * GET /api/v1/bank-accounts
 * Get all bank accounts for current user
 */
router.get('/', async (req, res) => {
  try {
    const { active = 'true' } = req.query;
    
    const query = { user: req.user.id };
    if (active === 'true') {
      query.isActive = true;
      query.isBlocked = false;
    }

    const accounts = await BankAccount.find(query).sort({ isPrimary: -1, createdAt: -1 });

    // Add masked account numbers
    const accountsWithMasking = accounts.map(acc => ({
      ...acc.toObject(),
      accountNumber: acc.maskedAccountNumber
    }));

    res.json({
      success: true,
      data: accountsWithMasking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/bank-accounts/primary
 * Get primary bank account
 */
router.get('/primary', async (req, res) => {
  try {
    const account = await BankAccount.getPrimary(req.user.id);

    if (!account) {
      return res.status(404).json({
        success: false,
        error: 'No primary bank account found'
      });
    }

    res.json({
      success: true,
      data: {
        ...account.toObject(),
        accountNumber: account.maskedAccountNumber
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
 * POST /api/v1/bank-accounts/resolve
 * Resolve bank account details using account number
 */
router.post('/resolve', async (req, res) => {
  try {
    const { bankCode, accountNumber } = req.body;

    if (!bankCode || !accountNumber) {
      return res.status(400).json({
        success: false,
        error: 'Bank code and account number are required'
      });
    }

    // Use NIP service or similar to resolve account
    const result = await BankAccount.resolveAccount(bankCode, accountNumber);

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/bank-accounts
 * Link a new bank account
 */
router.post('/', async (req, res) => {
  try {
    const {
      bankName,
      bankCode,
      accountNumber,
      accountName,
      accountType = 'savings',
      nickname,
      branchCode
    } = req.body;

    if (!bankName || !bankCode || !accountNumber || !accountName) {
      return res.status(400).json({
        success: false,
        error: 'Bank name, bank code, account number, and account name are required'
      });
    }

    // Check if account already linked
    const existing = await BankAccount.findOne({
      user: req.user.id,
      accountNumber
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        error: 'This account is already linked to your profile'
      });
    }

    // Check if this is the first account - make it primary
    const accountCount = await BankAccount.countDocuments({ user: req.user.id });
    const isPrimary = accountCount === 0;

    const bankAccount = await BankAccount.create({
      user: req.user.id,
      bankName,
      bankCode,
      accountNumber,
      accountName,
      accountType,
      nickname,
      branchCode,
      isPrimary
    });

    res.status(201).json({
      success: true,
      message: 'Bank account linked successfully',
      data: {
        ...bankAccount.toObject(),
        accountNumber: bankAccount.maskedAccountNumber
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
 * PATCH /api/v1/bank-accounts/:id/primary
 * Set bank account as primary
 */
router.patch('/:id/primary', async (req, res) => {
  try {
    const bankAccount = await BankAccount.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true,
      isBlocked: false
    });

    if (!bankAccount) {
      return res.status(404).json({
        success: false,
        error: 'Bank account not found'
      });
    }

    bankAccount.isPrimary = true;
    await bankAccount.save();

    res.json({
      success: true,
      message: 'Bank account set as primary',
      data: bankAccount
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/bank-accounts/:id/nickname
 * Update account nickname
 */
router.patch('/:id/nickname', async (req, res) => {
  try {
    const { nickname } = req.body;

    const bankAccount = await BankAccount.findOneAndUpdate(
      { _id: req.params.id, user: req.user.id },
      { nickname },
      { new: true }
    );

    if (!bankAccount) {
      return res.status(404).json({
        success: false,
        error: 'Bank account not found'
      });
    }

    res.json({
      success: true,
      data: bankAccount
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/bank-accounts/:id/verify
 * Verify bank account (admin or manual process)
 */
router.post('/:id/verify', async (req, res) => {
  try {
    const { method = 'manual' } = req.body;

    const bankAccount = await BankAccount.findOne({
      _id: req.params.id,
      user: req.user.id
    });

    if (!bankAccount) {
      return res.status(404).json({
        success: false,
        error: 'Bank account not found'
      });
    }

    await bankAccount.verify(method);

    res.json({
      success: true,
      message: 'Bank account verified',
      data: bankAccount
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/bank-accounts/:id/use
 * Mark account as last used
 */
router.post('/:id/use', async (req, res) => {
  try {
    const bankAccount = await BankAccount.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true,
      isBlocked: false
    });

    if (!bankAccount) {
      return res.status(404).json({
        success: false,
        error: 'Bank account not found'
      });
    }

    await bankAccount.markAsUsed();

    res.json({
      success: true,
      message: 'Account marked as used'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * DELETE /api/v1/bank-accounts/:id
 * Unlink bank account
 */
router.delete('/:id', async (req, res) => {
  try {
    const bankAccount = await BankAccount.findOne({
      _id: req.params.id,
      user: req.user.id
    });

    if (!bankAccount) {
      return res.status(404).json({
        success: false,
        error: 'Bank account not found'
      });
    }

    // Soft delete - just mark as inactive
    bankAccount.isActive = false;
    await bankAccount.save();

    res.json({
      success: true,
      message: 'Bank account unlinked'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/bank-accounts/banks
 * Get list of supported banks
 */
router.get('/banks/list', async (req, res) => {
  try {
    // List of Nigerian banks (would typically come from database or API)
    const banks = [
      { code: '000001', name: 'First Bank of Nigeria' },
      { code: '000002', name: 'United Bank for Africa' },
      { code: '000003', name: 'Zenith Bank' },
      { code: '000004', name: 'Guaranty Trust Bank' },
      { code: '000005', name: 'Access Bank' },
      { code: '000006', name: 'Ecobank Nigeria' },
      { code: '000007', name: 'Sterling Bank' },
      { code: '000008', name: 'Fidelity Bank' },
      { code: '000009', name: 'Union Bank of Nigeria' },
      { code: '000010', name: 'Stanbic IBTC Bank' },
      { code: '000011', name: 'Citibank Nigeria' },
      { code: '000012', name: 'Unity Bank' },
      { code: '000013', name: 'Paradise Bank' },
      { code: '000014', name: 'Heritage Bank' },
      { code: '000015', name: 'Keystone Bank' },
      { code: '000016', name: 'Mainstreet Bank' },
      { code: '000017', name: 'First City Monument Bank' },
      { code: '000018', name: 'Bank of Industry' },
      { code: '000019', name: 'Nigerian Deposit Insurance Corporation' },
      { code: '000020', name: 'Nigeria Police Bank' }
    ];

    res.json({
      success: true,
      data: banks
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
