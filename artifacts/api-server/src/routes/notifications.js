const { Router } = require('express');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = Router();

// POST /notifications/fcm-token
router.post('/fcm-token', requireAuth, (req, res) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'token is required' });

  const now = new Date().toISOString();
  db.prepare('UPDATE users SET fcm_token = ?, updated_at = ? WHERE id = ?').run(token, now, req.user.id);

  res.json({ message: 'FCM token registered' });
});

module.exports = router;
