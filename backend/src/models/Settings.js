/**
 * Settings Model
 * Manages user preferences and app configuration
 */

const mongoose = require('mongoose');

const settingsSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true
  },
  // Notification preferences
  notifications: {
    email: {
      transactions: { type: Boolean, default: true },
      savings: { type: Boolean, default: true },
      investments: { type: Boolean, default: true },
      loans: { type: Boolean, default: true },
      referrals: { type: Boolean, default: true },
      marketing: { type: Boolean, default: false },
      security: { type: Boolean, default: true }
    },
    push: {
      transactions: { type: Boolean, default: true },
      savings: { type: Boolean, default: true },
      investments: { type: Boolean, default: true },
      loans: { type: Boolean, default: true },
      referrals: { type: Boolean, default: true },
      marketing: { type: Boolean, default: false },
      security: { type: Boolean, default: true }
    },
    sms: {
      transactions: { type: Boolean, default: true },
      security: { type: Boolean, default: true },
      marketing: { type: Boolean, default: false }
    }
  },
  // Security settings
  security: {
    twoFactorEnabled: { type: Boolean, default: false },
    twoFactorMethod: {
      type: String,
      enum: ['totp', 'sms', 'email', 'none'],
      default: 'none'
    },
    loginAlerts: { type: Boolean, default: true },
    transactionPIN: { type: Boolean, default: false },
    biometricEnabled: { type: Boolean, default: true },
    trustedDevices: [{
      deviceId: String,
      deviceName: String,
      deviceToken: String,
      addedAt: { type: Date, default: Date.now },
      lastUsedAt: Date,
      isActive: { type: Boolean, default: true }
    }],
    sessionTimeout: { type: Number, default: 30 }, // minutes
    maxSessions: { type: Number, default: 3 }
  },
  // Privacy settings
  privacy: {
    showOnLeaderboard: { type: Boolean, default: true },
    showInvestmentPortfolio: { type: Boolean, default: false },
    allowReferralTracking: { type: Boolean, default: true },
    dataSharing: { type: Boolean, default: false }
  },
  // Display preferences
  display: {
    currency: { type: String, default: 'NGN' },
    language: { type: String, default: 'en' },
    timezone: { type: String, default: 'Africa/Lagos' },
    dateFormat: { type: String, default: 'DD/MM/YYYY' },
    theme: {
      type: String,
      enum: ['light', 'dark', 'system'],
      default: 'system'
    },
    compactMode: { type: Boolean, default: false }
  },
  // Transaction limits
  limits: {
    dailyWithdrawal: { type: Number, default: 500000 }, // NGN
    singleWithdrawal: { type: Number, default: 200000 }, // NGN
    dailyTransfer: { type: Number, default: 1000000 }, // NGN
    requirePIN: { type: Boolean, default: true }
  },
  // Saved preferences
  saved: {
    defaultPaymentMethod: {
      type: String,
      enum: ['bank_transfer', 'card', 'wallet'],
      default: 'wallet'
    },
    defaultSavingsFrequency: {
      type: String,
      enum: ['daily', 'weekly', 'biweekly', 'monthly'],
      default: 'monthly'
    },
    autoInvestPercentage: { type: Number, default: 0 },
    preferredInvestmentDuration: { type: Number, default: 30 } // days
  },
  // App state
  onboardingCompleted: { type: Boolean, default: false },
  lastActiveAt: { type: Date },
  appVersion: { type: String }
}, {
  timestamps: true
});

// Index
settingsSchema.index({ user: 1 });

// Instance method to update notification settings
settingsSchema.methods.updateNotificationSettings = async function(type, channel, key, value) {
  if (this.notifications[type] && this.notifications[type][channel]) {
    this.notifications[type][channel][key] = value;
    return this.save();
  }
  throw new Error('Invalid notification setting');
};

// Instance method to add trusted device
settingsSchema.methods.addTrustedDevice = async function(device) {
  if (this.security.trustedDevices.length >= this.security.maxSessions) {
    // Remove oldest inactive session
    this.security.trustedDevices = this.security.trustedDevices
      .filter(d => d.isActive)
      .sort((a, b) => a.lastUsedAt - b.lastUsedAt)
      .slice(0, this.security.maxSessions - 1);
  }
  this.security.trustedDevices.push({
    ...device,
    addedAt: new Date(),
    isActive: true
  });
  return this.save();
};

// Instance method to update last active
settingsSchema.methods.updateLastActive = async function() {
  this.lastActiveAt = new Date();
  return this.save();
};

// Static method to get or create settings
settingsSchema.statics.getOrCreate = async function(userId) {
  let settings = await this.findOne({ user: userId });
  if (!settings) {
    settings = await this.create({ user: userId });
  }
  return settings;
};

const Settings = mongoose.model('Settings', settingsSchema);

module.exports = Settings;
