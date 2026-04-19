/**
 * Referrals Routes
 *
 * Thin Supabase-backed endpoints. Heavy business logic (tier bonuses,
 * abuse checks, loan discount consumption) lives in
 * `services/referralService.js`.
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');
const referralService = require('../services/referralService');

router.use(authenticate);

const generateCode = () => {
  const chars = 'ABCDEFGHIJKLMNPQRSTUVWXYZ0123456789';
  return 'CV-' + Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
};

async function ensureReferralRow(profileId) {
  const { data } = await supabase
    .from('referrals')
    .select('*')
    .eq('profile_id', profileId)
    .maybeSingle();
  if (data) return data;
  const { data: created, error } = await supabase
    .from('referrals')
    .insert({ profile_id: profileId, my_referral_code: generateCode() })
    .select('*')
    .single();
  if (error) throw error;
  return created;
}

/**
 * GET /api/v1/referrals/summary
 */
router.get('/summary', async (req, res) => {
  try {
    await ensureReferralRow(req.user.id);
    const summary = await referralService.getReferralSummary(req.user.id);
    res.json({ success: true, ...summary });
  } catch (err) {
    logger.error('referral summary error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/referrals/share-link
 */
router.get('/share-link', async (req, res) => {
  try {
    await ensureReferralRow(req.user.id);
    const data = await referralService.getShareLink(req.user.id);
    res.json(data);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/referrals/events — list referrals this user made
 */
router.get('/events', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('referral_events')
      .select('*, referred:profiles!referral_events_referred_id_fkey(id, user_id, name, email)')
      .eq('referrer_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, events: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/referrals/claim — called by a new signup to credit referrer
 */
router.post(
  '/claim',
  [body('referralCode').isString().isLength({ min: 4, max: 20 })],
  validate,
  async (req, res) => {
    try {
      const { referralCode } = req.body;
      const { data: referrer, error: rErr } = await supabase
        .from('referrals')
        .select('profile_id')
        .eq('my_referral_code', referralCode)
        .maybeSingle();
      if (rErr) throw rErr;
      if (!referrer) return res.status(404).json({ success: false, error: 'Referral code not found' });

      const abuse = await referralService.checkForAbuse(referrer.profile_id, req.user.id);
      if (abuse.isDuplicate) {
        return res.status(400).json({ success: false, error: abuse.reason });
      }

      const lockInEnd = new Date();
      lockInEnd.setDate(lockInEnd.getDate() + 30);

      const { data: event, error } = await supabase
        .from('referral_events')
        .insert({
          referral_id: `REF-${Date.now()}`,
          referrer_id: referrer.profile_id,
          referred_id: req.user.id,
          confirmed: false,
          is_flagged: false,
          bonus_consumed: false,
          lock_in_end_date: lockInEnd.toISOString(),
        })
        .select('*')
        .single();
      if (error) throw error;

      // Increment the referrer's raw referral count
      const { data: current } = await supabase
        .from('referrals')
        .select('referral_count')
        .eq('profile_id', referrer.profile_id)
        .maybeSingle();
      await supabase
        .from('referrals')
        .update({ referral_count: (current?.referral_count || 0) + 1 })
        .eq('profile_id', referrer.profile_id);

      res.status(201).json({ success: true, event });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * POST /api/v1/referrals/events/:id/confirm — lifecycle hook for admin or
 * email verification; marks a referral as confirmed and refreshes tier.
 */
router.post('/events/:id/confirm', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data: event, error } = await supabase
      .from('referral_events')
      .update({ confirmed: true, confirmed_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    if (!event) return res.status(404).json({ success: false, error: 'Event not found' });
    await referralService.updateReferrerTier(event.referrer_id);
    res.json({ success: true, event });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
