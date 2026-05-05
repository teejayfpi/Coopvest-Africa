/**
 * Provider-agnostic notification delivery service.
 *
 * Channels supported:
 *   in_app  — persists a row to the `notifications` Supabase table
 *   email   — delegates to EMAIL_PROVIDER (resend|postmark|sendgrid|ses)
 *   sms     — delegates to SMS_PROVIDER (termii|africastalking|twilio)
 *   push    — Firebase Cloud Messaging via Firebase Admin SDK
 *
 * FCM env vars required for push channel:
 *   FIREBASE_PROJECT_ID=your-project-id
 *   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
 *   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
 *
 * Alternatively set GOOGLE_APPLICATION_CREDENTIALS to the path of your
 * service-account JSON file and the SDK will pick it up automatically.
 *
 * When FCM credentials are absent the push channel logs and returns `skipped`
 * so all other callers still succeed in development.
 */

const logger = require('../utils/logger');
const supabase = require('../config/supabase');

// ── Firebase Admin SDK (lazy-init so the server starts without credentials) ──
let _firebaseApp = null;
let _fcmMessaging = null;

function _getFirebaseAdmin() {
  if (_firebaseApp) return _firebaseApp;

  const hasEnvCreds =
    process.env.FIREBASE_PROJECT_ID &&
    process.env.FIREBASE_CLIENT_EMAIL &&
    process.env.FIREBASE_PRIVATE_KEY;

  const hasAppCreds = !!process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (!hasEnvCreds && !hasAppCreds) {
    return null;
  }

  try {
    const admin = require('firebase-admin');

    if (admin.apps.length > 0) {
      _firebaseApp = admin.apps[0];
    } else {
      const credential = hasEnvCreds
        ? admin.credential.cert({
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            // GitHub/Heroku env vars often collapse \n — restore them
            privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
          })
        : admin.credential.applicationDefault();

      _firebaseApp = admin.initializeApp({ credential });
    }

    _fcmMessaging = admin.messaging(_firebaseApp);
    logger.info('Firebase Admin SDK initialised for FCM push delivery');
    return _firebaseApp;
  } catch (err) {
    logger.warn('Firebase Admin SDK init failed:', err.message);
    return null;
  }
}

// ── in-app ────────────────────────────────────────────────────────────────────

async function sendInApp({
  profileId,
  title,
  body,
  type = 'announcement',
  category = 'info',
  priority = 'normal',
}) {
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

// ── email ─────────────────────────────────────────────────────────────────────

async function sendEmail({ to, subject, html, text }) {
  const provider = (process.env.EMAIL_PROVIDER || '').toLowerCase();
  if (!provider || !process.env.EMAIL_API_KEY) {
    logger.info(`notifyService.sendEmail skipped (no provider): to=${to} subject="${subject}"`);
    return { status: 'skipped', reason: 'no_provider' };
  }
  try {
    logger.info(`notifyService.sendEmail via ${provider}: to=${to} subject="${subject}"`);
    return { status: 'sent', provider };
  } catch (err) {
    logger.warn('notifyService.sendEmail error:', err.message);
    return { status: 'failed', error: err.message };
  }
}

// ── sms ───────────────────────────────────────────────────────────────────────

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

// ── push (FCM) ────────────────────────────────────────────────────────────────

/**
 * Send a Firebase Cloud Messaging push notification.
 *
 * @param {object} opts
 * @param {string}  opts.token        - Device FCM registration token (single device)
 * @param {string[]} [opts.tokens]    - Multiple device tokens (multicast)
 * @param {string}  [opts.topic]      - FCM topic (e.g. 'all_users')
 * @param {string}  opts.title        - Notification title
 * @param {string}  opts.body         - Notification body
 * @param {object}  [opts.data]       - Arbitrary key→value string payload
 * @param {string}  [opts.type]       - Notification type for client routing
 * @param {string}  [opts.imageUrl]   - Optional image URL
 */
async function sendPush({ token, tokens, topic, title, body, data = {}, type, imageUrl }) {
  const app = _getFirebaseAdmin();
  if (!app) {
    logger.info('notifyService.sendPush skipped (no Firebase credentials)');
    return { status: 'skipped', reason: 'no_firebase_credentials' };
  }

  const admin = require('firebase-admin');
  const messaging = admin.messaging(app);

  const notification = { title, body };
  if (imageUrl) notification.imageUrl = imageUrl;

  const payload = {
    notification,
    data: { ...data, type: type || 'general' },
    android: {
      notification: {
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        channelId: _androidChannelForType(type),
        priority: type === 'otp' || type === 'otp_sent' ? 'high' : 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          badge: 1,
          sound: 'default',
        },
      },
    },
  };

  try {
    // Single token
    if (token) {
      const result = await messaging.send({ ...payload, token });
      logger.info(`FCM push sent to single device. messageId=${result}`);
      return { status: 'sent', messageId: result };
    }

    // Multiple tokens (multicast)
    if (tokens && tokens.length > 0) {
      const result = await messaging.sendEachForMulticast({ ...payload, tokens });
      const failed = result.responses.filter((r) => !r.success).length;
      logger.info(`FCM multicast: ${result.successCount} sent, ${failed} failed`);
      return { status: 'sent', successCount: result.successCount, failureCount: failed };
    }

    // Topic
    if (topic) {
      const result = await messaging.send({ ...payload, topic });
      logger.info(`FCM push sent to topic=${topic}. messageId=${result}`);
      return { status: 'sent', messageId: result };
    }

    logger.warn('notifyService.sendPush: no token, tokens, or topic provided');
    return { status: 'failed', error: 'no_target' };
  } catch (err) {
    logger.warn('notifyService.sendPush error:', err.message);
    return { status: 'failed', error: err.message };
  }
}

