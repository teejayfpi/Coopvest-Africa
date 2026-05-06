/**
 * Winston Logger Configuration with Persistent Logging
 * 
 * Features:
 * - Console logging with colorized output
 * - File logging with rotation (daily + size-based)
 * - JSON format for log parsing
 * - External log service support (DataDog, Splunk, etc.)
 */

require('dotenv').config();
const winston = require('winston');
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');

// Ensure log directory exists
const LOG_DIR = process.env.LOG_DIR || './logs';
const LOG_TO_FILE = process.env.LOG_TO_FILE === 'true';
const LOG_LEVEL = process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug');
const LOG_EXTERNAL_SERVICE = process.env.LOG_EXTERNAL_SERVICE === 'true';
const LOG_EXTERNAL_URL = process.env.LOG_EXTERNAL_URL || '';

// Create log directory if it doesn't exist
if (LOG_TO_FILE && !fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

// Custom format for JSON logs (compatible with log aggregators)
const jsonFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

// Console format with colors
const consoleFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ timestamp, level, message, stack, ...meta }) => {
    let msg = `${timestamp} [${level.toUpperCase()}]: ${message}`;
    if (Object.keys(meta).length > 0) {
      msg += ` ${JSON.stringify(meta)}`;
    }
    if (stack) {
      msg += `\n${stack}`;
    }
    return msg;
  })
);

// Transport for file logging with rotation
const fileTransportOptions = {
  level: LOG_LEVEL,
  filename: path.join(LOG_DIR, 'coopvest-%DATE%.log'),
  datePattern: 'YYYY-MM-DD',
  maxSize: parseInt(process.env.LOG_MAX_SIZE) || 10 * 1024 * 1024, // 10MB default
  maxFiles: parseInt(process.env.LOG_MAX_FILES) || 30, // Keep 30 days of logs
  format: jsonFormat,
  handleExceptions: true,
  handleRejections: true
};

// Error log file (always logs errors)
const errorTransportOptions = {
  level: 'error',
  filename: path.join(LOG_DIR, 'coopvest-error-%DATE%.log'),
  datePattern: 'YYYY-MM-DD',
  maxSize: 10 * 1024 * 1024,
  maxFiles: 90, // Keep error logs longer
  format: jsonFormat,
  handleExceptions: true,
  handleRejections: true
};

// External log service transport (optional)
class ExternalLogTransport extends winston.Transport {
  constructor(opts) {
    super(opts);
    this.serviceUrl = opts.serviceUrl || process.env.LOG_EXTERNAL_URL;
    this.batch = [];
    this.batchInterval = opts.batchInterval || 5000; // Send logs every 5 seconds
    this.startBatching();
  }

  log(info, callback) {
    setImmediate(() => {
      this.emit('logged', info);
    });

    if (!this.serviceUrl) return callback();

    this.batch.push({
      level: info.level,
      message: info.message,
      timestamp: info.timestamp,
      ...info
    });

    callback();
  }

  startBatching() {
    setInterval(() => {
      if (this.batch.length === 0) return;

      const logsToSend = [...this.batch];
      this.batch = [];

      this.sendToExternalService(logsToSend);
    }, this.batchInterval);
  }

  sendToExternalService(logs) {
    const data = JSON.stringify({ logs, source: 'coopvest-api' });
    
    const url = new URL(this.serviceUrl);
    const transport = url.protocol === 'https:' ? https : http;

    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        'User-Agent': 'Coopvest-Logger/1.0'
      },
      timeout: 10000
    };

    const req = transport.request(options, (res) => {
      if (res.statusCode !== 200 && res.statusCode !== 201) {
        console.error(`External log service error: ${res.statusCode}`);
      }
    });

    req.on('error', (err) => {
      console.error('Failed to send logs to external service:', err.message);
    });

    req.write(data);
    req.end();
  }

  shutdown() {
    // Send any remaining logs
    if (this.batch.length > 0) {
      this.sendToExternalService(this.batch);
    }
  }
}

// Build transports array
const transports = [
  // Console transport
  new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      consoleFormat
    )
  })
];

// Add file transports if enabled
if (LOG_TO_FILE) {
  transports.push(
    new winston.transports.File(fileTransportOptions),
    new winston.transports.File(errorTransportOptions)
  );
}

// Add external transport if configured
if (LOG_EXTERNAL_SERVICE && LOG_EXTERNAL_URL) {
  transports.push(
    new ExternalLogTransport({
      level: LOG_LEVEL,
      serviceUrl: LOG_EXTERNAL_URL
    })
  );
}

// Create the logger
const logger = winston.createLogger({
  level: LOG_LEVEL,
  format: jsonFormat,
  defaultMeta: {
    service: 'coopvest-api',
    environment: process.env.NODE_ENV || 'development',
    version: '1.0.0'
  },
  transports,
  exitOnError: false
});

// Add stream for Morgan HTTP logger (optional)
logger.stream = {
  write: (message) => {
    logger.http(message.trim());
  }
};

/**
 * Create a child logger with additional context
 */
logger.child = (context) => {
  return logger.child(context);
};

/**
 * Log with request context
 */
logger.withRequest = (req, context = {}) => {
  return logger.child({
    requestId: context.requestId || req.requestId || 'unknown',
    userId: req.user?.userId || 'anonymous',
    ip: req.ip || req.connection?.remoteAddress,
    path: req.path,
    method: req.method,
    ...context
  });
};

/**
 * Shutdown the logger (flush any pending logs)
 */
logger.shutdown = (callback) => {
  logger.transports.forEach(transport => {
    if (typeof transport.shutdown === 'function') {
      transport.shutdown();
    }
  });
  
  // Handle ExternalLogTransport
  const externalTransport = logger.transports.find(t => t instanceof ExternalLogTransport);
  if (externalTransport) {
    externalTransport.shutdown();
  }
  
  if (callback) callback();
};

module.exports = logger;
