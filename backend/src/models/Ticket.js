/**
 * Ticket Model
 * 
 * Support ticket model for tracking user issues and requests
 */

const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

// Ticket status enum
const TICKET_STATUS = {
  OPEN: 'open',
  IN_PROGRESS: 'in_progress',
  AWAITING_USER: 'awaiting_user',
  RESOLVED: 'resolved',
  CLOSED: 'closed'
};

// Ticket priority enum
const TICKET_PRIORITY = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  URGENT: 'urgent'
};

// Ticket category enum
const TICKET_CATEGORY = {
  LOAN_ISSUE: 'loan_issue',
  GUARANTOR_CONSENT: 'guarantor_consent',
  REFERRAL_BONUS: 'referral_bonus',
  REPAYMENT_ISSUE: 'repayment_issue',
  ACCOUNT_KYC: 'account_kyc',
  TECHNICAL_BUG: 'technical_bug',
  OTHER: 'other'
};

// Status transition rules
const STATUS_TRANSITIONS = {
  [TICKET_STATUS.OPEN]: [TICKET_STATUS.IN_PROGRESS, TICKET_STATUS.CLOSED],
  [TICKET_STATUS.IN_PROGRESS]: [TICKET_STATUS.AWAITING_USER, TICKET_STATUS.RESOLVED, TICKET_STATUS.CLOSED],
  [TICKET_STATUS.AWAITING_USER]: [TICKET_STATUS.IN_PROGRESS, TICKET_STATUS.RESOLVED, TICKET_STATUS.CLOSED],
  [TICKET_STATUS.RESOLVED]: [TICKET_STATUS.OPEN, TICKET_STATUS.CLOSED],
  [TICKET_STATUS.CLOSED]: [TICKET_STATUS.OPEN]
};

const ticketSchema = new mongoose.Schema({
  ticketId: {
    type: String,
    required: true,
    unique: true,
    index: true,
    default: () => `TKT-${Date.now().toString(36).toUpperCase()}-${uuidv4().substring(0, 8).toUpperCase()}`
  },
  
  // User who created the ticket
  userId: {
    type: String,
    required: true,
    index: true
  },
  
  // Ticket content
  category: {
    type: String,
    enum: Object.values(TICKET_CATEGORY),
    required: [true, 'Ticket category is required']
  },
  
  priority: {
    type: String,
    enum: Object.values(TICKET_PRIORITY),
    default: TICKET_PRIORITY.MEDIUM
  },
  
  status: {
    type: String,
    enum: Object.values(TICKET_STATUS),
    default: TICKET_STATUS.OPEN,
    index: true
  },
  
  title: {
    type: String,
    required: [true, 'Ticket title is required'],
    trim: true,
    maxlength: 200
  },
  
  description: {
    type: String,
    required: [true, 'Ticket description is required'],
    maxlength: 5000
  },
  
  // Related references
  relatedReference: {
    loanId: {
      type: String,
      default: null
    },
    referralId: {
      type: String,
      default: null
    },
    transactionId: {
      type: String,
      default: null
    },
    guarantorRequestId: {
      type: String,
      default: null
    }
  },
  
  // Assignment
  assignedStaffId: {
    type: String,
    default: null,
    index: true
  },
  
  // Resolution
  resolution: {
    type: String,
    default: null
  },
  resolvedAt: {
    type: Date,
    default: null
  },
  resolvedBy: {
    type: String,
    default: null
  },
  
  // User interaction tracking
  lastUserResponseAt: {
    type: Date,
    default: null
  },
  
  // Auto-tagging
  metadata: {
    appVersion: {
      type: String,
      default: null
    },
    devicePlatform: {
      type: String,
      default: null
    },
    sourceScreen: {
      type: String,
      default: null
    }
  },
  
  // Audit trail
  statusHistory: [{
    status: String,
    changedBy: String,
    changedAt: {
      type: Date,
      default: Date.now
    },
    note: String
  }],
  
  // Abuse prevention
  abuseFlags: {
    isDuplicated: {
      type: Boolean,
      default: false
    },
    mergedInto: {
      type: String,
      default: null
    },
    userWarned: {
      type: Boolean,
      default: false
    },
    restrictionEndsAt: {
      type: Date,
      default: null
    }
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

// Indexes for efficient queries
ticketSchema.index({ userId: 1, status: 1 });
ticketSchema.index({ assignedStaffId: 1, status: 1 });
ticketSchema.index({ category: 1, priority: 1 });
ticketSchema.index({ createdAt: -1 });

// Pre-save middleware
ticketSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // Track status changes
  if (this.isModified('status')) {
    this.statusHistory.push({
      status: this.status,
      changedBy: this.lastModifiedBy || 'system',
      changedAt: new Date()
    });
  }
  
  next();
});

// Check if status transition is valid
ticketSchema.methods.canTransitionTo = function(newStatus) {
  const allowedTransitions = STATUS_TRANSITIONS[this.status] || [];
  return allowedTransitions.includes(newStatus);
};

// Transition status with validation
ticketSchema.methods.transitionTo = async function(newStatus, changedBy, note = null) {
  if (!this.canTransitionTo(newStatus)) {
    throw new Error(`Cannot transition from ${this.status} to ${newStatus}`);
  }
  
  const previousStatus = this.status;
  this.status = newStatus;
  this.lastModifiedBy = changedBy;
  
  // Handle resolution
  if (newStatus === TICKET_STATUS.RESOLVED) {
    this.resolvedAt = new Date();
    this.resolvedBy = changedBy;
  }
  
  await this.save();
  
  return { previousStatus, newStatus };
};

// Check if user can create ticket
ticketSchema.methods.canCreateTicket = function() {
  if (this.abuseFlags.restrictionEndsAt) {
    const now = new Date();
    if (this.abuseFlags.restrictionEndsAt > now) {
      return { allowed: false, reason: 'Ticket creation restricted' };
    }
  }
  return { allowed: true };
};

// Check for duplicate tickets
ticketSchema.statics.findDuplicates = async function(userId, title, description) {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
  
  const duplicates = await this.find({
    userId,
    title: { $regex: new RegExp(title.substring(0, 20), 'i') },
    createdAt: { $gte: oneDayAgo },
    status: { $nin: [TICKET_STATUS.CLOSED, TICKET_STATUS.RESOLVED] }
  });
  
  return duplicates;
};

// Get ticket statistics
ticketSchema.statics.getStats = async function(filters = {}) {
  const match = {};
  
  if (filters.category) match.category = filters.category;
  if (filters.priority) match.priority = filters.priority;
  if (filters.status) match.status = filters.status;
  if (filters.assignedStaffId) match.assignedStaffId = filters.assignedStaffId;
  
  const stats = await this.aggregate([
    { $match: match },
    {
      $group: {
        _id: '$status',
        count: { $sum: 1 }
      }
    }
  ]);
  
  const result = {
    total: 0,
    open: 0,
    inProgress: 0,
    awaitingUser: 0,
    resolved: 0,
    closed: 0
  };
  
  stats.forEach(s => {
    result[s._id] = s.count;
    result.total += s.count;
  });
  
  return result;
};

const Ticket = mongoose.model('Ticket', ticketSchema);

module.exports = {
  Ticket,
  TICKET_STATUS,
  TICKET_PRIORITY,
  TICKET_CATEGORY,
  STATUS_TRANSITIONS
};
