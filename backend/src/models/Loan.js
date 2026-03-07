/**
 * Loan Model
 * 
 * Tracking loan applications and status
 */

const mongoose = require('mongoose');

const loanSchema = new mongoose.Schema({
  loanId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  userId: {
    type: String,
    required: true,
    index: true
  },
  loanType: {
    type: String,
    required: true,
    enum: ['Quick Loan', 'Micro Loan', 'Business Loan', 'Emergency Loan']
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  tenureMonths: {
    type: Number,
    required: true,
    min: 1
  },
  purpose: {
    type: String,
    required: true
  },
  baseInterestRate: {
    type: Number,
    required: true
  },
  referralBonusPercent: {
    type: Number,
    default: 0
  },
  effectiveInterestRate: {
    type: Number,
    required: true
  },
  monthlyRepayment: {
    type: Number,
    required: true
  },
  totalRepayment: {
    type: Number,
    required: true
  },
  savingsFromBonus: {
    type: Number,
    default: 0
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'active', 'rejected', 'completed'],
    default: 'pending'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

const Loan = mongoose.model('Loan', loanSchema);

module.exports = Loan;
