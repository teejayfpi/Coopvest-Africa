/**
 * Rollover Routes
 *
 * A rollover extends the tenure of an active loan. Rollover requests are
 * persisted in Supabase `rollovers` and link back to the source loan.
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

/**
 * POST /api/v1/rollovers
 */
router.post(
  '/',
  [body('loanId').isString().notEmpty(), body('extensionMonths').isInt({ min: 1, max: 12 })],
  validate,
  async (req, res) => {
    try {
      const { loanId, extensionMonths, reason } = req.body;
      const { data: loan, error: lErr } = await supabase
        .from('loans')
        .select('*')
        .eq('loan_id', loanId)
        .eq('profile_id', req.user.id)
        .maybeSingle();
      if (lErr) throw lErr;
      if (!loan) return res.status(404).json({ success: false, error: 'Loan not found' });

      const { data, error } = await supabase
        .from('rollovers')
        .insert({
          loan_id: loan.id,
          profile_id: req.user.id,
          extension_months: extensionMonths,
          reason: reason || null,
          status: 'pending',
        })
        .select('*')
        .single();
      if (error) throw error;

      res.status(201).json({ success: true, rollover: data });
    } catch (err) {
      logger.error('rollover create error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/rollovers
 */
router.get('/', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('rollovers')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, rollovers: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/rollovers/:id
 */
router.get('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('rollovers')
      .select('*')
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Rollover not found' });
    res.json({ success: true, rollover: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * DELETE /api/v1/rollovers/:id — cancels while still pending
 */
router.delete('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { data: existing, error: sel } = await supabase
      .from('rollovers')
      .select('*')
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .maybeSingle();
    if (sel) throw sel;
    if (!existing) return res.status(404).json({ success: false, error: 'Rollover not found' });
    if (existing.status !== 'pending') {
      return res.status(400).json({ success: false, error: 'Only pending rollovers can be cancelled' });
    }

    const { data, error } = await supabase
      .from('rollovers')
      .update({ status: 'cancelled', cancelled_at: new Date().toISOString() })
      .eq('id', existing.id)
      .select('*')
      .single();
    if (error) throw error;
    res.json({ success: true, rollover: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
