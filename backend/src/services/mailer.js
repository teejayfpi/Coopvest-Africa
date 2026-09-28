/**
 * Outbound email via SMTP.
 *
 * Why this exists: `notifyService.sendEmail` only logs — it checks for
 * EMAIL_PROVIDER/EMAIL_API_KEY, then returns `{status:'sent'}` without sending
 * anything. That is fine for the transactional notifications nothing depends
 * on, but an admin reply to a website enquiry must actually reach the enquirer,
 * so it needs a transport that really sends.
 *
 * The configuration mirrors `alertService.js` and `render.yaml`: SMTP_HOST,
 * SMTP_PORT (default 465), SMTP_SECURE (default true on 465) and SMTP_USER /
 * SMTP_PASS (a Gmail app password). When SMTP is not configured, `send` returns
 * `{sent:false, reason:'not_configured'}` so callers can tell the admin the
 * reply was recorded but not emailed, instead of claiming success.
 */

const logger = require('../utils/logger');

let _transporter = null;

function isConfigured() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

function getTransporter() {
  if (_transporter) return _transporter;
  const nodemailer = require('nodemailer');
  const port = parseInt(process.env.SMTP_PORT || '465', 10);
  _transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    // 465 is implicit TLS; 587 upgrades with STARTTLS.
    secure: process.env.SMTP_SECURE ? process.env.SMTP_SECURE === 'true' : port === 465,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  return _transporter;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Send an email.
 *
 * @returns {Promise<{sent: boolean, reason?: string, error?: string}>}
 *   Never throws — a transport failure must not roll back the database write
 *   that recorded the reply, so the caller decides how to report it.
 */
async function send({ to, subject, text, html, replyTo }) {
  if (!isConfigured()) {
    logger.info(`mailer.send skipped (SMTP not configured): to=${to} subject="${subject}"`);
    return { sent: false, reason: 'not_configured' };
  }
  try {
    const from =
      process.env.CONTACT_FROM ||
      process.env.SMTP_FROM ||
      `Coopvest Africa <${process.env.SMTP_USER}>`;
    await getTransporter().sendMail({
      from,
      to,
      replyTo,
      subject,
      text,
      html: html || `<pre style="font-family:sans-serif;white-space:pre-wrap">${escapeHtml(text || '')}</pre>`,
    });
    logger.info(`mailer.send sent via SMTP: to=${to} subject="${subject}"`);
    return { sent: true };
  } catch (err) {
    logger.warn('mailer.send error:', err.message);
    return { sent: false, reason: 'failed', error: err.message };
  }
}

module.exports = { send, isConfigured, escapeHtml };
