const { Router } = require('express');
const supabase = require('../supabase');

const router = Router();

// Simple admin key guard middleware
function requireAdmin(req, res, next) {
  const key = process.env.ADMIN_API_KEY;
  if (!key) return next(); // no key configured — allow (dev mode)
  if (req.headers['x-admin-key'] !== key) {
    return res.status(403).json({ error: 'Invalid or missing admin key' });
  }
  next();
}

router.use(requireAdmin);

// GET /admin/users  — paginated user list
router.get('/users', async (req, res) => {
  const page = parseInt(req.query.page || '1', 10);
  const limit = parseInt(req.query.limit || '20', 10);
  const search = (req.query.search || '').trim();
  const kycStatus = req.query.kyc_status;
  const from = (page - 1) * limit;

  let query = supabase
    .from('users')
    .select('id,email,name,phone,kyc_status,membership_status,email_verified,referral_code,created_at,updated_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + limit - 1);

  if (search) {
    query = query.or(`email.ilike.%${search}%,name.ilike.%${search}%`);
  }
  if (kycStatus) {
    query = query.eq('kyc_status', kycStatus);
  }

  const { data, error, count } = await query;
  if (error) return res.status(500).json({ error: error.message });

  res.json({
    users: data,
    pagination: { page, limit, total: count, pages: Math.ceil(count / limit) },
  });
});

// GET /admin/users/:id  — single user with KYC submissions
router.get('/users/:id', async (req, res) => {
  const { data: user, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (error || !user) return res.status(404).json({ error: 'User not found' });

  const { data: kyc } = await supabase
    .from('kyc_submissions')
    .select('*')
    .eq('user_id', req.params.id)
    .order('submitted_at', { ascending: false });

  // Strip password hash
  delete user.password_hash;

  res.json({ user, kyc_submissions: kyc || [] });
});

// PATCH /admin/users/:id/kyc  — update KYC status + trigger push notification
router.patch('/users/:id/kyc', async (req, res) => {
  const { status, notes } = req.body;
  const validStatuses = ['pending', 'under_review', 'approved', 'rejected'];
  if (!status || !validStatuses.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}` });
  }

  const { data: user, error } = await supabase
    .from('users')
    .select('id, email, name, fcm_token, kyc_status')
    .eq('id', req.params.id)
    .single();

  if (error || !user) return res.status(404).json({ error: 'User not found' });

  await supabase.from('users').update({ kyc_status: status }).eq('id', req.params.id);

  // Send push notification
  const { sendKycStatusNotification } = require('../fcm');
  await sendKycStatusNotification(user, status);

  res.json({ message: `KYC status updated to '${status}'`, userId: req.params.id, previousStatus: user.kyc_status, newStatus: status });
});

// PATCH /admin/users/:id/membership  — suspend / reactivate account
router.patch('/users/:id/membership', async (req, res) => {
  const { status } = req.body;
  const valid = ['active', 'suspended', 'inactive'];
  if (!status || !valid.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${valid.join(', ')}` });
  }

  await supabase.from('users').update({ membership_status: status }).eq('id', req.params.id);
  res.json({ message: `Membership status updated to '${status}'`, userId: req.params.id });
});

// GET /admin/kyc  — all KYC submissions (pending review queue)
router.get('/kyc', async (req, res) => {
  const status = req.query.status || 'under_review';
  const page = parseInt(req.query.page || '1', 10);
  const limit = parseInt(req.query.limit || '20', 10);
  const from = (page - 1) * limit;

  const { data, error, count } = await supabase
    .from('users')
    .select('id,email,name,phone,kyc_status,created_at,updated_at', { count: 'exact' })
    .eq('kyc_status', status)
    .order('updated_at', { ascending: false })
    .range(from, from + limit - 1);

  if (error) return res.status(500).json({ error: error.message });

  res.json({
    submissions: data,
    pagination: { page, limit, total: count, pages: Math.ceil(count / limit) },
  });
});

// GET /admin/stats  — dashboard summary stats
router.get('/stats', async (req, res) => {
  const [totalUsers, verifiedUsers, pendingKyc, underReview, approvedKyc, rejectedKyc] = await Promise.all([
    supabase.from('users').select('id', { count: 'exact', head: true }),
    supabase.from('users').select('id', { count: 'exact', head: true }).eq('email_verified', true),
    supabase.from('users').select('id', { count: 'exact', head: true }).eq('kyc_status', 'pending'),
    supabase.from('users').select('id', { count: 'exact', head: true }).eq('kyc_status', 'under_review'),
    supabase.from('users').select('id', { count: 'exact', head: true }).eq('kyc_status', 'approved'),
    supabase.from('users').select('id', { count: 'exact', head: true }).eq('kyc_status', 'rejected'),
  ]);

  res.json({
    users: {
      total: totalUsers.count || 0,
      email_verified: verifiedUsers.count || 0,
    },
    kyc: {
      pending: pendingKyc.count || 0,
      under_review: underReview.count || 0,
      approved: approvedKyc.count || 0,
      rejected: rejectedKyc.count || 0,
    },
    generated_at: new Date().toISOString(),
  });
});

// POST /admin/notify  — broadcast push to a user
router.post('/notify', async (req, res) => {
  const { userId, title, body, data } = req.body;
  if (!userId || !title || !body) {
    return res.status(400).json({ error: 'userId, title, and body are required' });
  }

  const { data: user } = await supabase.from('users').select('id,email,fcm_token').eq('id', userId).single();
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (!user.fcm_token) return res.status(400).json({ error: 'User has no FCM token registered' });

  const { sendPushNotification } = require('../fcm');
  const result = await sendPushNotification({ token: user.fcm_token, title, body, data: data || {} });

  res.json({ message: result.success ? 'Notification sent' : 'FCM not configured', ...result });
});

module.exports = router;
