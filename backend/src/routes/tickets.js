/**
 * Ticket Routes (Member)
 * 
 * Routes for ticket creation and management by members
 */

const express = require('express');
const router = express.Router();
const { query, body, validationResult } = require('express-validator');
const ticketService = require('../services/ticketService');
const { TICKET_CATEGORY, TICKET_PRIORITY, TICKET_STATUS } = require('../models/Ticket');
const { requireEmailVerification } = require('../middleware/emailVerification');
const logger = require('../utils/logger');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

/**
 * POST /api/v1/tickets
 * Create a new support ticket
 */
router.post('/', [
  requireEmailVerification,
  body('title').notEmpty().withMessage('Title is required').isLength({ max: 200 }),
  body('description').notEmpty().withMessage('Description is required').isLength({ max: 5000 }),
  body('category').isIn(Object.values(TICKET_CATEGORY)).withMessage('Invalid category'),
  body('priority').optional().isIn(Object.values(TICKET_PRIORITY)),
  body('loanId').optional().isString(),
  body('referralId').optional().isString(),
  body('transactionId').optional().isString(),
  body('sourceScreen').optional().isString()
], validate, async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader.split(' ')[1];
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    const ticketData = {
      title: req.body.title,
      description: req.body.description,
      category: req.body.category,
      priority: req.body.priority,
      relatedReference: {
        loanId: req.body.loanId || null,
        referralId: req.body.referralId || null,
        transactionId: req.body.transactionId || null
      }
    };

    const context = {
      appVersion: req.headers['x-app-version'] || null,
      devicePlatform: req.headers['x-device-platform'] || null,
      sourceScreen: req.body.sourceScreen || null
    };

    const result = await ticketService.createTicket(userId, ticketData, context);

    if (!result.success) {
      return res.status(429).json(result);
    }

    res.status(201).json(result);
  } catch (error) {
    logger.error('Create ticket error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/tickets
 * Get user's tickets with filtering
 */
router.get('/', [
  requireEmailVerification,
  query('status').optional().isIn(Object.values(TICKET_STATUS)),
  query('category').optional().isIn(Object.values(TICKET_CATEGORY)),
  query('priority').optional().isIn(Object.values(TICKET_PRIORITY)),
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 })
], validate, async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader.split(' ')[1];
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    const options = {
      status: req.query.status,
      category: req.query.category,
      priority: req.query.priority,
      page: parseInt(req.query.page) || 1,
      limit: parseInt(req.query.limit) || 20,
      sortBy: 'createdAt',
      sortOrder: 'desc'
    };

    const result = await ticketService.getUserTickets(userId, options);

    res.json(result);
  } catch (error) {
    logger.error('Get tickets error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/tickets/:ticketId
 * Get ticket details with messages
 */
router.get('/:ticketId', [
  requireEmailVerification
], async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader.split(' ')[1];
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    const result = await ticketService.getTicketById(req.params.ticketId, userId, false);

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
 * POST /api/v1/tickets/:ticketId/messages
 * Add message to ticket
 */
router.post('/:ticketId/messages', [
  requireEmailVerification,
  body('content').notEmpty().withMessage('Message content is required').isLength({ max: 10000 })
], validate, async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader.split(' ')[1];
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    const result = await ticketService.addMessage(
      req.params.ticketId,
      userId,
      'user',
      req.body.content,
      req.body.attachments
    );

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.status(201).json(result);
  } catch (error) {
    logger.error('Add message error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/tickets/rate-limit/status
 * Check rate limit status
 */
router.get('/rate-limit/status', [
  requireEmailVerification
], async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader.split(' ')[1];
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    const [rateLimit, restriction] = await Promise.all([
      ticketService.checkRateLimit(userId),
      ticketService.checkUserRestriction(userId)
    ]);

    res.json({
      success: true,
      canCreate: rateLimit.allowed && restriction.allowed,
      rateLimit,
      restriction
    });
  } catch (error) {
    logger.error('Get rate limit status error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
