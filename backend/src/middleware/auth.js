/**
 * Authentication Middleware
 * 
 * JWT-based authentication middleware
 * Extracts userId ONLY from JWT token (not from headers)
 */

const jwt = require('jsonwebtoken');
const tokenBlacklistService = require('../services/tokenBlacklistService');
const AuditLog = require('../models/AuditLog');
const logger = require('../utils/logger');

// Validate JWT secret at module load
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('FATAL: JWT_SECRET environment variable is not set!');
}

// Ensure token blacklist is initialized before middleware runs
tokenBlacklistService.init().catch(err => {
  logger.warn('Token blacklist initialization deferred:', err.message);
});

/**
 * Authentication middleware
 * Verifies JWT token and extracts userId from token payload
 */
const authenticate = async (req, res, next) => {
  try {
    // Get token from Authorization header ONLY
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required. Provide Bearer token in Authorization header.'
      });
    }

    const token = authHeader.split(' ')[1];

    // Check if token is blacklisted
    const isBlacklisted = await tokenBlacklistService.isBlacklisted(token);
    if (isBlacklisted) {
      return res.status(401).json({
        success: false,
        error: 'Token has been revoked. Please login again.'
      });
    }

    // Verify and decode token
    const decoded = jwt.verify(token, JWT_SECRET);

    // Attach user info to request (from JWT ONLY)
    req.user = {
      userId: decoded.userId,
      iat: decoded.iat,
      exp: decoded.exp
    };

    // Attach raw token for potential use in other services
    req.token = token;

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Token has expired. Please login again.'
      });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: 'Invalid token'
      });
    }

    logger.error('Authentication error:', error);
    res.status(401).json({
      success: false,
      error: 'Authentication failed'
    });
  }
};

/**
 * Optional authentication middleware
 * Same as authenticate but doesn't fail if no token provided
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split(' ')[1];

    // Check if token is blacklisted
    const isBlacklisted = await tokenBlacklistService.isBlacklisted(token);
    if (isBlacklisted) {
      return next();
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    
    req.user = {
      userId: decoded.userId,
      iat: decoded.iat,
      exp: decoded.exp
    };
    req.token = token;

    next();
  } catch (error) {
    // Silently fail for optional auth
    next();
  }
};

/**
 * Admin-only middleware
 * Requires authentication AND admin role
 */
const requireAdmin = async (req, res, next) => {
  try {
    // First run authentication
    await authenticate(req, res, async () => {
      if (!req.user) {
        return; // authenticate already sent response
      }

      // Check if user is admin
      const { User } = require('../models');
      const user = await User.findOne({ userId: req.user.userId });
      
      if (!user || !['admin', 'superadmin'].includes(user.role)) {
        // Log unauthorized admin access attempt
        await AuditLog.log({
          action: 'UNAUTHORIZED_ACCESS_ATTEMPT',
          userId: req.user.userId,
          details: `Unauthorized admin access attempt to ${req.path}`,
          riskLevel: 'high',
          metadata: {
            path: req.path,
            method: req.method,
            ipAddress: req.ip,
            userAgent: req.headers['user-agent']
          }
        });

        return res.status(403).json({
          success: false,
          error: 'Admin access required'
        });
      }

      req.user.role = user.role;
      next();
    });
  } catch (error) {
    logger.error('Admin auth error:', error);
    res.status(500).json({
      success: false,
      error: 'Authorization check failed'
    });
  }
};

module.exports = {
  authenticate,
  optionalAuth,
  requireAdmin,
  JWT_SECRET
};
