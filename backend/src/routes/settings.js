/**
 * User Settings Routes
 *
 * Per-user settings rows live in Supabase `user_settings` (1:1 with
 * profile). A single flat JSON blob stores UI preferences, locale,
 * notification channels, etc.; top-level columns cover commonly queried
 * flags so the admin can filter easily.
 */

const express = require('express');
const { body } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

async function getOrCreate(profileId) {
  const { data, error } = await supabase
    .from('user_settings')
    .select('*')
    .eq('profile_id', profileId)
    .maybeSingle();
  if (error) throw error;
  if (data) return data;
  const { data: created, error: cErr } = await supabase
    .from('user_settings')
    .insert({ profile_id: profileId, preferences: {} })
    .select('*')
    .single();
  if (cErr) throw cErr;
  return created;
}

router.get('/', async (req, res) => {
  try {
    res.json({ success: true, settings: await getOrCreate(req.user.id) });
  } catch (err) {
    logger.error('settings get error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

router.patch('/', [body('preferences').optional().isObject()], validate, async (req, res) => {
  try {
    const existing = await getOrCreate(req.user.id);
    const update = {};
    if (req.body.preferences) update.preferences = { ...(existing.preferences || {}), ...req.body.preferences };
    if (req.body.locale !== undefined) update.locale = req.body.locale;
    if (req.body.timezone !== undefined) update.timezone = req.body.timezone;
    if (req.body.theme !== undefined) update.theme = req.body.theme;
    if (req.body.biometricEnabled !== undefined) update.biometric_enabled = !!req.body.biometricEnabled;
    if (req.body.twoFactorEnabled !== undefined) update.two_factor_enabled = !!req.body.twoFactorEnabled;
    if (req.body.notificationChannels !== undefined) update.notification_channels = req.body.notificationChannels;

    const { data, error } = await supabase
      .from('user_settings')
      .update(update)
      .eq('profile_id', existing.profile_id)
      .select('*')
      .single();
    if (error) throw error;
    res.json({ success: true, settings: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
