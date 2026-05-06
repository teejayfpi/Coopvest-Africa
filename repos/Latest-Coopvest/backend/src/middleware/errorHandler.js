/**
 * Error Handler Middleware
 *
 * Centralized error handling. Best-effort audit logging to Supabase
 * (`audit_logs`) is non-blocking; failures are logged but never surface to
 * the caller.
 */

const logger = require('../utils/logger');
const supabase = require('../config/supabase');

const errorHandler = async (err, req, res, next) => {
  logger.error(`${req.method} ${req.path} - Error:`, {
    message: err.message,
    stack: err.stack,
    userId: req.user?.userId || 'anonymous',
    ip: req.ip,
  });

  if (err.name === 'ValidationError') {
    return res.status(400).json({ success: false, error: 'Validation Error', details: err.message });
  }
  if (err.name === 'UnauthorizedError' || err.name === 'JsonWebTokenError') {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  // Postgres unique-violation
  if (err.code === '23505') {
    return res.status(409).json({ success: false, error: 'Duplicate entry' });
  }
  // Postgres FK violation
  if (err.code === '23503') {
    return res.status(400).json({ success: false, error: 'Related record not found' });
  }

  const statusCode = err.statusCode || 500;

  // Best-effort audit for server errors
  if (statusCode >= 500) {
    try {
      await supabase.from('audit_logs').insert({
        actor_id: req.user?.id || null,
        action: 'SERVER_ERROR',
        target_model: 'Request',
        target_id: null,
        metadata: {
          method: req.method,
          path: req.path,
          error: err.message,
          ip: req.ip,
        },
      });
    } catch (logErr) {
      logger.warn('Failed to write error to audit_logs:', logErr.message);
    }
  }

  res.status(statusCode).json({
    success: false,
    error: err.message || 'Internal server error',
  });
};

module.exports = errorHandler;
