/**
 * Validation for website contact-form enquiries.
 *
 * Kept dependency-free in `lib/` so it can be unit tested without booting
 * Express or Supabase — the same reason `activationGate.js` and
 * `loanPolicy.js` live here. The public `/api/contact` ingest endpoint is
 * unauthenticated, so this is the only thing between an anonymous request and a
 * database row; it validates *and* length-caps every field, and never trusts
 * the client's own validation (the site validates too, but for fast feedback
 * only).
 */

const MAX = {
  name: 120,
  email: 200,
  phone: 40,
  topic: 120,
  message: 5000,
  honeypot: 100,
};

/**
 * Topics the contact form may submit.
 *
 * This list is mirrored by `TOPICS` in the website's `api/contact.js`, whose
 * `tools/check_topics.py` fails the build if the two drift. Keeping the copy
 * here as well means a topic renamed on the site is rejected here rather than
 * silently stored as an unknown value — but the two must be changed together.
 */
const TOPICS = new Set([
  'Join by Direct Deposit (pay myself)',
  'Join through my employer (Salary Deduction)',
  'Employer / institution partnership',
  'Existing account or contribution query',
  'Loan enquiry',
  'Media or other enquiry',
]);

/** Strip control characters so nothing can be smuggled into mail headers. */
function clean(value, limit) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, limit);
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const PHONE_RE = /^[+()\d\s-]{7,20}$/;

/**
 * Validate a submitted enquiry.
 *
 * @param {object} body raw request body
 * @returns {{ok: boolean, errors: object, value: object, honeypot: boolean}}
 *   `value` is the cleaned payload (only meaningful when `ok`). `honeypot` is
 *   true when the hidden trap field was filled — callers should report success
 *   to the bot and store nothing.
 */
function validateContactSubmission(body) {
  const raw = body && typeof body === 'object' ? body : {};

  const name = clean(raw.name, MAX.name);
  const email = clean(raw.email, MAX.email);
  const phone = clean(raw.phone, MAX.phone);
  const topic = clean(raw.topic, MAX.topic);
  const message = clean(raw.message, MAX.message);
  const honeypot = clean(raw.website, MAX.honeypot);

  const errors = {};
  if (name.length < 2) errors.name = 'Please enter your full name.';
  if (!EMAIL_RE.test(email)) errors.email = 'Enter a valid email address.';
  if (phone && !PHONE_RE.test(phone)) errors.phone = 'Enter a valid phone number.';
  if (!TOPICS.has(topic)) errors.topic = 'Please choose what your message is about.';
  if (message.length < 10) errors.message = 'Please add a little more detail.';

  return {
    ok: Object.keys(errors).length === 0,
    errors,
    honeypot: honeypot.length > 0,
    value: { name, email, phone: phone || null, topic, message },
  };
}

/** Human-facing reference the enquirer is shown, e.g. `CM-3F9K2A`. */
function newContactReference(now = Date.now()) {
  return `CM-${now.toString(36).toUpperCase()}`;
}

module.exports = {
  MAX,
  TOPICS,
  clean,
  validateContactSubmission,
  newContactReference,
};
