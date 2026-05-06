/**
 * IP Whitelist Middleware for Admin Portal Security
 * 
 * This middleware restricts admin API access to allowed IP addresses.
 * Configure ADMIN_IP_WHITELIST in .env file.
 * 
 * Usage:
 *   - Leave ADMIN_IP_WHITELIST empty to disable IP filtering (development only!)
 *   - Use comma-separated IPs for multiple allowed addresses
 *   - Supports IPv4 and IPv6 addresses
 */

const logger = require('../utils/logger');

/**
 * Parse IP whitelist from environment variable
 * @returns {string[]} Array of allowed IP addresses
 */
const parseWhitelist = () => {
  const whitelistEnv = process.env.ADMIN_IP_WHITELIST || '';
  
  if (!whitelistEnv.trim()) {
    return []; // Empty means no filtering
  }
  
  return whitelistEnv
    .split(',')
    .map(ip => ip.trim())
    .filter(ip => ip.length > 0);
};

/**
 * Check if IP is in the allowed range (supports CIDR notation)
 * @param {string} clientIP - The client IP address to check
 * @param {string} allowedIP - The allowed IP or CIDR range
 * @returns {boolean} True if IP is allowed
 */
const isIPInRange = (clientIP, allowedIP) => {
  // Direct match
  if (clientIP === allowedIP) return true;
  
  // CIDR notation support (e.g., 192.168.1.0/24)
  if (allowedIP.includes('/')) {
    const [range, bits] = allowedIP.split('/');
    const mask = parseInt(bits, 10);
    
    const clientIPNum = ipToNumber(clientIP);
    const rangeNum = ipToNumber(range);
    const maskNum = ~((1 << (32 - mask)) - 1) >>> 0;
    
    return (clientIPNum & maskNum) === (rangeNum & maskNum);
  }
  
  return false;
};

/**
 * Convert IP address to number
 * @param {string} ip - IP address
 * @returns {number} Numeric representation
 */
const ipToNumber = (ip) => {
  const parts = ip.split('.');
  return ((parseInt(parts[0], 10) << 24) |
          (parseInt(parts[1], 10) << 16) |
          (parseInt(parts[2], 10) << 8) |
          parseInt(parts[3], 10)) >>> 0;
};

/**
 * Get client IP address from request
 * Handles proxied requests (X-Forwarded-For)
 * @param {Object} req - Express request object
 * @returns {string} Client IP address
 */
const getClientIP = (req) => {
  // Check X-Forwarded-For header (for proxied requests)
  const forwardedFor = req.headers['x-forwarded-for'];
  if (forwardedFor) {
    // Get the first IP in the chain (original client)
    const ips = forwardedFor.split(',').map(ip => ip.trim());
    return ips[0];
  }
  
  // Check X-Real-IP header
  const realIP = req.headers['x-real-ip'];
  if (realIP) {
    return realIP;
  }
  
  // Fallback to socket address
  return req.socket?.remoteAddress || 
         req.connection?.remoteAddress || 
         '127.0.0.1';
};

/**
 * Clean IP address (remove IPv6 prefix and port)
 * @param {string} ip - Raw IP address
 * @returns {string} Cleaned IP address
 */
const cleanIP = (ip) => {
  if (!ip) return '127.0.0.1';
  
  // Remove IPv6 prefix ::ffff: for IPv4 mapped addresses
  if (ip.startsWith('::ffff:')) {
    ip = ip.substring(7);
  }
  
  // Remove port if present (e.g., 192.168.1.1:8080)
  if (ip.includes(':') && !ip.startsWith['[']) {
    ip = ip.split(':')[0];
  }
  
  return ip;
};

/**
 * IP Whitelist Middleware Factory
 * 
 * @param {Object} options - Configuration options
 * @param {boolean} options.allowWithoutWhitelist - Allow all IPs if whitelist is empty
 * @param {boolean} options.logBlocked - Log blocked access attempts
 * @param {string[]} options.excludePaths - Paths to exclude from IP check
 * @returns {Function} Express middleware function
 */
const createIPWhitelist = (options = {}) => {
  const {
    allowWithoutWhitelist = false,
    logBlocked = true,
    excludePaths = ['/health', '/ws/stats']
  } = options;
  
  return (req, res, next) => {
    // Skip IP check for excluded paths
    const requestPath = req.path || req.url;
    if (excludePaths.some(path => requestPath.startsWith(path))) {
      return next();
    }
    
    const whitelist = parseWhitelist();
    
    // If no whitelist configured, decide based on option
    if (whitelist.length === 0) {
      if (allowWithoutWhitelist) {
        logger.warn('IP whitelist is empty - allowing all access. NOT RECOMMENDED FOR PRODUCTION!');
        return next();
      } else {
        logger.error('IP whitelist is empty but filtering is enabled. Access denied.');
        return res.status(403).json({
          success: false,
          error: 'Access denied. Admin IP whitelist not configured.'
        });
      }
    }
    
    const clientIP = cleanIP(getClientIP(req));
    
    // Check if IP is allowed
    const isAllowed = whitelist.some(allowedIP => isIPInRange(clientIP, allowedIP));
    
    if (!isAllowed) {
      if (logBlocked) {
        logger.warn(`Blocked admin access from unauthorized IP: ${clientIP}`, {
          path: requestPath,
          method: req.method,
          userAgent: req.headers['user-agent']
        });
      }
      
      return res.status(403).json({
        success: false,
        error: 'Access denied. Your IP address is not authorized.'
      });
    }
    
    logger.debug(`Allowed admin access from: ${clientIP}`);
    next();
  };
};

/**
 * Apply IP whitelist only to admin routes
 * This should be used alongside authentication middleware
 */
const adminIPWhitelist = createIPWhitelist({
  allowWithoutWhitelist: false,
  logBlocked: true,
  excludePaths: ['/health', '/ws/stats']
});

/**
 * Strict IP whitelist for sensitive operations
 * Can be used for specific high-security endpoints
 */
const strictIPWhitelist = createIPWhitelist({
  allowWithoutWhitelist: false,
  logBlocked: true,
  excludePaths: ['/health']
});

module.exports = {
  createIPWhitelist,
  adminIPWhitelist,
  strictIPWhitelist,
  parseWhitelist,
  getClientIP,
  cleanIP,
  isIPInRange
};
