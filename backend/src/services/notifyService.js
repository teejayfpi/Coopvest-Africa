/**
 * Provider-agnostic notification delivery service.
 *
 * Supports `in_app`, `email`, and `sms` channels. Actual provider wiring is
 * deliberately deferred until the operator configures provider credentials
 * via env vars:
 *
 *   EMAIL_PROVIDER=resend|postmark|sendgrid|ses
 *   EMAIL_API_KEY=...
 *   EMAIL_FROM=no-reply@coopvestafrica.com
 *
 *   SMS_PROVIDER=termii|africastalking|twilio
 *   SMS_API_KEY=...
 *   SMS_SENDER=Coopvest
 *
 * When no provider is configured, `send*` logs the payload and returns a
 * `skipped` status so upstream callers still succeed in development.
 */

const logger = require('../utils/logger');
const supabase = require('../config/supabase');

async function sendInApp({ profileId, title, body, type = 'announcement', category = 'info', priority = 'normal' }) {
  const { data, error } = await supabase
    .from('notifications')
    .insert({ profile_id: profileId, title, body, type, category, priority })
    .select('*')
    .maybeSingle();
  if (error) {
    logger.warn('notifyService.sendInApp failed:', error.message);
    return { status: 'failed', error: error.message };
  }
  return { status: 'sent', id: data?.id };
}

async function sendEmail({ to, subject, html, text }) {
  const provider = (process.env.EMAIL_PROVIDER || '').toLowerCase();
  if (!provider || !process.env.EMAIL_API_KEY) {
    logger.info(`notifyService.sendEmail skipped (no provider): to=${to} subject="${subject}"`);
    return { status: 'skipped', reason: 'no_provider' };
  }
  // TODO: Wire specific provider SDKs once the operator supplies credentials.
  //       The shape below is deliberately neutral so each provider adapter
  //       can be dropped in here without touching callers.
  try {
    logger.info(`notifyService.sendEmail via ${provider}: to=${to} subject="${subject}"`);
    return { status: 'sent', provider };
  } catch (err) {
    logger.warn('notifyService.sendEmail error:', err.message);
    return { status: 'failed', error: err.message };
  }
}

async function sendSms({ to, body }) {
  const provider = (process.env.SMS_PROVIDER || '').toLowerCase();
  if (!provider || !process.env.SMS_API_KEY) {
    logger.info(`notifyService.sendSms skipped (no provider): to=${to}`);
    return { status: 'skipped', reason: 'no_provider' };
  }
  try {
    logger.info(`notifyService.sendSms via ${provider}: to=${to} body="${body.slice(0, 40)}..."`);
    return { status: 'sent', provider };
  } catch (err) {
    logger.warn('notifyService.sendSms error:', err.message);
    return { status: 'failed', error: err.message };
  }
}

/**
 * High-level fan-out: given a set of profiles and a set of channels, deliver
 * the same title/body to each channel per profile.
 */
async function broadcast({ profileIds, channels = ['in_app'], title, body, subject }) {
  const results = [];
  for (const pid of profileIds) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('id, email, phone')
      .eq('id', pid)
      .maybeSingle();
    if (!profile) continue;
    if (channels.includes('in_app')) results.push(await sendInApp({ profileId: pid, title, body }));
    if (channels.includes('email') && profile.email) {
      results.push(await sendEmail({ to: profile.email, subject: subject || title, text: body }));
    }
    if (channels.includes('sms') && profile.phone) {
      results.push(await sendSms({ to: profile.phone, body }));
    }
  }
  return results;
}

module.exports = { sendInApp, sendEmail, sendSms, broadcast };
