/**
 * Watchlist Routes
 *
 * Per-user watchlist entries (saved loans, investment pools, tickers) are
 * stored in Supabase `watchlist`. Each row has a `target_type` + `target_id`.
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

router.get('/', async (req, res) => {
  try {
    let q = supabase
      .from('watchlist')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (req.query.targetType) q = q.eq('target_type', req.query.targetType);
    const { data, error } = await q;
    if (error) throw error;
    res.json({ success: true, items: data || [] });
  } catch (err) {
    logger.error('watchlist list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post(
  '/',
  [body('targetType').isString().notEmpty(), body('targetId').isString().notEmpty()],
  validate,
  async (req, res) => {
    try {
      const { targetType, targetId, meta } = req.body;
      const { data, error } = await supabase
        .from('watchlist')
        .upsert(
          { profile_id: req.user.id, target_type: targetType, target_id: targetId, meta: meta || {} },
          { onConflict: 'profile_id,target_type,target_id' }
        )
        .select('*')
        .single();
      if (error) throw error;
      res.status(201).json({ success: true, item: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

router.delete('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { error } = await supabase
      .from('watchlist')
      .delete()
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id);
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
