/**
 * WebSocket Service
 *
 * Real-time communication for loan progress updates and notifications.
 * Authentication uses Supabase JWT verification (getUser) instead of custom JWT.
 */

const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');
const supabase = require('../config/supabase');

class WebSocketService {
  constructor() {
    this.wss = null;
    this.clients = new Map(); // userId -> Set of WebSocket connections
    this.loanRooms = new Map(); // loanId -> Set of userIds subscribed
    this.heartbeatInterval = null;
  }

  /**
   * Initialize WebSocket server
   */
  initialize(server) {
    this.wss = new WebSocket.Server({
      server,
      path: '/ws',
    });

    logger.info('WebSocket server initializing...');

    this.wss.on('connection', (ws, req) => {
      this.handleConnection(ws, req);
    });

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

    ws.on('pong', () => {
      ws.isAlive = true;
    });

    ws.on('message', (data) => {
      this.handleMessage(ws, data);
    });

    ws.on('close', () => {
      this.handleDisconnect(ws);
    });

    ws.on('error', (error) => {
      logger.error(`WebSocket error for ${connectionId}:`, error);
      this.handleDisconnect(ws);
    });

    this.sendToClient(ws, {
      type: 'connected',
      connectionId,
      message: 'Connected to Coopvest WebSocket',
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
            message: `Unknown message type: ${message.type}`,
          });
      }
    } catch (error) {
      logger.error('Error parsing WebSocket message:', error);
      this.sendToClient(ws, {
        type: 'error',
        message: 'Invalid message format',
      });
    }
  }

  /**
   * Handle authentication message — verifies Supabase JWT via getUser().
   */
  async handleAuthenticate(ws, message) {
    try {
      const { token } = message;

      if (!token) {
        this.sendToClient(ws, {
          type: 'error',
          message: 'Authentication token required',
        });
        return;
      }

      // Verify the Supabase access token
      const {
        data: { user },
        error,
      } = await supabase.auth.getUser(token);

      if (error || !user) {
        this.sendToClient(ws, {
          type: 'error',
          message: 'Authentication failed',
        });
        return;
      }

      ws.userId = user.id;

      if (!this.clients.has(ws.userId)) {
        this.clients.set(ws.userId, new Set());
      }
      this.clients.get(ws.userId).add(ws);

      logger.info(`User ${ws.userId} authenticated via WebSocket`);

      this.sendToClient(ws, {
        type: 'authenticated',
        userId: ws.userId,
        message: 'Successfully authenticated',
      });
    } catch (error) {
      logger.error('WebSocket authentication error:', error);
      this.sendToClient(ws, {
        type: 'error',
        message: 'Authentication failed',
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
        message: 'Please authenticate first',
      });
      return;
    }

    if (!loanId) {
      this.sendToClient(ws, { type: 'error', message: 'Loan ID required' });
      return;
    }

    if (!this.loanRooms.has(loanId)) {
      this.loanRooms.set(loanId, new Set());
    }
    this.loanRooms.get(loanId).add(ws.userId);
    ws.subscribedLoans.add(loanId);

    logger.info(`User ${ws.userId} subscribed to loan ${loanId}`);

    this.sendToClient(ws, {
      type: 'subscribed',
      loanId,
      message: `Subscribed to loan ${loanId}`,
    });

    this.sendLoanProgress(loanId, ws.userId);
  }

  /**
   * Handle loan unsubscription
   */
  handleUnsubscribeLoan(ws, message) {
    const { loanId } = message;

    if (!loanId) {
      this.sendToClient(ws, { type: 'error', message: 'Loan ID required' });
      return;
    }

    if (this.loanRooms.has(loanId)) {
      this.loanRooms.get(loanId).delete(ws.userId);
    }
    ws.subscribedLoans.delete(loanId);

    logger.info(`User ${ws.userId} unsubscribed from loan ${loanId}`);

    this.sendToClient(ws, {
      type: 'unsubscribed',
      loanId,
      message: `Unsubscribed from loan ${loanId}`,
    });
  }

  /**
   * Handle client disconnect
   */
  handleDisconnect(ws) {
    if (ws.userId && this.clients.has(ws.userId)) {
      this.clients.get(ws.userId).delete(ws);
      if (this.clients.get(ws.userId).size === 0) {
        this.clients.delete(ws.userId);
      }
    }

    ws.subscribedLoans.forEach((loanId) => {
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
      this.wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
          return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, 30000);
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
      this.clients.get(userId).forEach((ws) => {
        this.sendToClient(ws, data);
      });
    }
  }

  /**
   * Broadcast loan progress to all subscribers of a loan
   */
  broadcastLoanProgress(loanId, progress) {
    if (!this.loanRooms.has(loanId)) return;

    const message = {
      type: 'loan_progress',
      loanId,
      timestamp: new Date().toISOString(),
      progress: {
        guarantorsFound: progress.guarantorsFound,
        guarantorsRequired: progress.guarantorsRequired,
        percentage: Math.round(
          (progress.guarantorsFound / progress.guarantorsRequired) * 100
        ),
        remaining: progress.guarantorsRequired - progress.guarantorsFound,
      },
      guarantors: progress.guarantors || [],
    };

    const subscribers = this.loanRooms.get(loanId);
    subscribers.forEach((userId) => {
      this.sendToUser(userId, message);
    });

    logger.debug(
      `Broadcasted progress update for loan ${loanId} to ${subscribers.size} subscribers`
    );
  }

  /**
   * Send current loan progress to a specific user
   */
  async sendLoanProgress(loanId, userId) {
    try {
      // 1. Fetch QR code details for the loan
      const { data: qrData, error: qrError } = await supabase
        .from('loan_qrs')
        .select('guarantors_required, guarantors_found')
        .eq('loan_id', loanId)
        .maybeSingle();

      if (qrError) {
        logger.error(`Error fetching QR data for loan ${loanId}:`, qrError);
      }

      // 2. Fetch loan guarantors and join with profile details
      const { data: guarantors, error: gError } = await supabase
        .from('loan_guarantors')
        .select(`
          status,
          consented_at,
          created_at,
          profiles (
            name,
            phone
          )
        `)
        .eq('loan_id', loanId);

      if (gError) {
        logger.error(`Error fetching guarantors for loan ${loanId}:`, gError);
      }

      // 3. Structure the progress data
      const guarantorsRequired = qrData?.guarantors_required || 3;
      
      const consentedGuarantors = guarantors 
        ? guarantors.filter(g => g.status === 'consented' || g.status === 'approved') 
        : [];
      const guarantorsFound = consentedGuarantors.length;

      const formattedGuarantors = (guarantors || []).map(g => {
        const profile = g.profiles || {};
        let maskedPhone = profile.phone || '';
        if (maskedPhone.length > 7) {
          maskedPhone = maskedPhone.slice(0, 7) + '****' + maskedPhone.slice(-4);
        }
        return {
          name: profile.name || 'Unknown',
          phone: maskedPhone,
          status: g.status === 'consented' ? 'approved' : g.status, // Map 'consented' to 'approved' for frontend compatibility
          timestamp: g.consented_at || g.created_at || new Date().toISOString(),
        };
      });

      this.sendToUser(userId, {
        type: 'loan_progress',
        loanId,
        timestamp: new Date().toISOString(),
        progress: {
          found: guarantorsFound,
          required: guarantorsRequired,
          percentage: Math.round((guarantorsFound / guarantorsRequired) * 100),
          remaining: Math.max(0, guarantorsRequired - guarantorsFound),
        },
        guarantors: formattedGuarantors,
      });
    } catch (error) {
      logger.error(`Failed to send real-time loan progress for loan ${loanId} to user ${userId}:`, error);
      // Fallback to sending basic error or empty status if DB fails
      this.sendToUser(userId, {
        type: 'error',
        message: 'Failed to retrieve real-time loan progress',
      });
    }
  }

  /**
   * Notify loan owner of guarantor activity
   */
  notifyGuarantorAction(loanId, action) {
    const message = {
      type: 'guarantor_action',
      loanId,
      timestamp: new Date().toISOString(),
      action,
      guarantor: action.guarantor || null,
    };

    if (this.loanRooms.has(loanId)) {
      this.loanRooms.get(loanId).forEach((userId) => {
        this.sendToUser(userId, message);
      });
    }
  }

  /**
   * Send notification to a user
   */
  sendNotification(userId, notification) {
    this.sendToUser(userId, {
      type: 'notification',
      timestamp: new Date().toISOString(),
      notification,
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
      clientsPerUser: Array.from(this.clients.entries()).map(
        ([userId, sockets]) => ({
          userId,
          connections: sockets.size,
        })
      ),
    };
  }

  /**
   * Cleanup and close
   */
  shutdown() {
    this.stopHeartbeat();
    if (this.wss) {
      this.wss.clients.forEach((ws) => {
        ws.close();
      });
      this.wss.close();
    }
    this.clients.clear();
    this.loanRooms.clear();
    logger.info('WebSocket server shutdown complete');
  }
}

module.exports = new WebSocketService();
