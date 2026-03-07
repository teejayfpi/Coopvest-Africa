/**
 * Error Handler Middleware
 * 
 * Centralized error handling with AuditLog integration for critical errors.
 */

const logger = require('../utils/logger');
const AuditLog = require('../models/AuditLog');

const errorHandler = async (err, req, res, next) => {
  // Log to winston logger
  logger.error(`${req.method} ${req.path} - Error:`, {
    message: err.message,
    stack: err.stack,
    userId: req.user?.userId || 'anonymous',
    ip: req.ip
  });

  // Handle specific error types
  
  // Mongoose validation error
  if (err.name === 'ValidationError') {
    const errors = Object.values(err.errors).map(e => e.message);
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors
    });
  }

  // Mongoose duplicate key error
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue)[0];
    return res.status(400).json({
      success: false,
      error: `${field} already exists`
    });
  }

  // Mongoose cast error (invalid ObjectId)
  if (err.name === 'CastError') {
    return res.status(400).json({
      success: false,
      error: 'Invalid ID format'
    });
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      error: 'Invalid token'
    });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      success: false,
      error: 'Token expired'
    });
  }

  // Default error
  const statusCode = err.statusCode || 500;
  const isCritical = statusCode === 500;

  // Log critical 500 errors to AuditLog for alerting
  if (isCritical) {
    try {
      await AuditLog.log({
        action: 'SYSTEM_ERROR_CRITICAL',
        userId: req.user?.userId || null,
        details: `Critical System Error: ${err.message}`,
        riskLevel: 'critical',
        metadata: {
          path: req.path,
          method: req.method,
          stack: err.stack,
          ipAddress: req.ip,
          userAgent: req.headers['user-agent']
        }
      });
    } catch (logError) {
      logger.error('Failed to log critical error to AuditLog:', logError);
    }
  }

  res.status(statusCode).json({
    success: true, // Some clients might expect success: false, but keeping it consistent with existing structure
    success: false,
    error: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};

module.exports = errorHandler;
