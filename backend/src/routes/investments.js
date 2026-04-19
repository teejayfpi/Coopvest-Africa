/**
 * Investment Pools Routes
 *
 * Pools are defined in Supabase `investment_pools` and member stakes are
 * tracked in `investment_participations`. Listing pools is public; joining
 * and viewing your own participations requires authentication.
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

/**
 * GET /api/v1/investments/pools — public listing
 */
router.get('/pools', async (req, res) => {
  try {
    let q = supabase.from('investment_pools').select('*').order('created_at', { ascending: false });
    if (req.query.status) q = q.eq('status', req.query.status);
    const { data, error } = await q;
    if (error) throw error;
    res.json({ success: true, pools: data || [] });
  } catch (err) {
    logger.error('investments list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

router.get('/pools/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('investment_pools')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Pool not found' });
    res.json({ success: true, pool: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post(
  '/pools/:id/join',
  authenticate,
  [param('id').isUUID(), body('amount').isFloat({ min: 0.01 })],
  validate,
  async (req, res) => {
    try {
      const { data: pool, error: pErr } = await supabase
        .from('investment_pools')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (pErr) throw pErr;
      if (!pool) return res.status(404).json({ success: false, error: 'Pool not found' });
      if (pool.status !== 'open') return res.status(400).json({ success: false, error: 'Pool is not open' });

      const { data, error } = await supabase
        .from('investment_participations')
        .insert({
          pool_id: pool.id,
          profile_id: req.user.id,
          amount: req.body.amount,
          status: 'active',
        })
        .select('*')
        .single();
      if (error) throw error;
      res.status(201).json({ success: true, participation: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

router.get('/my-participations', authenticate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('investment_participations')
      .select('*, pool:investment_pools(id, name, status, expected_return_pct)')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, participations: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
