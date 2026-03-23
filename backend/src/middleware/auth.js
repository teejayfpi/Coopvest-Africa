/**
 * Authentication Middleware
 * 
 * Supabase-based authentication middleware
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

/**
 * Authentication middleware
 * Verifies Supabase token and extracts user info
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required. Provide Bearer token in Authorization header.'
      });
    }

    const token = authHeader.split(' ')[1];

    // Verify token with Supabase
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid or expired token'
      });
    }

    // Attach user info to request
    req.user = {
      id: user.id,
      email: user.email,
      userId: user.user_metadata.userId || user.id, // Support both Supabase ID and custom userId
      role: user.user_metadata.role || 'user'
    };

    req.token = token;
    next();
  } catch (error) {
    logger.error('Authentication error:', error);
    res.status(401).json({
      success: false,
      error: 'Authentication failed'
    });
  }
};

/**
 * Optional authentication middleware
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (!error && user) {
      req.user = {
        id: user.id,
        email: user.email,
        userId: user.user_metadata.userId || user.id,
        role: user.user_metadata.role || 'user'
      };
      req.token = token;
    }

    next();
  } catch (error) {
    next();
  }
};

/**
 * Admin-only middleware
 */
const requireAdmin = async (req, res, next) => {
  await authenticate(req, res, () => {
    if (req.user && (req.user.role === 'admin' || req.user.role === 'superadmin')) {
      next();
    } else {
      res.status(403).json({
        success: false,
        error: 'Admin access required'
      });
    }
  });
};

module.exports = {
  authenticate,
  optionalAuth,
  requireAdmin
};
