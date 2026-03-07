/**
 * HTTPS Enforcement Middleware
 * 
 * Ensures all API communication is over HTTPS in production.
 * Adds HSTS headers for browser security.
 */

const logger = require('../utils/logger');

/**
 * Get the HSTS configuration from environment
 */
const getHSTSConfig = () => ({
  maxAge: parseInt(process.env.HSTS_MAX_AGE) || 31536000, // 1 year
  includeSubdomains: process.env.HSTS_INCLUDE_SUBDOMAINS === 'true',
  preload: process.env.HSTS_PRELOAD === 'true'
});

/**
 * Build HSTS header value
 */
const buildHSTSHeader = () => {
  const config = getHSTSConfig();
  let header = `max-age=${config.maxAge}`;
  
  if (config.includeSubdomains) {
    header += '; includeSubDomains';
  }
  
  if (config.preload) {
    header += '; preload';
  }
  
  return header;
};

/**
 * Middleware to enforce HTTPS in production
 * 
 * In development mode (NODE_ENV !== 'production'), this middleware
 * will not redirect requests but will still add HSTS headers.
 */
const enforceHTTPS = (req, res, next) => {
  // Check if HTTPS enforcement is enabled
  const enforceHttps = process.env.ENFORCE_HTTPS === 'true';
  
  // Get protocol from X-Forwarded-Proto header (for proxied requests)
  const proto = req.headers['x-forwarded-protocol'] || 
                req.headers['x-forwarded-proto'] ||
                req.protocol ||
                'http';
  
  const isHttps = proto.toLowerCase() === 'https' || req.socket.encrypted;
  
  // Add HSTS header to all responses
  const hstsHeader = buildHSTSHeader();
  res.setHeader('Strict-Transport-Security', hstsHeader);
  
  // In development or if HTTPS enforcement is disabled, just continue
  if (!enforceHttps || process.env.NODE_ENV !== 'production') {
    return next();
  }
  
  // Check if request is already HTTPS
  if (isHttps) {
    return next();
  }
  
  // Redirect HTTP to HTTPS
  const host = req.headers.host || req.hostname;
  const httpsHost = host.replace(/:\d+$/, ''); // Remove port if present
  
  logger.warn(`HTTP request detected, redirecting to HTTPS: ${req.method} ${req.originalUrl} from ${req.ip}`);
  
  return res.redirect(301, `https://${httpsHost}${req.originalUrl}`);
};

/**
 * Middleware to add security headers
 * Adds various security-related HTTP headers
 */
const securityHeaders = (req, res, next) => {
  // Prevent XSS attacks
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  
  // Content Security Policy - adjust based on your needs
  res.setHeader('Content-Security-Policy', "default-src 'self'");
  
  // Referrer Policy
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  
  // Permissions Policy
  res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  
  // Cache control for sensitive endpoints
  const sensitivePaths = ['/api/v1/admin', '/api/v1/auth/login', '/api/v1/auth/register'];
  const isSensitivePath = sensitivePaths.some(path => req.path.startsWith(path));
  
  if (isSensitivePath) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }
  
  next();
};

/**
 * Middleware to log request details with security context
 */
const securityLogger = (req, res, next) => {
  const startTime = Date.now();
  
  // Log request
  logger.debug(`Request: ${req.method} ${req.path} from ${req.ip}`, {
    userAgent: req.headers['user-agent'],
    contentType: req.headers['content-type']
  });
  
  // Log response when sent
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const logLevel = res.statusCode >= 400 ? 'warn' : 'debug';
    
    logger[logLevel](`Response: ${req.method} ${req.path} ${res.statusCode} ${duration}ms`, {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip
    });
  });
  
  next();
};

module.exports = {
  enforceHTTPS,
  securityHeaders,
  securityLogger,
  getHSTSConfig,
  buildHSTSHeader
};
