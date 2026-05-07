const { Router } = require('express');
const supabase = require('../supabase');
const { requireAuth } = require('../middleware/auth');
const { sendPushNotification, sendKycStatusNotification } = require('../fcm');

const router = Router();

// POST /notifications/fcm-token
// Register or update FCM device token for the authenticated user
router.post('/fcm-token', requireAuth, async (req, res) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'token is required' });

  const { error } = await supabase
    .from('users')
    .update({ fcm_token: token })
    .eq('id', req.user.id);

  if (error) {
    console.error('[FCM-TOKEN] DB error:', error.message);
    return res.status(500).json({ error: 'Failed to register token' });
  }

  res.json({ message: 'FCM token registered successfully' });
});

// DELETE /notifications/fcm-token
// Remove FCM token on logout / notification opt-out
router.delete('/fcm-token', requireAuth, async (req, res) => {
  await supabase.from('users').update({ fcm_token: null }).eq('id', req.user.id);
  res.json({ message: 'FCM token removed' });
});

// POST /notifications/send
// Send a push notification to the authenticated user's device (for testing)
router.post('/send', requireAuth, async (req, res) => {
  const { title, body, data } = req.body;
  if (!title || !body) return res.status(400).json({ error: 'title and body are required' });

  const token = req.user.fcm_token;
  if (!token) return res.status(400).json({ error: 'No FCM token registered for this user' });

  const result = await sendPushNotification({ token, title, body, data: data || {} });
  if (result.success) {
    res.json({ message: 'Notification sent', messageId: result.messageId });
  } else {
    res.status(500).json({ error: 'Failed to send notification', reason: result.reason });
  }
});

// POST /notifications/kyc-update  (admin/internal use)
// Trigger a KYC status push notification for a specific user
router.post('/kyc-update', async (req, res) => {
  const adminKey = process.env.ADMIN_API_KEY;
  if (adminKey && req.headers['x-admin-key'] !== adminKey) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const { userId, status } = req.body;
  if (!userId || !status) return res.status(400).json({ error: 'userId and status are required' });

  const validStatuses = ['approved', 'rejected', 'under_review'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}` });
  }

  const { data: user, error } = await supabase
    .from('users').select('id, email, name, fcm_token, kyc_status').eq('id', userId).single();

  if (error || !user) return res.status(404).json({ error: 'User not found' });

  // Update KYC status in DB
  await supabase.from('users').update({ kyc_status: status }).eq('id', userId);

  // Send push notification
  await sendKycStatusNotification(user, status);

  res.json({ message: `KYC status updated to '${status}' and notification sent`, userId });
});

module.exports = router;
