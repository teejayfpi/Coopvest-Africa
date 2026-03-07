/**
 * User Model
 * 
 * Extended user model with referral-specific fields
 */

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  // Basic info
  userId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    trim: true
  },
  phone: {
    type: String,
    required: [true, 'Phone number is required']
  },
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: 8,
    select: false
  },

  // KYC verification
  kyc: {
    verified: {
      type: Boolean,
      default: false
    },
    verifiedAt: {
      type: Date,
      default: null
  },
  nationalId: {
    type: String,
    default: null
  },
  address: {
    type: String,
    default: null
  },
  dateOfBirth: {
    type: Date,
    default: null
  }
  },

  // Savings tracking
  savings: {
    totalSaved: {
      type: Number,
      default: 0,
      min: 0
    },
    monthlySavings: {
      type: Number,
      default: 0,
      min: 0
    },
    firstSavingsDate: {
      type: Date,
      default: null
    },
    consecutiveMonths: {
      type: Number,
      default: 0,
      min: 0
    },
    lastSavingsDate: {
      type: Date,
      default: null
    }
  },

  // Referral info
  referral: {
    myReferralCode: {
      type: String,
      unique: true,
      uppercase: true,
      index: true
    },
    referredBy: {
      type: String,
      default: null,
      index: true
    },
    referredByCode: {
      type: String,
      default: null
    },
    referralCount: {
      type: Number,
      default: 0
    },
    confirmedReferralCount: {
      type: Number,
      default: 0
    },
    currentTierBonus: {
      type: Number,
      default: 0,
      min: 0,
      max: 4
    }
  },

  // Device fingerprinting for fraud detection
  deviceFingerprints: [{
    fingerprint: String,
    firstSeen: Date,
    lastSeen: Date
  }],

  // Account status
  isActive: {
    type: Boolean,
    default: true
  },
  isFlagged: {
    type: Boolean,
    default: false
  },
  flaggedReason: {
    type: String,
    default: null
  },
  role: {
    type: String,
    enum: ['member', 'admin', 'superadmin'],
    default: 'member'
  },

  // Email verification
  emailVerification: {
    isVerified: {
      type: Boolean,
      default: false
    },
    verificationToken: {
      type: String,
      default: null
    },
    otp: {
      type: String,
      default: null
    },
    verificationExpires: {
      type: Date,
      default: null
    },
    verifiedAt: {
      type: Date,
      default: null
    },
    lastResendAt: {
      type: Date,
      default: null
    }
  },

  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now
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

// Generate unique referral code
userSchema.statics.generateReferralCode = function(userId) {
  const prefix = 'COOP';
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  const userPart = userId.substring(0, 4).toUpperCase();
  return `${prefix}${userPart}${random}`;
};

// Generate email verification token and OTP
userSchema.methods.generateEmailVerificationToken = function() {
  const crypto = require('crypto');
  const token = crypto.randomBytes(32).toString('hex');
  
  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  
  this.emailVerification.verificationToken = token;
  this.emailVerification.otp = otp;
  this.emailVerification.verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
  return { token, otp };
};

// Check if email verification token is valid
userSchema.methods.isEmailVerificationTokenValid = function(token) {
  return (
    this.emailVerification.verificationToken === token &&
    this.emailVerification.verificationExpires > new Date()
  );
};

// Check if OTP is valid
userSchema.methods.isOTPValid = function(otp) {
  return (
    this.emailVerification.otp === otp &&
    this.emailVerification.verificationExpires > new Date()
  );
};

// Verify email
userSchema.methods.verifyEmail = function() {
  this.emailVerification.isVerified = true;
  this.emailVerification.verifiedAt = new Date();
  this.emailVerification.verificationToken = null;
  this.emailVerification.otp = null;
  this.emailVerification.verificationExpires = null;
  return this.save();
};

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Generate referral code on creation
userSchema.pre('save', function(next) {
  if (!this.referral.myReferralCode) {
    this.referral.myReferralCode = User.generateReferralCode(this.userId);
  }
  this.updatedAt = new Date();
  next();
});

// Compare password method
userSchema.methods.comparePassword = async function(candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

// Add device fingerprint
userSchema.methods.addDeviceFingerprint = function(fingerprint) {
  const existing = this.deviceFingerprints.find(
    df => df.fingerprint === fingerprint
  );
  
  if (existing) {
    existing.lastSeen = new Date();
  } else {
    this.deviceFingerprints.push({
      fingerprint,
      firstSeen: new Date(),
      lastSeen: new Date()
    });
  }
  
  return this.save();
};

// Check for duplicate device
userSchema.methods.hasDeviceFingerprint = function(fingerprint) {
  return this.deviceFingerprints.some(
    df => df.fingerprint === fingerprint
  );
};

// Virtual for savings duration in months
userSchema.virtual('savingsDurationMonths').get(function() {
  if (!this.savings.firstSavingsDate) return 0;
  
  const now = new Date();
  const first = new Date(this.savings.firstSavingsDate);
  const months = (now.getFullYear() - first.getFullYear()) * 12 + 
                 (now.getMonth() - first.getMonth());
  
  return Math.max(0, months);
});

// Check if user meets savings criteria
userSchema.methods.meetsSavingsCriteria = function(minMonths = 3, minAmount = 5000) {
  return this.savings.consecutiveMonths >= minMonths && 
         this.savings.totalSaved >= minAmount &&
         this.kyc.verified;
};

const User = mongoose.model('User', userSchema);

module.exports = User;
