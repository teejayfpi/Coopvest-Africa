/**
 * Public website contact-form ingest — POST /api/contact
 *
 * The marketing site (`coopvest-website`) posts every enquiry here. The enquiry
 * is stored in `contact_messages` so it appears in the admin dashboard's
 * Website Enquiries page, where an admin can read and reply to it.
 *
 * Why this endpoint exists rather than the site emailing directly: email has no
 * queue. An enquiry that was not emailed (no provider configured — the live
 * site answered 503) was lost with no record, and even a delivered one was only
 * ever a message in a shared inbox that nothing tracked. Storing first means an
 * admin sees every enquiry and can answer it.
 *
 * Security: the endpoint is unauthenticated by necessity, so it is deliberately
 * defensive — it validates and length-caps every field (`lib/contactMessages`),
 * discards a honeypot, rate-limits per IP, and never echoes internal errors.
 */

const express = require('express');
const rateLimit = require('express-rate-limit');
const crypto = require('crypto');

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const {
  validateContactSubmission,
  newContactReference,
} = require('../lib/contactMessages');

const router = express.Router();

/**
 * Enquiries per IP. Tighter than the global limiter because this path is public
 * and every accepted request writes a row and may send an email.
 */
const contactLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: parseInt(process.env.CONTACT_RATE_LIMIT_MAX) || 10,
  message: {
    success: false,
    error: 'too_many_requests',
    message: 'Too many messages. Please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) =>
    req.headers['x-forwarded-for']?.split(',')[0].trim() ||
    req.ip ||
    req.connection?.remoteAddress ||
    'unknown',
});

function clientIp(req) {
  return (
    req.headers['x-forwarded-for']?.split(',')[0].trim() ||
    req.ip ||
    req.connection?.remoteAddress ||
    null
  );
}

/**
 * Optional shared secret.
 *
 * When `CONTACT_INGEST_TOKEN` is set, callers must present the same value in
 * `X-Contact-Token`. It is optional because the endpoint has to serve the
 * form's own same-origin request, which cannot carry a secret the browser
 * would expose; leave it unset for that. Set it when the site proxies through
 * its own function (needing the token then does not help an attacker who can
 * already reach this endpoint directly) or when fronting the API with a WAF
 * that injects the header. Compared in constant time.
 */
function ingestTokenValid(req) {
  const expected = process.env.CONTACT_INGEST_TOKEN;
  if (!expected) return true;
  const provided = String(req.headers['x-contact-token'] || '');
  if (provided.length !== expected.length) return false;
  try {
    return crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(expected));
  } catch {
    return false;
  }
}

/**
 * Best-effort heads-up email so an admin notices a new enquiry without watching
 * the dashboard. Never fatal: the row is already stored, and the dashboard is
 * the system of record. Skipped silently when SMTP is not configured.
 */
async function notifyAdmins({ reference, enquiry }) {
  const recipients = (process.env.CONTACT_NOTIFY_TO || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (!recipients.length || !process.env.SMTP_HOST || !process.env.SMTP_USER) return;

  try {
    const nodemailer = require('nodemailer');
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '465', 10),
      secure: process.env.SMTP_SECURE ? process.env.SMTP_SECURE === 'true' : true,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
    await transporter.sendMail({
      from: process.env.CONTACT_FROM || process.env.SMTP_USER,
      to: recipients,
      replyTo: enquiry.email,
      subject: `[Website] ${enquiry.topic}: ${enquiry.name} (${reference})`,
      text: [
        'New enquiry from the Coopvest Africa website',
        `Reference: ${reference}`,
        '',
        `Name:    ${enquiry.name}`,
        `Email:   ${enquiry.email}`,
        enquiry.phone && `Phone:   ${enquiry.phone}`,
        `Topic:   ${enquiry.topic}`,
        '',
        enquiry.message,
      ]
        .filter(Boolean)
        .join('\n'),
    });
  } catch (err) {
    logger.warn('contact: admin notification email failed:', err.message);
  }
}

router.post('/', contactLimiter, async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');

  if (!ingestTokenValid(req)) {
    return res.status(403).json({ success: false, error: 'forbidden' });
  }

  const result = validateContactSubmission(req.body);

  // A hidden field real users never fill. Report success so bots do not learn
  // they were filtered, but store nothing.
  if (result.honeypot) {
    return res.status(200).json({ success: true });
  }

  if (!result.ok) {
    return res.status(400).json({ success: false, error: 'validation_failed', errors: result.errors });
  }

  const reference = newContactReference();
  const { name, email, phone, topic, message } = result.value;
  const userAgent = String(req.headers['user-agent'] || '').slice(0, 500) || null;

  const { error } = await supabase.from('contact_messages').insert({
    reference,
    name,
    email,
    phone,
    topic,
    message,
    source: 'website',
    status: 'new',
    ip_address: clientIp(req),
    user_agent: userAgent,
    metadata: { origin: req.headers.origin || null },
  });

  if (error) {
    logger.error('contact: failed to store enquiry:', error.message);
    return res.status(502).json({
      success: false,
      error: 'delivery_failed',
      message: 'We could not save your message just now. Please email coopvestafrica@gmail.com directly.',
    });
  }

  await notifyAdmins({ reference, enquiry: { name, email, phone, topic, message } });

  return res.status(200).json({ success: true, reference });
});

module.exports = router;
