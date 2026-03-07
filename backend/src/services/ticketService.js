/**
 * Ticket Service
 * 
 * Business logic for ticket operations
 */

const { Ticket, TicketMessage, TicketAttachment, User, AuditLog } = require('../models');
const { TICKET_STATUS, TICKET_PRIORITY, TICKET_CATEGORY } = require('../models/Ticket');
const logger = require('../utils/logger');

// Configuration
const TICKET_RATE_LIMIT = parseInt(process.env.TICKET_RATE_LIMIT) || 5; // Max tickets per day
const DUPLICATE_THRESHOLD_DAYS = parseInt(process.env.DUPLICATE_THRESHOLD_DAYS) || 7;

class TicketService {
  /**
   * Create a new ticket
   */
  async createTicket(userId, ticketData, context = {}) {
    try {
      // Check if user is restricted
      const restrictionCheck = await this.checkUserRestriction(userId);
      if (!restrictionCheck.allowed) {
        return {
          success: false,
          error: restrictionCheck.reason,
          restrictionEndsAt: restrictionCheck.endsAt
        };
      }

      // Check rate limit
      const rateLimitCheck = await this.checkRateLimit(userId);
      if (!rateLimitCheck.allowed) {
        return {
          success: false,
          error: rateLimitCheck.reason,
          remainingTickets: rateLimitCheck.remaining
        };
      }

      // Check for duplicates
      const duplicates = await this.findDuplicateTickets(
        userId,
        ticketData.title,
        ticketData.category
      );

      // Create ticket
      const ticket = new Ticket({
        userId,
        category: ticketData.category,
        priority: ticketData.priority || TICKET_PRIORITY.MEDIUM,
        title: ticketData.title,
        description: ticketData.description,
        relatedReference: ticketData.relatedReference || {},
        metadata: {
          appVersion: context.appVersion || null,
          devicePlatform: context.devicePlatform || null,
          sourceScreen: context.sourceScreen || null
        },
        statusHistory: [{
          status: TICKET_STATUS.OPEN,
          changedBy: userId,
          changedAt: new Date(),
          note: 'Ticket created'
        }]
      });

      // Handle duplicates
      if (duplicates.length > 0) {
        ticket.abuseFlags.isDuplicated = true;
        ticket.statusHistory.push({
          status: ticket.status,
          changedBy: 'system',
          changedAt: new Date(),
          note: `Marked as duplicate of ${duplicates.length} existing ticket(s)`
        });
      }

      await ticket.save();

      // Create initial message
      const initialMessage = new TicketMessage({
        ticketId: ticket.ticketId,
        senderId: userId,
        senderType: 'user',
        content: ticketData.description,
        isInternalNote: false
      });
      await initialMessage.save();

      // Log audit
      await this.logAudit(ticket.ticketId, userId, 'TICKET_CREATED', {
        category: ticket.category,
        priority: ticket.priority
      });

      logger.info(`Ticket created: ${ticket.ticketId} by user ${userId}`);

      return {
        success: true,
        ticket: {
          ticketId: ticket.ticketId,
          category: ticket.category,
          priority: ticket.priority,
          status: ticket.status,
          title: ticket.title,
          createdAt: ticket.createdAt,
          isDuplicated: ticket.abuseFlags.isDuplicated
        }
      };
    } catch (error) {
      logger.error('Create ticket error:', error);
      throw error;
    }
  }

  /**
   * Get user's tickets
   */
  async getUserTickets(userId, options = {}) {
    try {
      const {
        status,
        category,
        priority,
        page = 1,
        limit = 20,
        sortBy = 'createdAt',
        sortOrder = 'desc'
      } = options;

      const query = { userId };
      
      if (status) query.status = status;
      if (category) query.category = category;
      if (priority) query.priority = priority;

      const skip = (page - 1) * limit;
      const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

      const [tickets, total] = await Promise.all([
        Ticket.find(query)
          .sort(sort)
          .skip(skip)
          .limit(limit)
          .select('-statusHistory'),
        Ticket.countDocuments(query)
      ]);

      return {
        success: true,
        tickets,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      };
    } catch (error) {
      logger.error('Get user tickets error:', error);
      throw error;
    }
  }

