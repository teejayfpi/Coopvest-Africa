/**
 * WebSocket Service
 * 
 * Real-time communication for loan progress updates and notifications
 */

const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

class WebSocketService {
  constructor() {
    this.wss = null;
    this.clients = new Map(); // userId -> Set of WebSocket connections
    this.loanRooms = new Map(); // loanId -> Set of userIds subscribed
    this.heartbeatInterval = null;
    
    // JWT secret for token verification
    this.jwtSecret = process.env.JWT_SECRET || 'coopvest-jwt-secret-2025';
  }

  /**
   * Initialize WebSocket server
   */
  initialize(server) {
    this.wss = new WebSocket.Server({ 
      server,
      path: '/ws'
    });

    logger.info('WebSocket server initializing...');

    this.wss.on('connection', (ws, req) => {
      this.handleConnection(ws, req);
    });

    // Start heartbeat to detect stale connections
    this.startHeartbeat();

    logger.info('WebSocket server initialized on path: /ws');
  }

  /**
   * Handle new WebSocket connection
   */
  handleConnection(ws, req) {
    const connectionId = uuidv4();
    ws.connectionId = connectionId;
    ws.isAlive = true;
    ws.userId = null;
    ws.subscribedLoans = new Set();

    logger.info(`New WebSocket connection: ${connectionId}`);

    // Handle pong (heartbeat response)
    ws.on('pong', () => {
      ws.isAlive = true;
    });

    // Handle incoming messages
    ws.on('message', (data) => {
      this.handleMessage(ws, data);
    });

    // Handle connection close
    ws.on('close', () => {
      this.handleDisconnect(ws);
    });

    // Handle errors
    ws.on('error', (error) => {
      logger.error(`WebSocket error for ${connectionId}:`, error);
      this.handleDisconnect(ws);
    });

    // Send connection confirmation
    this.sendToClient(ws, {
      type: 'connected',
      connectionId,
      message: 'Connected to Coopvest WebSocket'
    });
  }

  /**
   * Handle incoming WebSocket message
   */
  handleMessage(ws, data) {
    try {
      const message = JSON.parse(data.toString());
      
      switch (message.type) {
        case 'authenticate':
          this.handleAuthenticate(ws, message);
          break;
          
        case 'subscribe_loan':
          this.handleSubscribeLoan(ws, message);
          break;
          
        case 'unsubscribe_loan':
          this.handleUnsubscribeLoan(ws, message);
          break;
          
        case 'ping':
          this.sendToClient(ws, { type: 'pong', timestamp: Date.now() });
          break;
          
        default:
          logger.warn(`Unknown message type: ${message.type}`);
          this.sendToClient(ws, {
            type: 'error',
            message: `Unknown message type: ${message.type}`
          });
      }
    } catch (error) {
      logger.error('Error parsing WebSocket message:', error);
      this.sendToClient(ws, {
        type: 'error',
        message: 'Invalid message format'
      });
    }
  }

  /**
   * Handle authentication message
   */
  handleAuthenticate(ws, message) {
    try {
      const { token } = message;
      
      if (!token) {
        this.sendToClient(ws, {
          type: 'error',
          message: 'Authentication token required'
        });
        return;
      }

      // Verify JWT token
      const decoded = jwt.verify(token, this.jwtSecret);
      ws.userId = decoded.userId || decoded.user_id;
      
      // Add to clients map
      if (!this.clients.has(ws.userId)) {
        this.clients.set(ws.userId, new Set());
      }
      this.clients.get(ws.userId).add(ws);

      logger.info(`User ${ws.userId} authenticated via WebSocket`);

      this.sendToClient(ws, {
        type: 'authenticated',
        userId: ws.userId,
        message: 'Successfully authenticated'
      });
    } catch (error) {
      logger.error('WebSocket authentication error:', error);
      this.sendToClient(ws, {
        type: 'error',
        message: 'Authentication failed'
      });
    }
  }

  /**
   * Handle loan subscription
   */
  handleSubscribeLoan(ws, message) {
    const { loanId } = message;
    
    if (!ws.userId) {
      this.sendToClient(ws, {
        type: 'error',
        message: 'Please authenticate first'
      });
      return;
    }

    if (!loanId) {
      this.sendToClient(ws, {
        type: 'error',
        message: 'Loan ID required'
      });
      return;
    }

    // Add to loan room
    if (!this.loanRooms.has(loanId)) {
      this.loanRooms.set(loanId, new Set());
    }
    this.loanRooms.get(loanId).add(ws.userId);
    ws.subscribedLoans.add(loanId);

    logger.info(`User ${ws.userId} subscribed to loan ${loanId}`);

    this.sendToClient(ws, {
      type: 'subscribed',
      loanId,
      message: `Subscribed to loan ${loanId}`
    });

    // Send current progress
    this.sendLoanProgress(loanId, ws.userId);
  }

