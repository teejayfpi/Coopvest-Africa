/**
 * Referral Model
 * 
 * Represents a referral relationship between members
 * Includes all qualification fields and bonus tracking
 */

const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const referralSchema = new mongoose.Schema({
  // Unique identifier
  referralId: {
    type: String,
    default: () => `REF-${uuidv4().substring(0, 8).toUpperCase()}`,
    unique: true,
    index: true
  },

  // Referral code used
  referralCode: {
    type: String,
    required: [true, 'Referral code is required'],
    uppercase: true,
    trim: true,
    index: true
  },

  // Referrer (person who invited)
  referrerId: {
    type: String,
    required: [true, 'Referrer ID is required'],
    index: true
  },
  referrerName: {
    type: String,
    required: [true, 'Referrer name is required']
  },

  // Referred person
  referredId: {
    type: String,
    required: [true, 'Referred user ID is required'],
    index: true
  },
  referredName: {
    type: String,
    required: [true, 'Referred user name is required']
  },

  // Confirmation status
  confirmed: {
    type: Boolean,
    default: false,
    index: true
  },
  confirmationDate: {
    type: Date,
    default: null
  },

  // Lock-in period tracking
  lockInEndDate: {
    type: Date,
    default: null,
    index: true
  },

  // Bonus tracking
  tierBonusPercent: {
    type: Number,
    default: 0,
    min: 0,
    max: 4
  },
  bonusConsumed: {
    type: Boolean,
    default: false
  },
  bonusUsedLoanId: {
    type: String,
    default: null
  },
  bonusUsedDate: {
    type: Date,
    default: null
  },

  // Qualification criteria
  kycVerified: {
    type: Boolean,
    default: false,
    index: true
  },
  kycVerifiedDate: {
    type: Date,
    default: null
  },
  savingsCriteriaMet: {
    type: Boolean,
    default: false,
    index: true
  },
  consecutiveSavingsMonths: {
    type: Number,
    default: 0,
    min: 0
  },
  totalSavingsAmount: {
    type: Number,
    default: 0,
    min: 0
  },
  minimumSavingsDate: {
    type: Date, // 3 months from first savings
    default: null
  },

  // Anti-abuse fields
  isFlagged: {
    type: Boolean,
    default: false,
    index: true
  },
  flaggedReason: {
    type: String,
    default: null
  },
  flaggedDate: {
    type: Date,
    default: null
  },
  flaggedBy: {
    type: String,
    default: null
  },

  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Compound indexes for efficient queries
referralSchema.index({ referrerId: 1, confirmed: 1 });
referralSchema.index({ referredId: 1, referralCode: 1 });
referralSchema.index({ confirmed: 1, kycVerified: 1, savingsCriteriaMet: 1 });

// Virtual for lock-in status
referralSchema.virtual('isLockInComplete').get(function() {
  if (!this.lockInEndDate) return false;
  return new Date() > this.lockInEndDate;
});

// Virtual for bonus availability
referralSchema.virtual('isBonusAvailable').get(function() {
  return this.confirmed && 
         !this.bonusConsumed && 
         !this.isFlagged && 
         this.isLockInComplete;
});

// Virtual for qualification status
referralSchema.virtual('isQualified').get(function() {
  return this.confirmed && 
         this.kycVerified && 
         this.savingsCriteriaMet && 
         !this.isFlagged;
});

// Virtual for tier description
referralSchema.virtual('tierDescription').get(function() {
  if (this.tierBonusPercent >= 4) return 'Gold Tier (4% OFF)';
  if (this.tierBonusPercent >= 3) return 'Silver Tier (3% OFF)';
  if (this.tierBonusPercent >= 2) return 'Bronze Tier (2% OFF)';
  return 'No Bonus Yet';
});

// Static method to calculate tier bonus
referralSchema.statics.calculateTierBonus = function(confirmedReferralCount) {
  if (confirmedReferralCount >= 6) return 4.0;
  if (confirmedReferralCount >= 4) return 3.0;
  if (confirmedReferralCount >= 2) return 2.0;
  return 0;
};

// Static method to get tier name
referralSchema.statics.getTierName = function(bonusPercent) {
  if (bonusPercent >= 4) return 'Gold';
  if (bonusPercent >= 3) return 'Silver';
  if (bonusPercent >= 2) return 'Bronze';
  return 'None';
};

// Pre-save middleware to update timestamps
referralSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// Instance method to confirm referral
referralSchema.methods.confirmReferral = function(lockInDays = 30) {
  if (this.confirmed) {
    throw new Error('Referral is already confirmed');
  }
  
  this.confirmed = true;
  this.confirmationDate = new Date();
  this.lockInEndDate = new Date(Date.now() + lockInDays * 24 * 60 * 60 * 1000);
  
  return this.save();
};

// Instance method to apply bonus to loan
referralSchema.methods.applyBonusToLoan = function(loanId) {
  if (this.bonusConsumed) {
    throw new Error('Bonus has already been consumed');
  }
  if (!this.isBonusAvailable) {
    throw new Error('Bonus is not available');
  }
  
  this.bonusConsumed = true;
  this.bonusUsedLoanId = loanId;
  this.bonusUsedDate = new Date();
  
  return this.save();
};

// Instance method to flag referral
referralSchema.methods.flagReferral = function(reason, adminId) {
  this.isFlagged = true;
  this.flaggedReason = reason;
  this.flaggedDate = new Date();
  this.flaggedBy = adminId;
  
  return this.save();
};

// Instance method to unflag referral
referralSchema.methods.unflagReferral = function() {
  this.isFlagged = false;
  this.flaggedReason = null;
  this.flaggedDate = null;
  this.flaggedBy = null;
  
  return this.save();
};

// Static method to get user's referral summary
referralSchema.statics.getUserReferralSummary = async function(userId, referralCode) {
  const pipeline = [
    { $match: { referrerId: userId } },
    {
      $group: {
        _id: null,
        totalReferrals: { $sum: 1 },
        pendingReferrals: {
          $sum: { $cond: [{ $eq: ['$confirmed', false] }, 1, 0] }
        },
        confirmedReferrals: {
          $sum: { $cond: [{ $eq: ['$confirmed', true] }, 1, 0] }
        },
        flaggedReferrals: {
          $sum: { $cond: [{ $eq: ['$isFlagged', true] }, 1, 0] }
        }
      }
    }
  ];

  const result = await this.aggregate(pipeline);
  
  const stats = result[0] || {
    totalReferrals: 0,
    pendingReferrals: 0,
    confirmedReferrals: 0,
    flaggedReferrals: 0
  };

  // Get recent referrals
  const recentReferrals = await this.find({ referrerId: userId })
    .sort({ createdAt: -1 })
    .limit(5)
    .lean();

  // Calculate current tier bonus
  const confirmedCount = stats.confirmedReferrals;
  const currentBonus = this.calculateTierBonus(confirmedCount);
  
  // Check if any bonus is available
  const hasAvailableBonus = await this.exists({
    referrerId: userId,
    confirmed: true,
    isFlagged: false,
    bonusConsumed: false,
    lockInEndDate: { $lte: new Date() }
  });

  // Get next bonus unlock date
  const nextUnlock = await this.findOne({
    referrerId: userId,
    confirmed: true,
    isFlagged: false,
    bonusConsumed: false,
    lockInEndDate: { $gt: new Date() }
  }).sort({ lockInEndDate: 1 });

  return {
    userId,
    referralCode,
    ...stats,
    currentTierBonus: currentBonus,
    currentTierDescription: currentBonus >= 4 ? 'Gold Tier (4% OFF)' : 
                           currentBonus >= 3 ? 'Silver Tier (3% OFF)' :
                           currentBonus >= 2 ? 'Bronze Tier (2% OFF)' : 'No Bonus Yet',
    isBonusAvailable: !!hasAvailableBonus,
    nextBonusUnlockDate: nextUnlock?.lockInEndDate || null,
    recentReferrals
  };
};

// Static method to update user's tier bonuses
referralSchema.statics.updateUserTierBonuses = async function(userId) {
  const confirmedCount = await this.countDocuments({
    referrerId: userId,
    confirmed: true,
    isFlagged: false
  });

  const tierBonus = this.calculateTierBonus(confirmedCount);

  // Update all unconsumed confirmed referrals with new tier
  await this.updateMany(
    {
      referrerId: userId,
      confirmed: true,
      isFlagged: false,
      bonusConsumed: false
    },
    {
      $set: { tierBonusPercent: tierBonus }
    }
  );

  return tierBonus;
};

const Referral = mongoose.model('Referral', referralSchema);

module.exports = Referral;
