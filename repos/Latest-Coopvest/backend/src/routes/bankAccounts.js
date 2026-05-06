/**
 * Bank Accounts Routes
 *
 * Linked bank accounts are stored in Supabase `bank_accounts`, one row per
 * account per profile. The first created account is marked as default.
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
 * GET /api/v1/bank-accounts
 */
router.get('/', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('bank_accounts')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, accounts: data || [] });
  } catch (err) {
    logger.error('bank accounts list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/bank-accounts
 */
router.post(
  '/',
  [
    body('bankName').isString().isLength({ min: 1, max: 120 }),
    body('accountNumber').isString().isLength({ min: 6, max: 20 }),
    body('accountName').isString().isLength({ min: 1, max: 200 }),
    body('bankCode').optional().isString(),
  ],
  validate,
  async (req, res) => {
    try {
      const { bankName, accountNumber, accountName, bankCode } = req.body;
      const { count } = await supabase
        .from('bank_accounts')
        .select('id', { count: 'exact', head: true })
        .eq('profile_id', req.user.id);

      const { data, error } = await supabase
        .from('bank_accounts')
        .insert({
          profile_id: req.user.id,
          bank_name: bankName,
          account_number: accountNumber,
          account_name: accountName,
          bank_code: bankCode || null,
          is_default: (count || 0) === 0,
        })
        .select('*')
        .single();
      if (error) throw error;
      res.status(201).json({ success: true, account: data });
    } catch (err) {
      logger.error('bank account create error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * PATCH /api/v1/bank-accounts/:id
 */
router.patch('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const update = {};
    if (req.body.bankName !== undefined) update.bank_name = req.body.bankName;
    if (req.body.accountNumber !== undefined) update.account_number = req.body.accountNumber;
    if (req.body.accountName !== undefined) update.account_name = req.body.accountName;
    if (req.body.bankCode !== undefined) update.bank_code = req.body.bankCode;
    const { data, error } = await supabase
      .from('bank_accounts')
      .update(update)
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Account not found' });
    res.json({ success: true, account: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PATCH /api/v1/bank-accounts/:id/default
 */
router.patch('/:id/default', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { error: clearErr } = await supabase
      .from('bank_accounts')
      .update({ is_default: false })
      .eq('profile_id', req.user.id);
    if (clearErr) throw clearErr;
    const { data, error } = await supabase
      .from('bank_accounts')
      .update({ is_default: true })
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Account not found' });
    res.json({ success: true, account: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * DELETE /api/v1/bank-accounts/:id
 */
router.delete('/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { error } = await supabase
      .from('bank_accounts')
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
