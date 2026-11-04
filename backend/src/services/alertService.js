/**
 * Alert Service
 * 
 * Handles sending alerts for critical risks and system errors.
 * Supports Email and Webhook notifications.
 */

const nodemailer = require('nodemailer');
const https = require('https');
const http = require('http');
const logger = require('../utils/logger');

// Configuration
const ALERT_EMAIL_RECIPIENTS = process.env.ALERT_EMAIL_RECIPIENTS || '';
const ALERT_WEBHOOK_URL = process.env.ALERT_WEBHOOK_URL || '';
const APP_NAME = 'Coopvest Africa';

// Minimum gap between system-error alerts. Overridable so a test can drive the
// throttle without waiting.
const SYSTEM_ALERT_MIN_INTERVAL_MS = Number(process.env.SYSTEM_ALERT_MIN_INTERVAL_MS) || 5 * 60 * 1000;

class AlertService {
  constructor() {
    this.transporter = null;
    // Throttle state for sendSystemErrorAlert (see below).
    this._lastSystemAlertAt = 0;
    this._suppressedSystemAlerts = 0;
  }

  /**
   * Get or create email transporter
   */
  async getTransporter() {
    if (!this.transporter) {
      this.transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS
        }
      });
    }
    return this.transporter;
  }

  /**
   * Send a critical risk alert
   * @param {Object} log - The AuditLog entry
   */
  async sendCriticalAlert(log) {
    const { action, details, userId, riskLevel, auditId } = log;
    
    if (riskLevel !== 'critical' && riskLevel !== 'high') {
      return;
    }

    const alertData = {
      title: `🚨 CRITICAL ALERT: ${action}`,
      message: details,
      auditId,
      userId: userId || 'N/A',
      riskLevel: riskLevel.toUpperCase(),
      timestamp: new Date().toISOString(),
      metadata: log.metadata || {}
    };

    logger.warn(`Sending critical alert for audit: ${auditId}`, { action, riskLevel });

    // Send via multiple channels
    const results = await Promise.allSettled([
      this.sendEmailAlert(alertData),
      this.sendWebhookAlert(alertData)
    ]);

    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        logger.error(`Alert channel ${index === 0 ? 'Email' : 'Webhook'} failed:`, result.reason);
      }
    });
  }

  /**
   * Send alert via Email
   */
  async sendEmailAlert(data) {
    if (!ALERT_EMAIL_RECIPIENTS) return;

    try {
      const transporter = await this.getTransporter();
      const recipients = ALERT_EMAIL_RECIPIENTS.split(',').map(e => e.trim());

      const html = `
        <div style="font-family: sans-serif; max-width: 600px; border: 2px solid #d32f2f; border-radius: 8px; overflow: hidden;">
          <div style="background-color: #d32f2f; color: white; padding: 20px; text-align: center;">
            <h2 style="margin: 0;">${data.title}</h2>
          </div>
          <div style="padding: 20px; background-color: #fff;">
            <p><strong>Risk Level:</strong> <span style="color: #d32f2f; font-weight: bold;">${data.riskLevel}</span></p>
            <p><strong>Audit ID:</strong> ${data.auditId}</p>
            <p><strong>User ID:</strong> ${data.userId}</p>
            <p><strong>Time:</strong> ${data.timestamp}</p>
            <hr style="border: 0; border-top: 1px solid #eee;">
            <p><strong>Details:</strong></p>
            <div style="background-color: #f5f5f5; padding: 15px; border-radius: 4px; font-family: monospace;">
              ${data.message}
            </div>
          </div>
          <div style="background-color: #f9f9f9; padding: 15px; text-align: center; font-size: 12px; color: #666;">
            This is an automated security alert from ${APP_NAME}.
          </div>
        </div>
      `;

      await transporter.sendMail({
        from: `"Security Alerts" <${process.env.SMTP_FROM || 'alerts@coopvest.com'}>`,
        to: recipients,
        subject: `[SECURITY] ${data.riskLevel}: ${data.title}`,
        html
      });

      logger.info(`Email alert sent to ${recipients.length} recipients`);
    } catch (error) {
      throw new Error(`Email alert failed: ${error.message}`);
    }
  }

  /**
   * Alert operators that the server itself is failing.
   *
   * Distinct from sendCriticalAlert, which reports a risky *user action* found
   * in the audit log. This reports the process failing, and it exists because
   * an error that reaches errorHandler was previously written to the log and to
   * audit_logs and then seen by nobody — a failing endpoint stayed invisible
   * until a member reported it.
   *
   * Uses the webhook channel (Slack/Discord/custom) rather than email: it is
   * already generic, and it does not depend on SMTP being configured.
   *
   * Never throws. Alerting sits on the error path, so a failure to alert must
   * not be able to turn one error into two.
   */
  async sendSystemErrorAlert({ title, message, context }) {
    if (!ALERT_WEBHOOK_URL) return;

    // A single failing dependency makes every request 5xx at once, so without a
    // floor this sends thousands of identical messages and the channel gets
    // muted precisely when it is needed. Send one per window and report how many
    // were folded into it.
    const now = Date.now();
    if (now - this._lastSystemAlertAt < SYSTEM_ALERT_MIN_INTERVAL_MS) {
      this._suppressedSystemAlerts += 1;
      return;
    }
    const suppressed = this._suppressedSystemAlerts;
    this._lastSystemAlertAt = now;
    this._suppressedSystemAlerts = 0;

    const body = suppressed > 0
      ? `${message}\n\n(${suppressed} further error(s) suppressed in the last ${Math.round(SYSTEM_ALERT_MIN_INTERVAL_MS / 1000)}s)`
      : message;

    try {
      await this.sendWebhookAlert({
        title: title || 'Server error',
        riskLevel: 'HIGH',
        userId: (context && context.userId) || 'N/A',
        message: body,
        auditId: 'N/A',
        timestamp: new Date().toISOString(),
        metadata: context || {},
      });
    } catch (error) {
      logger.warn(`System error alert failed: ${error.message}`);
    }
  }

  /**
   * Send alert via Webhook (e.g., Slack, Discord, or custom endpoint)
   */
  async sendWebhookAlert(data) {
    if (!ALERT_WEBHOOK_URL) return;

    return new Promise((resolve, reject) => {
      const url = new URL(ALERT_WEBHOOK_URL);
      const transport = url.protocol === 'https:' ? https : http;
      
      const payload = JSON.stringify({
        text: `*${data.title}*\n*Risk:* ${data.riskLevel}\n*User:* ${data.userId}\n*Details:* ${data.message}\n*Audit ID:* ${data.auditId}`,
        ...data
      });

      const options = {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname + url.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload)
        },
        timeout: 5000
      };

      const req = transport.request(options, (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          logger.info('Webhook alert sent successfully');
          resolve();
        } else {
          reject(new Error(`Webhook returned status ${res.statusCode}`));
        }
      });

      req.on('error', (err) => reject(err));
      req.on('timeout', () => {
        req.destroy();
        reject(new Error('Webhook request timed out'));
      });

      req.write(payload);
      req.end();
    });
  }
}

module.exports = new AlertService();
