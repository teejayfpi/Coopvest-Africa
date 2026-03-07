/**
 * Ticket Message Model
 * 
 * Threaded messages for ticket conversations
 */

const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const ticketMessageSchema = new mongoose.Schema({
  messageId: {
    type: String,
    required: true,
    unique: true,
    index: true,
    default: () => `MSG-${Date.now().toString(36).toUpperCase()}-${uuidv4().substring(0, 8).toUpperCase()}`
  },
  
  // Reference to ticket
  ticketId: {
    type: String,
    required: true,
    index: true
  },
  
  // User who sent the message
  senderId: {
    type: String,
    required: true,
    index: true
  },
  
  // Sender type
  senderType: {
    type: String,
    enum: ['user', 'staff', 'system'],
    required: true
  },
  
  // Message content
  content: {
    type: String,
    required: [true, 'Message content is required'],
    maxlength: 10000
  },
  
  // Internal note flag (only visible to staff)
  isInternalNote: {
    type: Boolean,
    default: false
  },
  
  // Read tracking
  readBy: [{
    userId: String,
    readAt: {
      type: Date,
      default: Date.now
    }
  }],
  
  // Attachment references
  attachments: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'TicketAttachment'
  }],
  
  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
}, {
  timestamps: true
});

// Index for efficient message retrieval
ticketMessageSchema.index({ ticketId: 1, createdAt: 1 });

// Virtual for checking if message is unread by a user
ticketMessageSchema.methods.isUnreadBy = function(userId) {
  return !this.readBy.some(r => r.userId === userId);
};

// Mark message as read
ticketMessageSchema.methods.markAsRead = async function(userId) {
  const existingRead = this.readBy.find(r => r.userId === userId);
  if (!existingRead) {
    this.readBy.push({ userId, readAt: new Date() });
    await this.save();
  }
  return this;
};

// Get unread message count for a user
ticketMessageSchema.statics.getUnreadCount = async function(ticketId, userId) {
  const count = await this.countDocuments({
    ticketId,
    createdAt: { $gt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }, // Last 30 days
    $expr: {
      $not: {
        $in: [userId, '$readBy.userId']
      }
    },
    senderId: { $ne: userId }
  });
  
  return count;
};

// Get conversation for a ticket
ticketMessageSchema.statics.getConversation = async function(ticketId, options = {}) {
  const { limit = 50, skip = 0, sortOrder = 'asc' } = options;
  
  const messages = await this.find({ ticketId })
    .sort({ createdAt: sortOrder === 'asc' ? 1 : -1 })
    .skip(skip)
    .limit(limit)
    .populate('attachments');
  
  return sortOrder === 'asc' ? messages : messages.reverse();
};

const TicketMessage = mongoose.model('TicketMessage', ticketMessageSchema);

module.exports = TicketMessage;