  /**
   * Get ticket by ID
   */
  async getTicketById(ticketId, userId, isAdmin = false) {
    try {
      const query = isAdmin 
        ? { ticketId }
        : { ticketId, userId };

      const ticket = await Ticket.findOne(query);
      
      if (!ticket) {
        return { success: false, error: 'Ticket not found' };
      }

      // Get messages
      const messages = await TicketMessage.find({ ticketId })
        .sort({ createdAt: 1 })
        .populate('attachments');

      return {
        success: true,
        ticket,
        messages
      };
    } catch (error) {
      logger.error('Get ticket error:', error);
      throw error;
    }
  }

  /**
   * Add message to ticket
   */
  async addMessage(ticketId, senderId, senderType, content, attachments = []) {
    try {
      const ticket = await Ticket.findOne({ ticketId });
      
      if (!ticket) {
        return { success: false, error: 'Ticket not found' };
      }

      // Validate status
      if (ticket.status === TICKET_STATUS.CLOSED) {
        return { success: false, error: 'Cannot add message to closed ticket' };
      }

      // Create message
      const message = new TicketMessage({
        ticketId,
        senderId,
        senderType,
        content,
        attachments: attachments.filter(a => a)
      });

      await message.save();

      // Update ticket
      ticket.updatedAt = new Date();
      
      if (senderType === 'user') {
        ticket.lastUserResponseAt = new Date();
        
        // If waiting for user response, transition back to in_progress
        if (ticket.status === TICKET_STATUS.AWAITING_USER) {
          await ticket.transitionTo(TICKET_STATUS.IN_PROGRESS, senderId, 'User replied');
        }
      }
      
      await ticket.save();

      // Log audit
      await this.logAudit(ticketId, senderId, 'MESSAGE_ADDED', {
        messageId: message.messageId,
        senderType
      });

      return {
        success: true,
        message: {
          messageId: message.messageId,
          content: message.content,
          senderType: message.senderType,
          createdAt: message.createdAt
        }
      };
    } catch (error) {
      logger.error('Add message error:', error);
      throw error;
    }
  }

  /**
   * Update ticket status (admin only)
   */
  async updateStatus(ticketId, newStatus, staffId, note = null) {
    try {
      const ticket = await Ticket.findOne({ ticketId });
      
      if (!ticket) {
        return { success: false, error: 'Ticket not found' };
      }

      // Validate transition
      if (!ticket.canTransitionTo(newStatus)) {
        return {
          success: false,
          error: `Cannot transition from ${ticket.status} to ${newStatus}`,
          allowedTransitions: []
        };
      }

      const previousStatus = ticket.status;
      await ticket.transitionTo(newStatus, staffId, note);

      // Log audit
      await this.logAudit(ticketId, staffId, 'STATUS_CHANGED', {
        previousStatus,
        newStatus,
        note
      });

      // Trigger notification
      await this.sendStatusChangeNotification(ticket, previousStatus, newStatus);

      return {
        success: true,
        ticket: {
          ticketId: ticket.ticketId,
          previousStatus,
          newStatus: ticket.status,
          updatedAt: ticket.updatedAt
        }
      };
    } catch (error) {
      logger.error('Update status error:', error);
      throw error;
    }
  }

  /**
   * Assign ticket to staff
   */
  async assignTicket(ticketId, staffId, assignedBy) {
    try {
      const ticket = await Ticket.findOne({ ticketId });
      
      if (!ticket) {
        return { success: false, error: 'Ticket not found' };
      }

      const previousStaff = ticket.assignedStaffId;
      ticket.assignedStaffId = staffId;
      
      // If not in progress, transition
      if (ticket.status === TICKET_STATUS.OPEN) {
        await ticket.transitionTo(TICKET_STATUS.IN_PROGRESS, assignedBy, `Assigned to staff`);
      }
      
      await ticket.save();

      // Log audit
      await this.logAudit(ticketId, assignedBy, 'TICKET_ASSIGNED', {
        previousStaff,
        newStaff: staffId
      });

      return {
        success: true,
        ticket: {
          ticketId: ticket.ticketId,
          assignedStaffId: ticket.assignedStaffId
        }
      };
    } catch (error) {
      logger.error('Assign ticket error:', error);
      throw error;
    }
  }

