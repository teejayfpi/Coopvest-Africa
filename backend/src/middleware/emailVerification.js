/**
 * Email Verification Middleware
 * 
 * Middleware to require email verification for protected routes
 */

const { User } = require('../models');
const logger = require('../utils/logger');

/**
 * Middleware to check if user has verified their email
 * 
 * Usage:
 * - Require email verification: requireEmailVerification
 * - Optional check: optionalEmailVerification (sets req.userEmailVerified)
 */
const requireEmailVerification = async (req, res, next) => {
  try {
    // Get user from JWT middleware (if auth middleware already ran)
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED'
      });
    }

    const jwt = require('jsonwebtoken');
    const JWT_SECRET = process.env.JWT_SECRET;
    
    try {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, JWT_SECRET);
      
      const user = await User.findOne({ userId: decoded.userId });
      
      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      // Check if email is verified
      if (!user.emailVerification.isVerified) {
        return res.status(403).json({
          success: false,
          error: 'Email verification required',
          code: 'EMAIL_VERIFICATION_REQUIRED',
          message: 'Please verify your email address to access this resource',
          requiresVerification: true,
          // Include helpful info for the client
          verificationEndpoints: {
            send: 'POST /api/v1/auth/send-verification-email?email={userEmail}',
            status: 'GET /api/v1/auth/check-email-verification?email={userEmail}'
          }
        });
      }

      // Attach user to request for downstream handlers
      req.user = user;
      req.userId = decoded.userId;
      
      next();
    } catch (jwtError) {
      return res.status(401).json({
        success: false,
        error: 'Invalid or expired token',
        code: 'INVALID_TOKEN'
      });
    }
  } catch (error) {
    logger.error('Email verification middleware error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      code: 'SERVER_ERROR'
    });
  }
};

/**
 * Optional email verification check
 * Attaches email verification status to request but doesn't block access
 */
const optionalEmailVerification = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // No auth, continue without email verification status
      req.userEmailVerified = null;
      return next();
    }

    const jwt = require('jsonwebtoken');
    const JWT_SECRET = process.env.JWT_SECRET;
    
    try {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, JWT_SECRET);
      
      const user = await User.findOne({ userId: decoded.userId });
      
      if (user) {
        req.userEmailVerified = user.emailVerification.isVerified;
        req.user = user;
        req.userId = decoded.userId;
      } else {
        req.userEmailVerified = null;
      }
      
      next();
    } catch (jwtError) {
      req.userEmailVerified = null;
      next();
    }
  } catch (error) {
    logger.error('Optional email verification middleware error:', error);
    req.userEmailVerified = null;
    next();
  }
};

/**
 * Create a middleware that requires email verification for specific routes
 * 
 * Options:
 * - excludeIfVerified: Array of paths to exclude from verification requirement
 * - customMessage: Custom error message
 */
const createEmailVerificationMiddleware = (options = {}) => {
  const { excludeIfVerified, customMessage } = options;
  
  return async (req, res, next) => {
    // Skip if path is in exclusion list
    if (excludeIfVerified && excludeIfVerified.some(path => req.path.startsWith(path))) {
      return next();
    }
    
    return requireEmailVerification(req, res, next);
  };
};

/**
 * Routes that require email verification
 * Add these routes to the list that need email verification
 */
const PROTECTED_ROUTES = {
  // Wallet & Savings
  '/api/v1/wallet': ['POST', 'PUT', 'DELETE'],
  '/api/v1/savings': ['POST', 'PUT', 'DELETE'],
  
  // Loans
  '/api/v1/loans': ['POST', 'PUT', 'DELETE'],
  '/api/v1/guarantors': ['POST', 'PUT', 'DELETE'],
  
  // Investments
  '/api/v1/investments': ['POST', 'PUT', 'DELETE'],
  
  // Profile (sensitive operations)
  '/api/v1/user/profile': ['PUT', 'DELETE'],
  '/api/v1/user/kyc': ['POST', 'PUT'],
  
  // Referrals (certain operations)
  '/api/v1/referrals/withdraw': ['POST'],
  '/api/v1/referrals/claim': ['POST'],
};

/**
 * Automatic route protection middleware
 * Use this to protect multiple routes based on configuration
 */
const autoProtectRoutes = (routesConfig = PROTECTED_ROUTES) => {
  return async (req, res, next) => {
    const path = req.path;
    const method = req.method;
    
    // Check if this route/method combination needs protection
    const routeConfig = routesConfig[path];
    
    if (routeConfig && routeConfig.includes(method)) {
      return requireEmailVerification(req, res, next);
    }
    
    next();
  };
};

module.exports = {
  requireEmailVerification,
  optionalEmailVerification,
  createEmailVerificationMiddleware,
  autoProtectRoutes,
  PROTECTED_ROUTES
};
