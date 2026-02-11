/**
 * Coopvest Africa - Referral System Backend API
 * 
 * Main entry point for the Express server with WebSocket support
 * 
 * Security Features:
 * - JWT authentication
 * - IP whitelisting for admin routes
 * - HTTPS enforcement with HSTS
 * - Rate limiting
 * - Security headers
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const http = require('http');
const connectDB = require('./config/database');
const logger = require('./utils/logger');

// Import services
const websocketService = require('./services/websocketService');

// Import routes
const authRoutes = require('./routes/auth');
const emailVerificationRoutes = require('./routes/emailVerification');
const referralRoutes = require('./routes/referrals');
const ticketRoutes = require('./routes/tickets');
const adminTicketRoutes = require('./routes/adminTickets');
const adminRoutes = require('./routes/admin');
const loanRoutes = require('./routes/loans');
const walletRoutes = require('./routes/wallet');
const userRoutes = require('./routes/user');
const kycRoutes = require('./routes/kyc');
const savingsRoutes = require('./routes/savings');
const rolloverRoutes = require('./routes/rollover');
const investmentsRoutes = require('./routes/investments');

// Import middleware
const errorHandler = require('./middleware/errorHandler');
const { enforceHTTPS, securityHeaders, securityLogger } = require('./middleware/httpsEnforcement');
const { adminIPWhitelist } = require('./middleware/ipWhitelist');

const app = express();
const PORT = process.env.PORT || 8080;

// Create HTTP server
const server = http.createServer(app);

// Connect to MongoDB
connectDB();

// Initialize WebSocket server
websocketService.initialize(server);

// ==============================================================================
// TRUST PROXY (Required for proper IP detection behind load balancer/proxy)
// ==============================================================================
app.set('trust proxy', true);

// ==============================================================================
// HTTPS ENFORCEMENT & SECURITY HEADERS
// ==============================================================================
// Only enforce HTTPS in production
if (process.env.NODE_ENV === 'production') {
  app.use(enforceHTTPS);
}
app.use(securityHeaders);
app.use(securityLogger);

// ==============================================================================
// CORS CONFIGURATION
// ==============================================================================
const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map(origin => origin.trim())
  .filter(origin => origin.length > 0);

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) return callback(null, true);
    
    // Allow localhost for development
    if (allowedOrigins.includes('http://localhost:3000') && origin === 'http://localhost:3000') {
      return callback(null, true);
    }
    if (allowedOrigins.includes('http://localhost:8080') && origin === 'http://localhost:8080') {
      return callback(null, true);
    }
    
    // Check if origin is in allowed list
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    
    // Log rejected origins in production
    if (process.env.NODE_ENV === 'production') {
      logger.warn(`CORS rejected origin: ${origin}`);
    }
    
    return callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Admin-ID'],
  credentials: true,
  maxAge: 86400 // 24 hours
}));

// ==============================================================================
// RATE LIMITING
// ==============================================================================
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: {
    success: false,
    error: 'Too many requests, please try again later.',
    retryAfter: Math.ceil((parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000) / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    // Use X-Forwarded-For for proxied requests
    return req.headers['x-forwarded-for'] || req.ip || req.connection.remoteAddress;
  }
});
app.use('/api/', limiter);

// Stricter rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 requests per window
  message: {
    success: false,
    error: 'Too many authentication attempts, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    return req.body?.email || req.ip || req.connection.remoteAddress;
  }
});

// ==============================================================================
// BODY PARSER
// ==============================================================================
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ==============================================================================
// LOGGING
// ==============================================================================
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
} else {
  // Use morgan with winston in production
  app.use(morgan('combined', {
    stream: { write: message => logger.info(message.trim()) }
  }));
}

// ==============================================================================
// HEALTH CHECK (No IP restriction)
// ==============================================================================
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Coopvest API is running',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// WebSocket stats endpoint
app.get('/ws/stats', (req, res) => {
  const stats = websocketService.getStats();
  res.json({
    success: true,
    websocket: stats
  });
});

// ==============================================================================
// API ROUTES - MEMBER ENDPOINTS (No IP whitelist)
// ==============================================================================
app.use('/api/v1/auth', authLimiter, authRoutes);
app.use('/api/v1/auth', emailVerificationRoutes);
app.use('/api/v1/referrals', referralRoutes);
app.use('/api/v1/tickets', ticketRoutes);
app.use('/api/v1/loans', loanRoutes);
app.use('/api/v1/wallet', walletRoutes);
app.use('/api/v1/user', userRoutes);
app.use('/api/v1/kyc', kycRoutes);
app.use('/api/v1/savings', savingsRoutes);
app.use('/api/v1/rollover', rolloverRoutes);
app.use('/api/v1/investments', investmentsRoutes);

// Aliases for requested endpoints
app.post('/api/auth/login', authLimiter, (req, res, next) => {
  req.url = '/login';
  authRoutes(req, res, next);
});
app.post('/api/auth/verify-email', (req, res, next) => {
  req.url = '/verify-otp';
  emailVerificationRoutes(req, res, next);
});
app.post('/api/auth/resend-verification', (req, res, next) => {
  req.url = '/resend-otp';
  emailVerificationRoutes(req, res, next);
});
app.get('/api/user/profile', (req, res, next) => {
  req.url = '/profile';
  authRoutes(req, res, next);
});
app.post('/api/loans/apply', (req, res, next) => {
  req.url = '/apply';
  loanRoutes(req, res, next);
});
app.get('/api/wallet/balance', (req, res, next) => {
  req.url = '/balance';
  walletRoutes(req, res, next);
});

// ==============================================================================
// API ROUTES - ADMIN ENDPOINTS (With IP whitelist)
// ==============================================================================
// Apply IP whitelist to all admin routes
app.use('/api/v1/admin', adminIPWhitelist, adminRoutes);
app.use('/api/v1/admin', adminIPWhitelist, adminTicketRoutes);

// ==============================================================================
// 404 HANDLER
// ==============================================================================
app.use((req, res, next) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
    path: req.path
  });
});

// ==============================================================================
// ERROR HANDLER
// ==============================================================================
app.use(errorHandler);

// ==============================================================================
// START SERVER
// ==============================================================================
server.listen(PORT, '0.0.0.0', () => {
  logger.info(`🚀 Coopvest Referral API running on port ${PORT}`);
  logger.info(`🌐 WebSocket endpoint: ws://localhost:${PORT}/ws`);
  logger.info(`💚 Health check: http://localhost:${PORT}/health`);
  logger.info(`📊 WebSocket stats: http://localhost:${PORT}/ws/stats`);
  logger.info(`📦 Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`🔒 HTTPS Enforced: ${process.env.NODE_ENV === 'production'}`);
  logger.info(`🛡️ IP Whitelisting: ${process.env.ADMIN_IP_WHITELIST ? 'Enabled' : 'Disabled'}`);
});

// ==============================================================================
// GRACEFUL SHUTDOWN
// ==============================================================================

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  logger.error('Unhandled Rejection:', err);
  websocketService.shutdown();
  server.close(() => {
    logger.info('Process terminated due to unhandled rejection');
    process.exit(1);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception:', err);
  process.exit(1);
});

// SIGTERM and SIGINT handlers
const shutdownHandler = (signal) => {
  logger.info(`${signal} received. Shutting down gracefully...`);
  
  // Stop accepting new connections
  server.close(() => {
    logger.info('HTTP server closed');
  });
  
  // Shutdown WebSocket
  websocketService.shutdown();
  
  // Flush logs
  logger.shutdown(() => {
    logger.info('Logger shutdown complete');
    process.exit(0);
  });
  
  // Force exit after 30 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
};

process.on('SIGTERM', () => shutdownHandler('SIGTERM'));
process.on('SIGINT', () => shutdownHandler('SIGINT'));

// ==============================================================================
// UNHANDLED ROUTE WARNING (Development)
// ==============================================================================
if (process.env.NODE_ENV !== 'production') {
  app._router.stack.forEach((layer) => {
    if (layer.route) {
      const methods = Object.keys(layer.route.methods).join(', ').toUpperCase();
      logger.debug(`Route: ${methods} ${layer.route.path}`);
    }
  });
}

module.exports = app;