  /**
   * Handle loan unsubscription
   */
  handleUnsubscribeLoan(ws, message) {
    const { loanId } = message;
    
    if (!loanId) {
      this.sendToClient(ws, {
        type: 'error',
        message: 'Loan ID required'
      });
      return;
    }

    // Remove from loan room
    if (this.loanRooms.has(loanId)) {
      this.loanRooms.get(loanId).delete(ws.userId);
    }
    ws.subscribedLoans.delete(loanId);

    logger.info(`User ${ws.userId} unsubscribed from loan ${loanId}`);

    this.sendToClient(ws, {
      type: 'unsubscribed',
      loanId,
      message: `Unsubscribed from loan ${loanId}`
    });
  }

  /**
   * Handle client disconnect
   */
  handleDisconnect(ws) {
    // Remove from clients map
    if (ws.userId && this.clients.has(ws.userId)) {
      this.clients.get(ws.userId).delete(ws);
      if (this.clients.get(ws.userId).size === 0) {
        this.clients.delete(ws.userId);
      }
    }

    // Remove from loan rooms
    ws.subscribedLoans.forEach(loanId => {
      if (this.loanRooms.has(loanId)) {
        this.loanRooms.get(loanId).delete(ws.userId);
      }
    });

    logger.info(`WebSocket disconnected: ${ws.connectionId}`);
  }

  /**
   * Start heartbeat interval
   */
  startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      this.wss.clients.forEach(ws => {
        if (ws.isAlive === false) {
          return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, 30000); // 30 seconds
  }

  /**
   * Stop heartbeat interval
   */
  stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
  }

  /**
   * Send message to specific client
   */
  sendToClient(ws, data) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(data));
    }
  }

  /**
   * Send message to user across all their connections
   */
  sendToUser(userId, data) {
    if (this.clients.has(userId)) {
      this.clients.get(userId).forEach(ws => {
        this.sendToClient(ws, data);
      });
    }
  }

  /**
   * Send loan progress update to all subscribers of a loan
   */
  broadcastLoanProgress(loanId, progress) {
    if (!this.loanRooms.has(loanId)) {
      return;
    }

    const message = {
      type: 'loan_progress',
      loanId,
      timestamp: new Date().toISOString(),
      progress: {
        guarantorsFound: progress.guarantorsFound,
        guarantorsRequired: progress.guarantorsRequired,
        percentage: Math.round((progress.guarantorsFound / progress.guarantorsRequired) * 100),
        remaining: progress.guarantorsRequired - progress.guarantorsFound
      },
      guarantors: progress.guarantors || []
    };

    // Get all userIds subscribed to this loan
    const subscribers = this.loanRooms.get(loanId);
    
    subscribers.forEach(userId => {
      this.sendToUser(userId, message);
    });

    logger.debug(`Broadcasted progress update for loan ${loanId} to ${subscribers.size} subscribers`);
  }

  /**
   * Send loan progress to specific user
   */
  sendLoanProgress(loanId, userId) {
    // In production, fetch from database
    const mockProgress = {
      guarantorsFound: 2,
      guarantorsRequired: 3,
      guarantors: [
        { name: 'Jane Smith', phone: '+23480****5678', status: 'approved', timestamp: new Date().toISOString() },
        { name: 'Mike Johnson', phone: '+23480****9012', status: 'approved', timestamp: new Date().toISOString() }
      ]
    };

    this.sendToUser(userId, {
      type: 'loan_progress',
      loanId,
      timestamp: new Date().toISOString(),
      progress: {
        found: mockProgress.guarantorsFound,
        required: mockProgress.guarantorsRequired,
        percentage: Math.round((mockProgress.guarantorsFound / mockProgress.guarantorsRequired) * 100),
        remaining: mockProgress.guarantorsRequired - mockProgress.guarantorsFound
      },
      guarantors: mockProgress.guarantors
    });
  }

  /**
   * Notify loan owner of guarantor activity
   */
  notifyGuarantorAction(loanId, action) {
    const message = {
      type: 'guarantor_action',
      loanId,
      timestamp: new Date().toISOString(),
      action, // 'viewed', 'approved', 'declined'
      guarantor: action.guarantor || null
    };

    // Get subscribers for this loan
    if (this.loanRooms.has(loanId)) {
      this.loanRooms.get(loanId).forEach(userId => {
        this.sendToUser(userId, message);
      });
    }
  }

  /**
   * Broadcast notification to user
   */
  sendNotification(userId, notification) {
    this.sendToUser(userId, {
      type: 'notification',
      timestamp: new Date().toISOString(),
      notification
    });
  }

  /**
   * Get connection statistics
   */
  getStats() {
    return {
      totalConnections: this.wss ? this.wss.clients.size : 0,
      authenticatedUsers: this.clients.size,
      activeLoanRooms: this.loanRooms.size,
      clientsPerUser: Array.from(this.clients.entries()).map(([userId, sockets]) => ({
        userId,
        connections: sockets.size
      }))
    };
  }

  /**
   * Cleanup and close
   */
  shutdown() {
    this.stopHeartbeat();
    if (this.wss) {
      this.wss.clients.forEach(ws => {
        ws.close();
      });
      this.wss.close();
    }
    this.clients.clear();
    this.loanRooms.clear();
    logger.info('WebSocket server shutdown complete');
  }
}

// Export singleton instance
module.exports = new WebSocketService();
