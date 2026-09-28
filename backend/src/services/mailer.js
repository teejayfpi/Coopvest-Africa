/**
 * Outbound email for admin replies and similar.
 *
 * Transport is chosen by configuration, in this order:
 *
 *   1. Resend HTTP API (RESEND_API_KEY) — plain HTTPS, no dependency.
 *   2. SMTP (SMTP_HOST + SMTP_USER + SMTP_PASS) — nodemailer.
 *
 * Resend is preferred because the Render web services run on the free plan,
 * which blocks outbound SMTP (25/465/587): an SMTP send there fails with
 * "Connection timeout" no matter how correct the credentials are. Resend goes
 * over 443, which is not blocked.
 *
 * `notifyService.sendEmail` is not used here: it only logs — it checks for
 * EMAIL_PROVIDER/EMAIL_API_KEY, then returns `{status:'sent'}` without sending
 * anything. An admin reply to a website enquiry must actually reach the
 * enquirer, so it needs a transport that really sends.
 *
 * When no transport is configured, `send` returns
 * `{sent:false, reason:'not_configured'}` so callers can tell the admin the
 * reply was recorded but not emailed, instead of claiming success.
 */

const logger = require('../utils/logger');

let _transporter = null;

function hasResend() {
  return Boolean(process.env.RESEND_API_KEY);
}

function hasSmtp() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

function isConfigured() {
  return hasResend() || hasSmtp();
}

function fromAddress() {
  return (
    process.env.CONTACT_FROM ||
    process.env.SMTP_FROM ||
    (hasSmtp() ? `Coopvest Africa <${process.env.SMTP_USER}>` : 'Coopvest Africa <onboarding@resend.dev>')
  );
}

async function sendViaResend({ to, subject, text, html, replyTo }) {
  const base = process.env.RESEND_BASE_URL || 'https://api.resend.com';
  const response = await fetch(`${base}/emails`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: fromAddress(),
      to: [to],
      reply_to: replyTo,
      subject,
      text,
      html,
    }),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`resend ${response.status} ${detail.slice(0, 300)}`);
  }
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
    logger.info(`mailer.send skipped (no mail transport configured): to=${to} subject="${subject}"`);
    return { sent: false, reason: 'not_configured' };
  }
  try {
    const body = {
      to,
      subject,
      text,
      replyTo,
      html: html || `<pre style="font-family:sans-serif;white-space:pre-wrap">${escapeHtml(text || '')}</pre>`,
    };
    if (hasResend()) {
      await sendViaResend(body);
      logger.info(`mailer.send sent via Resend: to=${to} subject="${subject}"`);
    } else {
      await getTransporter().sendMail({ from: fromAddress(), ...body });
      logger.info(`mailer.send sent via SMTP: to=${to} subject="${subject}"`);
    }
    return { sent: true };
  } catch (err) {
    logger.warn('mailer.send error:', err.message);
    return { sent: false, reason: 'failed', error: err.message };
  }
}

module.exports = { send, isConfigured, hasResend, hasSmtp, fromAddress, escapeHtml };
