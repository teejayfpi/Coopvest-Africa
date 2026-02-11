/**
 * Rollover/Loan Extension Model
 * 
 * Tracking loan rollover/extension requests and history
 */

const mongoose = require('mongoose');

const rolloverSchema = new mongoose.Schema({
  rolloverId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  loanId: {
    type: String,
    required: true,
    index: true
  },
  userId: {
    type: String,
    required: true,
    index: true
  },
  
  // Original Loan Details
  originalLoan: {
    amount: Number,
    tenureMonths: Number,
    interestRate: Number,
    monthlyRepayment: Number,
    remainingBalance: Number,
    remainingMonths: Number,
    nextDueDate: Date
  },
  
  // Rollover Request Details
  requestedTenure: {
    type: Number,
    required: true,
    min: 1,
    max: 24
  },
  requestedReason: {
    type: String,
    default: ''
  },
  
  // New Terms (after approval)
  newTerms: {
    tenureMonths: Number,
    interestRate: Number,
    monthlyRepayment: Number,
    extensionFee: Number,
    newDueDate: Date
  },
  
  // Status
  status: {
    type: String,
    enum: ['pending', 'under_review', 'approved', 'rejected', 'cancelled', 'completed'],
    default: 'pending'
  },
  
  // Guarantor Requirements for Rollover
  requiresNewGuarantors: {
    type: Boolean,
    default: false
  },
  guarantorsRequired: {
    type: Number,
    default: 0
  },
  guarantorsConfirmed: {
    type: Number,
    default: 0
  },
  
  // Admin Review
  reviewedBy: {
    type: String,
    default: null
  },
  reviewedAt: {
    type: Date,
    default: null
  },
  reviewNotes: {
    type: String,
    default: null
  },
  
  // Rejection Details
  rejectionReason: {
    type: String,
    default: null
  },
  
  // Timeline
  submittedAt: {
    type: Date,
    default: Date.now
  },
  approvedAt: {
    type: Date,
    default: null
  },
  completedAt: {
    type: Date,
    default: null
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

// Check if eligible for rollover
rolloverSchema.methods.isEligible = function() {
  const maxExtensions = 3;
  const maxTenure = 36;
  return (
    this.originalLoan.remainingMonths > 0 &&
    this.originalLoan.remainingMonths < this.requestedTenure &&
    this.requestedTenure <= maxTenure
  );
};

const Rollover = mongoose.model('Rollover', rolloverSchema);

module.exports = Rollover;
