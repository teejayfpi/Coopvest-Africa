/**
 * Transaction Model
 * Tracks all financial transactions in the system
 */

const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  transactionId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  type: {
    type: String,
    enum: [
      'deposit',
      'withdrawal',
      'transfer_in',
      'transfer_out',
      'investment',
      'investment_return',
      'savings_deposit',
      'savings_withdrawal',
      'loan_disbursement',
      'loan_repayment',
      'referral_bonus',
      'interest',
      'fee',
      'refund',
      'adjustment',
      'rollover'
    ],
    required: true,
    index: true
  },
  category: {
    type: String,
    enum: ['credit', 'debit'],
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  currency: {
    type: String,
    default: 'NGN',
    uppercase: true,
    minlength: 3,
    maxlength: 3
  },
  status: {
    type: String,
    enum: ['pending', 'processing', 'completed', 'failed', 'cancelled', 'reversed'],
    default: 'pending',
    index: true
  },
  paymentMethod: {
    type: String,
    enum: ['bank_transfer', 'card', 'ussd', 'qr_code', 'wallet', 'internal', 'other'],
    default: 'wallet'
  },
  description: {
    type: String,
    required: true,
    maxlength: 500
  },
  reference: {
    type: String,
    trim: true,
    index: true
  },
  // Related entities
  wallet: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Wallet'
  },
  savingsGoal: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'SavingsGoal'
  },
  investmentPool: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'InvestmentPool'
  },
  loan: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Loan'
  },
  bankAccount: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BankAccount'
  },
  // Payment gateway details
  gateway: {
    name: {
      type: String,
      enum: ['flutterwave', 'paystack', 'stripe', 'moniepoint', 'internal']
    },
    transactionId: String,
    responseCode: String,
    responseMessage: String,
    rawResponse: mongoose.Schema.Types.Mixed
  },
  // Fee breakdown
  fees: {
    platform: { type: Number, default: 0 },
    processing: { type: Number, default: 0 },
    other: { type: Number, default: 0 },
    total: { type: Number, default: 0 }
  },
  // Net amount after fees
  netAmount: {
    type: Number
  },
  // Balance after transaction
  balanceBefore: {
    type: Number,
    required: true
  },
  balanceAfter: {
    type: Number,
    required: true
  },
  // Metadata
  metadata: {
    type: Map,
    of: mongoose.Schema.Types.Mixed,
    default: {}
  },
  // Failure details
  failureReason: {
    type: String,
    maxlength: 500
  },
  failureCode: {
    type: String
  },
  // Reversal tracking
  reversed: {
    type: Boolean,
    default: false
  },
  reversedAt: {
    type: Date
  },
  reversedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  reversalReason: {
    type: String,
    maxlength: 500
  },
  // Timestamps
  initiatedAt: {
    type: Date,
    default: Date.now
  },
  processingAt: {
    type: Date
  },
  completedAt: {
    type: Date
  },
  failedAt: {
    type: Date
  }
}, {
  timestamps: true
});

// Indexes for efficient queries
transactionSchema.index({ user: 1, createdAt: -1 });
transactionSchema.index({ user: 1, status: 1, createdAt: -1 });
transactionSchema.index({ user: 1, type: 1, createdAt: -1 });
transactionSchema.index({ transactionId: 1 });
transactionSchema.index({ reference: 1 });
transactionSchema.index({ createdAt: -1 });

// Generate unique transaction ID
transactionSchema.statics.generateTransactionId = function() {
  const prefix = 'TXN';
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `${prefix}${timestamp}${random}`;
};

// Pre-save middleware to set net amount and transaction ID
transactionSchema.pre('save', function(next) {
  if (!this.transactionId) {
    this.transactionId = Transaction.generateTransactionId();
  }
  if (!this.netAmount && this.fees) {
    this.netAmount = this.amount - (this.fees.total || 0);
  }
  if (this.status === 'completed' && !this.completedAt) {
    this.completedAt = new Date();
  }
  if (this.status === 'processing' && !this.processingAt) {
    this.processingAt = new Date();
  }
  next();
});

// Static method to get transaction history
transactionSchema.statics.getHistory = async function(userId, options = {}) {
  const { page = 1, limit = 20, type, status, startDate, endDate } = options;
  const query = { user: userId };

  if (type) query.type = type;
  if (status) query.status = status;
  if (startDate || endDate) {
    query.createdAt = {};
    if (startDate) query.createdAt.$gte = new Date(startDate);
    if (endDate) query.createdAt.$lte = new Date(endDate);
  }

  const skip = (page - 1) * limit;

  const [transactions, total] = await Promise.all([
    this.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('wallet', 'balance')
      .populate('savingsGoal', 'name')
      .populate('investmentPool', 'name'),
    this.countDocuments(query)
  ]);

  return {
    transactions,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit)
    }
  };
};

// Static method to get summary
transactionSchema.statics.getSummary = async function(userId, startDate, endDate) {
  const query = {
    user: userId,
    status: 'completed',
    createdAt: {}
  };

  if (startDate) query.createdAt.$gte = new Date(startDate);
  if (endDate) query.createdAt.$lte = new Date(endDate);

  const result = await this.aggregate([
    { $match: query },
    {
      $group: {
        _id: null,
        totalCredits: {
          $sum: {
            $cond: [{ $eq: ['$category', 'credit'] }, '$amount', 0]
          }
        },
        totalDebits: {
          $sum: {
            $cond: [{ $eq: ['$category', 'debit'] }, '$amount', 0]
          }
        },
        transactionCount: { $sum: 1 }
      }
    }
  ]);

  return result[0] || { totalCredits: 0, totalDebits: 0, transactionCount: 0 };
};

const Transaction = mongoose.model('Transaction', transactionSchema);

module.exports = Transaction;
