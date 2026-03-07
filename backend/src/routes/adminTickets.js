/**
 * Admin Ticket Routes
 * 
 * Routes for admin/support staff to manage tickets
 */

const express = require('express');
const router = express.Router();
const { query, body, validationResult } = require('express-validator');
const ticketService = require('../services/ticketService');
const { TICKET_CATEGORY, TICKET_PRIORITY, TICKET_STATUS } = require('../models/Ticket');
const logger = require('../utils/logger');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

// Middleware to check admin role
const requireAdmin = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, error: 'Authentication required' });
    }

    const token = authHeader.split(' ')[1];
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if user is admin
    const { User } = require('../models');
    const user = await User.findOne({ userId: decoded.userId });
    
    if (!user || !['admin', 'superadmin', 'support'].includes(user.role)) {
      return res.status(403).json({ success: false, error: 'Admin access required' });
    }

    req.userId = decoded.userId;
    req.userRole = user.role;
    next();
  } catch (error) {
    logger.error('Admin auth error:', error);
    res.status(401).json({ success: false, error: 'Invalid token' });
  }
};

/**
 * GET /api/v1/admin/tickets
 * Get all tickets with filtering (admin)
 */
router.get('/tickets', [
  requireAdmin,
  query('status').optional().isIn(Object.values(TICKET_STATUS)),
  query('category').optional().isIn(Object.values(TICKET_CATEGORY)),
  query('priority').optional().isIn(Object.values(TICKET_PRIORITY)),
  query('assignedStaffId').optional().isString(),
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 })
], validate, async (req, res) => {
  try {
    const options = {
      status: req.query.status,
      category: req.query.category,
      priority: req.query.priority,
      assignedStaffId: req.query.assignedStaffId,
      page: parseInt(req.query.page) || 1,
      limit: parseInt(req.query.limit) || 20,
      sortBy: req.query.sortBy || 'createdAt',
      sortOrder: req.query.sortOrder || 'desc'
    };

    // For admins, get all tickets
    const { Ticket } = require('../models');
    const query = {};
    
    if (options.status) query.status = options.status;
    if (options.category) query.category = options.category;
    if (options.priority) query.priority = options.priority;
    if (options.assignedStaffId) query.assignedStaffId = options.assignedStaffId;

    const skip = (options.page - 1) * options.limit;
    const sort = { [options.sortBy]: options.sortOrder === 'desc' ? -1 : 1 };

    const [tickets, total] = await Promise.all([
      Ticket.find(query)
        .sort(sort)
        .skip(skip)
        .limit(options.limit)
        .select('-statusHistory'),
      Ticket.countDocuments(query)
    ]);

    res.json({
      success: true,
      tickets,
      pagination: {
        page: options.page,
        limit: options.limit,
        total,
        pages: Math.ceil(total / options.limit)
      }
    });
  } catch (error) {
    logger.error('Get all tickets error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/admin/tickets/stats
 * Get ticket statistics (admin)
 */
router.get('/tickets/stats', [
  requireAdmin
], async (req, res) => {
  try {
    const result = await ticketService.getStats(req.query);
    res.json(result);
  } catch (error) {
    logger.error('Get ticket stats error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/admin/tickets/:ticketId
 * Get ticket details (admin)
 */
router.get('/tickets/:ticketId', [
  requireAdmin
], async (req, res) => {
  try {
    const result = await ticketService.getTicketById(req.params.ticketId, req.userId, true);

    if (!result.success) {
      return res.status(404).json(result);
    }

    res.json(result);
  } catch (error) {
    logger.error('Get ticket error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * PATCH /api/v1/admin/tickets/:ticketId/status
 * Update ticket status (admin)
 */
router.patch('/tickets/:ticketId/status', [
  requireAdmin,
  body('status').isIn(Object.values(TICKET_STATUS)).withMessage('Invalid status'),
  body('note').optional().isString().isLength({ max: 500 })
], validate, async (req, res) => {
  try {
    const result = await ticketService.updateStatus(
      req.params.ticketId,
      req.body.status,
      req.userId,
      req.body.note
    );

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    logger.error('Update status error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/v1/admin/tickets/:ticketId/assign
 * Assign ticket to staff (admin)
 */
router.post('/tickets/:ticketId/assign', [
  requireAdmin,
  body('staffId').notEmpty().withMessage('Staff ID is required')
], validate, async (req, res) => {
  try {
    const result = await ticketService.assignTicket(
      req.params.ticketId,
      req.body.staffId,
      req.userId
    );

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    logger.error('Assign ticket error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/v1/admin/tickets/:ticketId/messages
 * Add admin message to ticket
 */
router.post('/tickets/:ticketId/messages', [
  requireAdmin,
  body('content').notEmpty().withMessage('Message content is required').isLength({ max: 10000 }),
  body('isInternalNote').optional().isBoolean()
], validate, async (req, res) => {
  try {
    const senderType = req.body.isInternalNote ? 'staff' : 'staff';
    
    const result = await ticketService.addMessage(
      req.params.ticketId,
      req.userId,
      senderType,
      req.body.content,
      req.body.attachments
    );

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.status(201).json(result);
  } catch (error) {
    logger.error('Add admin message error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/v1/admin/tickets/:ticketId/restrict-user
 * Restrict user from creating tickets
 */
router.post('/tickets/:ticketId/restrict-user', [
  requireAdmin,
  body('durationDays').optional().isInt({ min: 1, max: 30 })
], validate, async (req, res) => {
  try {
    const ticket = await ticketService.getTicketById(req.params.ticketId, req.userId, true);
    
    if (!ticket.success) {
      return res.status(404).json(ticket);
    }

    const result = await ticketService.restrictUser(
      ticket.ticket.userId,
      req.userId,
      req.body.durationDays || 7
    );

    res.json(result);
  } catch (error) {
    logger.error('Restrict user error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/admin/tickets/search
 * Search tickets
 */
router.get('/tickets/search', [
  requireAdmin,
  query('q').notEmpty().withMessage('Search query is required'),
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 })
], validate, async (req, res) => {
  try {
    const { Ticket } = require('../models');
    const searchQuery = req.query.q;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const tickets = await Ticket.find({
      $or: [
        { ticketId: { $regex: searchQuery, $options: 'i' } },
        { title: { $regex: searchQuery, $options: 'i' } },
        { description: { $regex: searchQuery, $options: 'i' } }
      ]
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .select('-statusHistory');

    const total = await Ticket.countDocuments({
      $or: [
        { ticketId: { $regex: searchQuery, $options: 'i' } },
        { title: { $regex: searchQuery, $options: 'i' } },
        { description: { $regex: searchQuery, $options: 'i' } }
      ]
    });

    res.json({
      success: true,
      tickets,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    logger.error('Search tickets error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
