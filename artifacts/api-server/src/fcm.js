let firebaseApp = null;
let messaging = null;

function initFirebase() {
  if (firebaseApp) return messaging;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) {
    console.warn('[FCM] FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled');
    return null;
  }

  try {
    const admin = require('firebase-admin');
    const serviceAccount = JSON.parse(serviceAccountJson);
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    messaging = admin.messaging(firebaseApp);
    console.log('[FCM] Firebase Admin SDK initialized — push notifications enabled');
    return messaging;
  } catch (err) {
    console.error('[FCM] Failed to initialize Firebase Admin SDK:', err.message);
    return null;
  }
}

async function sendPushNotification({ token, title, body, data = {} }) {
  const msg = initFirebase();
  if (!msg) {
    console.log(`[FCM] (disabled) Would push to token ${token?.slice(0, 20)}...: ${title} — ${body}`);
    return { success: false, reason: 'FCM not configured' };
  }

  try {
    const result = await msg.send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'coopvest_default' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
    console.log(`[FCM] Push sent — messageId: ${result}`);
    return { success: true, messageId: result };
  } catch (err) {
    console.error('[FCM] Push failed:', err.message);
    return { success: false, reason: err.message };
  }
}

async function sendKycStatusNotification(user, kycStatus) {
  if (!user.fcm_token) return;
  const messages = {
    approved: {
      title: 'KYC Approved!',
      body: 'Your identity has been verified. You now have full access to Coopvest.',
    },
    rejected: {
      title: 'KYC Update Required',
      body: 'Your KYC submission needs attention. Please resubmit your documents.',
    },
    under_review: {
      title: 'KYC Under Review',
      body: 'Your documents are being reviewed. We\'ll notify you shortly.',
    },
  };
  const msg = messages[kycStatus];
  if (!msg) return;
  await sendPushNotification({
    token: user.fcm_token,
    title: msg.title,
    body: msg.body,
    data: { type: 'kyc_status', status: kycStatus },
  });
}

module.exports = { sendPushNotification, sendKycStatusNotification, initFirebase };