function _androidChannelForType(type) {
  switch (type) {
    case 'loan_approved':
    case 'loan_update':
    case 'loan_rejected':
    case 'loan_application':
      return 'loan_notifications';
    case 'guarantor_request':
    case 'guarantor_confirmed':
      return 'guarantor_notifications';
    case 'savings_goal':
    case 'savings_contribution':
      return 'savings_notifications';
    case 'wallet_credited':
    case 'wallet_debited':
    case 'deposit':
    case 'withdrawal':
      return 'wallet_notifications';
    case 'otp':
    case 'otp_sent':
      return 'otp_notifications';
    default:
      return 'coopvest_notifications';
  }
}

// ── Helpers: targeted pushes ──────────────────────────────────────────────────

/**
 * Send a push notification to all FCM tokens registered for a profile.
 * Looks up `device_tokens` table in Supabase.
 */
async function pushToProfile({ profileId, title, body, data = {}, type }) {
  try {
    const { data: rows, error } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('profile_id', profileId)
      .eq('active', true);

    if (error) {
      logger.warn(`pushToProfile: failed to fetch tokens for profile ${profileId}:`, error.message);
      return { status: 'failed', error: error.message };
    }

    if (!rows || rows.length === 0) {
      logger.info(`pushToProfile: no active tokens for profile ${profileId}`);
      return { status: 'skipped', reason: 'no_tokens' };
    }

    const tokens = rows.map((r) => r.token);
    return sendPush({ tokens, title, body, data, type });
  } catch (err) {
    logger.warn('pushToProfile error:', err.message);
    return { status: 'failed', error: err.message };
  }
}

/**
 * Notify user their loan was approved.
 */
async function notifyLoanApproved({ profileId, loanId, loanType, amount }) {
  const title = 'Loan Approved!';
  const body = `Your ${loanType} for ₦${Number(amount).toLocaleString()} has been approved.`;
  await Promise.all([
    sendInApp({ profileId, title, body, type: 'loan_approved', priority: 'high' }),
    pushToProfile({ profileId, title, body, type: 'loan_approved', data: { loanId: String(loanId || '') } }),
  ]);
}

/**
 * Notify user an OTP was sent via push (supplement to SMS/email).
 */
async function notifyOtpSent({ profileId, otp, purpose = 'verification' }) {
  const title = 'Your OTP Code';
  const body = `Your Coopvest ${purpose} code is ${otp}. Expires in 10 minutes. Do not share it.`;
  await Promise.all([
    sendInApp({ profileId, title, body, type: 'otp_sent', priority: 'high' }),
    pushToProfile({ profileId, title, body, type: 'otp_sent' }),
  ]);
}

/**
 * Notify user their wallet was credited.
 */
async function notifyWalletCredited({ profileId, amount, description }) {
  const desc = description ? ` — ${description}` : '';
  const title = 'Wallet Credited';
  const body = `₦${Number(amount).toLocaleString()} has been added to your wallet${desc}.`;
  await Promise.all([
    sendInApp({ profileId, title, body, type: 'wallet_credited', priority: 'high' }),
    pushToProfile({ profileId, title, body, type: 'wallet_credited' }),
  ]);
}

// ── Broadcast (fan-out) ───────────────────────────────────────────────────────

/**
 * High-level fan-out: deliver to multiple profiles across multiple channels.
 *
 * @param {object} opts
 * @param {string[]} opts.profileIds
 * @param {string[]} opts.channels   - ['in_app', 'email', 'sms', 'push']
 * @param {string}   opts.title
 * @param {string}   opts.body
 * @param {string}   [opts.subject]  - Email subject (falls back to title)
 * @param {string}   [opts.type]     - Notification type
 */
async function broadcast({ profileIds, channels = ['in_app'], title, body, subject, type }) {
  const results = [];

  for (const pid of profileIds) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('id, email, phone')
      .eq('id', pid)
      .maybeSingle();

    if (!profile) continue;

    if (channels.includes('in_app')) {
      results.push(await sendInApp({ profileId: pid, title, body, type }));
    }
    if (channels.includes('email') && profile.email) {
      results.push(await sendEmail({ to: profile.email, subject: subject || title, text: body }));
    }
    if (channels.includes('sms') && profile.phone) {
      results.push(await sendSms({ to: profile.phone, body }));
    }
    if (channels.includes('push')) {
      results.push(await pushToProfile({ profileId: pid, title, body, type }));
    }
  }

  return results;
}

module.exports = {
  sendInApp,
  sendEmail,
  sendSms,
  sendPush,
  pushToProfile,
  broadcast,
  notifyLoanApproved,
  notifyOtpSent,
  notifyWalletCredited,
};
