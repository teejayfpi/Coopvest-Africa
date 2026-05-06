const { Router } = require('express');
const supabase = require('../supabase');
const { requireAuth } = require('../middleware/auth');

const router = Router();

router.post('/fcm-token', requireAuth, async (req, res) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'token is required' });

  await supabase.from('users').update({ fcm_token: token }).eq('id', req.user.id);
  res.json({ message: 'FCM token registered' });
});

module.exports = router;
