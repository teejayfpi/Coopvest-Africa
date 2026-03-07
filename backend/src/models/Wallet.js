/**
 * Wallet Model
 * 
 * Tracking user balances and transactions
 */

const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  transactionId: {
    type: String,
    required: true,
    unique: true
  },
  type: {
    type: String,
    enum: ['deposit', 'withdrawal', 'loan_disbursement', 'loan_repayment', 'referral_bonus', 'transfer'],
    required: true
  },
  amount: {
    type: Number,
    required: true
  },
  currency: {
    type: String,
    default: 'NGN'
  },
  status: {
    type: String,
    enum: ['pending', 'completed', 'failed', 'reversed'],
    default: 'completed'
  },
  description: String,
  reference: String,
  metadata: Object,
  createdAt: {
    type: Date,
    default: Date.now
  }
});

const walletSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  balance: {
    type: Number,
    default: 0,
    min: 0
  },
  currency: {
    type: String,
    default: 'NGN'
  },
  transactions: [transactionSchema],
  isActive: {
    type: Boolean,
    default: true
  },
  lastUpdated: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Update lastUpdated on save
walletSchema.pre('save', function(next) {
  this.lastUpdated = new Date();
  next();
});

const Wallet = mongoose.model('Wallet', walletSchema);

module.exports = Wallet;