  /**
   * Check rate limit for user
   */
  async checkRateLimit(userId) {
    try {
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      
      const count = await Ticket.countDocuments({
        userId,
        createdAt: { $gte: oneDayAgo }
      });

      const remaining = Math.max(0, TICKET_RATE_LIMIT - count);
      
      if (count >= TICKET_RATE_LIMIT) {
        return {
          allowed: false,
          reason: 'Daily ticket limit reached',
          remaining: 0
        };
      }

      return {
        allowed: true,
        remaining
      };
    } catch (error) {
      logger.error('Check rate limit error:', error);
      return { allowed: true, remaining: TICKET_RATE_LIMIT };
    }
  }

  /**
   * Find duplicate tickets
   */
  async findDuplicateTickets(userId, title, category) {
    try {
      const daysAgo = new Date(Date.now() - DUPLICATE_THRESHOLD_DAYS * 24 * 60 * 60 * 1000);
      
      // Check for similar titles
      const similarTitle = title.substring(0, 30);
      
      const duplicates = await Ticket.find({
        userId,
        category,
        createdAt: { $gte: daysAgo },
        status: { $nin: [TICKET_STATUS.CLOSED, TICKET_STATUS.RESOLVED] },
        title: { $regex: new RegExp(similarTitle, 'i') }
      });

      return duplicates;
    } catch (error) {
      logger.error('Find duplicates error:', error);
      return [];
    }
  }

  /**
   * Check if user is restricted
   */
  async checkUserRestriction(userId) {
    try {
      const user = await User.findOne({ userId });
      
      if (!user) {
        return { allowed: true };
      }

      // Check abuse flags from any recent ticket
      const recentTicket = await Ticket.findOne({
        userId,
        'abuseFlags.restrictionEndsAt': { $gt: new Date() }
      }).sort({ createdAt: -1 });

      if (recentTicket && recentTicket.abuseFlags.restrictionEndsAt > new Date()) {
        return {
          allowed: false,
          reason: 'Ticket creation temporarily restricted',
          endsAt: recentTicket.abuseFlags.restrictionEndsAt
        };
      }

      return { allowed: true };
    } catch (error) {
      logger.error('Check restriction error:', error);
      return { allowed: true };
    }
  }

  /**
   * Restrict user from creating tickets
   */
  async restrictUser(userId, staffId, durationDays = 7) {
    try {
      const restrictionEnd = new Date();
      restrictionEnd.setDate(restrictionEnd.getDate() + durationDays);

      // Update all open tickets for this user
      await Ticket.updateMany(
        { userId, status: { $nin: [TICKET_STATUS.CLOSED, TICKET_STATUS.RESOLVED] } },
        {
          'abuseFlags.userWarned': true,
          'abuseFlags.restrictionEndsAt': restrictionEnd
        }
      );

      // Log audit
      await this.logAudit('SYSTEM', staffId, 'USER_RESTRICTED', {
        userId,
        durationDays,
        endsAt: restrictionEnd
      });

      return {
        success: true,
        restrictionEndsAt: restrictionEnd
      };
    } catch (error) {
      logger.error('Restrict user error:', error);
      throw error;
    }
  }

  /**
   * Log audit entry
   */
  async logAudit(ticketId, userId, action, details = {}) {
    try {
      const auditLog = new AuditLog({
        action,
        entityType: 'ticket',
        entityId: ticketId,
        userId,
        details,
        timestamp: new Date()
      });
      await auditLog.save();
    } catch (error) {
      logger.error('Log audit error:', error);
    }
  }

  /**
   * Send status change notification
   */
  async sendStatusChangeNotification(ticket, previousStatus, newStatus) {
    try {
      // TODO: Integrate with notification service
      logger.info(`Notification: Ticket ${ticket.ticketId} status changed from ${previousStatus} to ${newStatus}`);
    } catch (error) {
      logger.error('Send notification error:', error);
    }
  }

  /**
   * Get ticket statistics (admin)
   */
  async getStats(filters = {}) {
    try {
      const stats = await Ticket.getStats(filters);
      return {
        success: true,
        stats
      };
    } catch (error) {
      logger.error('Get stats error:', error);
      throw error;
    }
  }
}

module.exports = new TicketService();
