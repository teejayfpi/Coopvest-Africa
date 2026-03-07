/**
 * Audit Log Model
 * 
 * Tracks all referral-related actions for compliance and auditing
 */

const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const auditLogSchema = new mongoose.Schema({
  // Unique audit ID
  auditId: {
    type: String,
    default: () => `AUDIT-${uuidv4().substring(0, 8).toUpperCase()}`,
    unique: true,
    index: true
  },

  // Action type
  action: {
    type: String,
    required: true,
    enum: [
      'REFERRAL_REGISTERED',
      'REFERRAL_CONFIRMED',
      'REFERRAL_FLAGGED',
      'REFERRAL_UNFLAGGED',
      'REFERRAL_REVOKED',
      'BONUS_APPLIED',
      'BONUS_CONSUMED',
      'TIER_UPDATED',
      'SETTINGS_CHANGED',
      'FRAUD_DETECTED',
      'SELF_REFERRAL_DETECTED',
      'DUPLICATE_DETECTED',
      'LOAN_APPLIED_WITH_BONUS',
      'LOAN_APPLICATION_SUBMITTED',
      'LOAN_QR_GENERATED',
      'UNAUTHORIZED_ACCESS_ATTEMPT',
      'SYSTEM_ERROR_CRITICAL'
    ],
    index: true
  },

  // Related entities
  referralId: {
    type: String,
    default: null,
    index: true
  },
  userId: {
    type: String,
    default: null,
    index: true
  },
  adminId: {
    type: String,
    default: null
  },
  loanId: {
    type: String,
    default: null
  },

  // Action details
  details: {
    type: String,
    required: true
  },
  previousValue: {
    type: mongoose.Schema.Types.Mixed,
    default: null
  },
  newValue: {
    type: mongoose.Schema.Types.Mixed,
    default: null
  },

  // Metadata
  metadata: {
    ipAddress: String,
    userAgent: String,
    deviceFingerprint: String,
    location: String,
    referrerUrl: String
  },

  // Risk assessment
  riskLevel: {
    type: String,
    enum: ['low', 'medium', 'high', 'critical'],
    default: 'low'
  },

  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
}, {
  timestamps: false
});

// Compound indexes
auditLogSchema.index({ action: 1, createdAt: -1 });
auditLogSchema.index({ userId: 1, createdAt: -1 });
auditLogSchema.index({ referralId: 1, createdAt: -1 });
auditLogSchema.index({ adminId: 1, createdAt: -1 });

// Static method to log an action
auditLogSchema.statics.log = async function(params) {
  const {
    action,
    referralId = null,
    userId = null,
    adminId = null,
    loanId = null,
    details,
    previousValue = null,
    newValue = null,
    metadata = {},
    riskLevel = 'low'
  } = params;

  try {
    const log = new this({
      action,
      referralId,
      userId,
      adminId,
      loanId,
      details,
      previousValue,
      newValue,
      metadata,
      riskLevel
    });

    await log.save();

    // Trigger alert for high/critical risks
    if (riskLevel === 'critical' || riskLevel === 'high') {
      try {
        // Lazy load alert service to avoid circular dependencies
        const alertService = require('../services/alertService');
        alertService.sendCriticalAlert(log).catch(err => {
          console.error('Background alert sending failed:', err);
        });
      } catch (alertError) {
        console.error('Failed to trigger alert service:', alertError);
      }
    }

    return log;
  } catch (error) {
    console.error('Failed to create audit log:', error);
    // Don't throw - audit logging should not break main flow
    return null;
  }
};

// Static method to get user activity
auditLogSchema.statics.getUserActivity = async function(userId, limit = 50) {
  return this.find({ userId })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();
};

// Static method to get referral history
auditLogSchema.statics.getReferralHistory = async function(referralId, limit = 50) {
  return this.find({ referralId })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();
};

// Static method to get admin actions
auditLogSchema.statics.getAdminActions = async function(adminId, limit = 50) {
  return this.find({ adminId })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();
};

// Static method to get flagged activity
auditLogSchema.statics.getFlaggedActivity = async function(limit = 100) {
  return this.find({ 
    riskLevel: { $in: ['high', 'critical'] }
  })
  .sort({ createdAt: -1 })
  .limit(limit)
  .lean();
};

// Static method to get audit statistics
auditLogSchema.statics.getAuditStats = async function(startDate, endDate) {
  const pipeline = [
    {
      $match: {
        createdAt: { $gte: startDate, $lte: endDate }
      }
    },
    {
      $group: {
        _id: '$action',
        count: { $sum: 1 }
      }
    },
    {
      $sort: { count: -1 }
    }
  ];

  return this.aggregate(pipeline);
};

const AuditLog = mongoose.model('AuditLog', auditLogSchema);

module.exports = AuditLog;
