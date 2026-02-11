/**
 * Notification Model
 * Manages user notifications for transactions, alerts, and updates
 */

const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  type: {
    type: String,
    enum: [
      'transaction',
      'savings',
      'investment',
      'loan',
      'referral',
      'kyc',
      'system',
      'promotion',
      'security',
      'reminder'
    ],
    required: true,
    index: true
  },
  category: {
    type: String,
    enum: [
      'credit',
      'debit',
      'milestone',
      'expiry',
      'status_change',
      'info',
      'warning',
      'success',
      'action_required'
    ],
    default: 'info'
  },
  title: {
    type: String,
    required: true,
    maxlength: 200
  },
  message: {
    type: String,
    required: true,
    maxlength: 1000
  },
  data: {
    type: Map,
    of: mongoose.Schema.Types.Mixed,
    default: {}
  },
  reference: {
    model: {
      type: String,
      enum: ['User', 'Wallet', 'SavingsGoal', 'InvestmentPool', 'Loan', 'Referral', 'KYC', 'Ticket']
    },
    id: {
      type: mongoose.Schema.Types.ObjectId
    }
  },
  isRead: {
    type: Boolean,
    default: false,
    index: true
  },
  readAt: {
    type: Date
  },
  isArchived: {
    type: Boolean,
    default: false,
    index: true
  },
  archivedAt: {
    type: Date
  },
  isPushed: {
    type: Boolean,
    default: false
  },
  pushedAt: {
    type: Date
  },
  priority: {
    type: String,
    enum: ['low', 'normal', 'high', 'urgent'],
    default: 'normal',
    index: true
  },
  expiresAt: {
    type: Date
  },
  actionUrl: {
    type: String,
    maxlength: 500
  },
  actionLabel: {
    type: String,
    maxlength: 50
  }
}, {
  timestamps: true
});

// Compound indexes for efficient queries
notificationSchema.index({ user: 1, createdAt: -1 });
notificationSchema.index({ user: 1, isRead: 1, createdAt: -1 });
notificationSchema.index({ user: 1, type: 1, createdAt: -1 });
notificationSchema.index({ user: 1, priority: -1, createdAt: -1 });

// Virtual for checking if notification is expired
notificationSchema.virtual('isExpired').get(function() {
  if (!this.expiresAt) return false;
  return new Date() > this.expiresAt;
});

// Instance method to mark as read
notificationSchema.methods.markAsRead = async function() {
  if (!this.isRead) {
    this.isRead = true;
    this.readAt = new Date();
    await this.save();
  }
  return this;
};

// Instance method to archive
notificationSchema.methods.archive = async function() {
  if (!this.isArchived) {
    this.isArchived = true;
    this.archivedAt = new Date();
    await this.save();
  }
  return this;
};

// Static method to get unread count
notificationSchema.statics.getUnreadCount = async function(userId) {
  return this.countDocuments({
    user: userId,
    isRead: false,
    isArchived: false,
    $or: [
      { expiresAt: { $exists: false } },
      { expiresAt: { $gt: new Date() } }
    ]
  });
};

// Static method to get unread notifications
notificationSchema.statics.getUnread = async function(userId, limit = 20) {
  return this.find({
    user: userId,
    isRead: false,
    isArchived: false,
    $or: [
      { expiresAt: { $exists: false } },
      { expiresAt: { $gt: new Date() } }
    ]
  })
    .sort({ priority: -1, createdAt: -1 })
    .limit(limit)
    .populate('reference.model', 'name title');
};

// Static method to create and send notification
notificationSchema.statics.send = async function(userId, type, title, message, options = {}) {
  const notification = new this({
    user: userId,
    type,
    title,
    message,
    ...options
  });
  return notification.save();
};

const Notification = mongoose.model('Notification', notificationSchema);

module.exports = Notification;
