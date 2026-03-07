/**
 * Ticket Attachment Model
 * 
 * File attachments for tickets and messages
 */

const mongoose = require('mongoose');

const ticketAttachmentSchema = new mongoose.Schema({
  attachmentId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  
  // Reference to ticket
  ticketId: {
    type: String,
    required: true,
    index: true
  },
  
  // Reference to message (optional)
  messageId: {
    type: String,
    default: null
  },
  
  // Uploader info
  uploadedBy: {
    type: String,
    required: true
  },
  
  // File info
  fileName: {
    type: String,
    required: true
  },
  
  originalName: {
    type: String,
    required: true
  },
  
  mimeType: {
    type: String,
    required: true
  },
  
  size: {
    type: Number,
    required: true
  },
  
  // Storage info
  storageProvider: {
    type: String,
    default: 'local'
  },
  
  storagePath: {
    type: String,
    required: true
  },
  
  // Validation
  isValidated: {
    type: Boolean,
    default: false
  },
  
  validationError: {
    type: String,
    default: null
  },
  
  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Allowed MIME types for security
const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain'
];

// Maximum file sizes (in bytes)
const MAX_FILE_SIZES = {
  image: 5 * 1024 * 1024,      // 5 MB
  document: 10 * 1024 * 1024,  // 10 MB
};

// Validate file type
ticketAttachmentSchema.statics.validateFile = function(mimeType, size) {
  const errors = [];
  
  if (!ALLOWED_MIME_TYPES.includes(mimeType)) {
    errors.push('File type not allowed');
    return { valid: false, errors };
  }
  
  const fileType = mimeType.startsWith('image/') ? 'image' : 'document';
  const maxSize = MAX_FILE_SIZES[fileType];
  
  if (size > maxSize) {
    errors.push(`File size exceeds maximum allowed (${maxSize / 1024 / 1024}MB)`);
  }
  
  return { valid: errors.length === 0, errors };
};

// Generate storage path
ticketAttachmentSchema.statics.generateStoragePath = function(ticketId, fileName) {
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  
  return `tickets/${year}/${month}/${ticketId}/${fileName}`;
};

// Mark as validated
ticketAttachmentSchema.methods.markValidated = function() {
  this.isValidated = true;
  this.validationError = null;
  return this.save();
};

// Mark as invalid
ticketAttachmentSchema.methods.markInvalid = function(error) {
  this.isValidated = false;
  this.validationError = error;
  return this.save();
};

const TicketAttachment = mongoose.model('TicketAttachment', ticketAttachmentSchema);

module.exports = {
  TicketAttachment,
  ALLOWED_MIME_TYPES,
  MAX_FILE_SIZES
};
