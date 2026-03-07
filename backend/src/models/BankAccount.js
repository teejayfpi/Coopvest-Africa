/**
 * BankAccount Model
 * Manages user linked bank accounts for withdrawals and transfers
 */

const mongoose = require('mongoose');

const bankAccountSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  bankName: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100
  },
  bankCode: {
    type: String,
    required: true,
    trim: true,
    uppercase: true,
    minlength: 3,
    maxlength: 10
  },
  accountNumber: {
    type: String,
    required: true,
    trim: true,
    minlength: 10,
    maxlength: 20
  },
  accountName: {
    type: String,
    required: true,
    trim: true,
    maxlength: 150
  },
  accountType: {
    type: String,
    enum: ['savings', 'current', 'business'],
    default: 'savings'
  },
  isPrimary: {
    type: Boolean,
    default: false
  },
  isVerified: {
    type: Boolean,
    default: false
  },
  verifiedAt: {
    type: Date
  },
  verificationMethod: {
    type: String,
    enum: ['micro-deposit', 'manual', 'api', 'none'],
    default: 'none'
  },
  lastUsedAt: {
    type: Date
  },
  nickname: {
    type: String,
    trim: true,
    maxlength: 50
  },
  branchCode: {
    type: String,
    trim: true,
    maxlength: 20
  },
  bvn: {
    type: String,
    trim: true,
    minlength: 11,
    maxlength: 11
  },
  bvnVerified: {
    type: Boolean,
    default: false
  },
  bvnVerifiedAt: {
    type: Date
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true
  },
  isBlocked: {
    type: Boolean,
    default: false
  },
  blockedAt: {
    type: Date
  },
  blockReason: {
    type: String,
    maxlength: 500
  },
  metadata: {
    type: Map,
    of: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: true
});

// Compound unique index for user + account number
bankAccountSchema.index({ user: 1, accountNumber: 1 }, { unique: true });

// Index for bank lookups
bankAccountSchema.index({ bankCode: 1, accountNumber: 1 });

// Virtual for masked account number
bankAccountSchema.virtual('maskedAccountNumber').get(function() {
  if (!this.accountNumber) return '';
  const len = this.accountNumber.length;
  if (len <= 4) return this.accountNumber;
  return '*'.repeat(len - 4) + this.accountNumber.slice(-4);
});

// Pre-save middleware to set primary
bankAccountSchema.pre('save', async function(next) {
  if (this.isPrimary && this.isModified('isPrimary')) {
    // Unset other primary accounts for this user
    await this.constructor.updateMany(
      { user: this.user, _id: { $ne: this._id }, isPrimary: true },
      { isPrimary: false }
    );
  }
  next();
});

// Instance method to verify account
bankAccountSchema.methods.verify = async function(method = 'manual') {
  this.isVerified = true;
  this.verifiedAt = new Date();
  this.verificationMethod = method;
  return this.save();
};

// Instance method to block account
bankAccountSchema.methods.block = async function(reason) {
  this.isBlocked = true;
  this.blockedAt = new Date();
  this.blockReason = reason;
  return this.save();
};

// Instance method to unblock account
bankAccountSchema.methods.unblock = async function() {
  this.isBlocked = false;
  this.blockedAt = null;
  this.blockReason = null;
  return this.save();
};

// Instance method to mark as last used
bankAccountSchema.methods.markAsUsed = async function() {
  this.lastUsedAt = new Date();
  return this.save();
};

// Static method to get user's primary account
bankAccountSchema.statics.getPrimary = async function(userId) {
  return this.findOne({ user: userId, isPrimary: true, isActive: true, isBlocked: false });
};

// Static method to get user's verified accounts
bankAccountSchema.statics.getVerified = async function(userId) {
  return this.find({ user: userId, isVerified: true, isActive: true, isBlocked: false })
    .sort({ isPrimary: -1, createdAt: -1 });
};

// Static method to resolve account using NIP service
bankAccountSchema.statics.resolveAccount = async function(bankCode, accountNumber) {
  // This would integrate with NIP (NIBSS Instant Payment) or similar service
  // Placeholder for actual API integration
  return {
    bankCode,
    accountNumber,
    accountName: null, // Would be resolved from API
    resolved: false
  };
};

const BankAccount = mongoose.model('BankAccount', bankAccountSchema);

module.exports = BankAccount;
