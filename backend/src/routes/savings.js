/**
 * Savings Routes
 *
 * Savings balances are stored per profile in `savings`. Named savings goals
 * live in `savings_goals`. Deposits and withdrawals flow through the
 * wallet helpers so every movement has a matching transaction row.
 */

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');
const { adjustBalance, recordTransaction, ensureWallet } = require('./wallet');

router.use(authenticate);

async function getOrCreateSavings(profileId) {
  const { data, error } = await supabase
    .from('savings')
    .select('*')
    .eq('profile_id', profileId)
    .maybeSingle();
  if (error) throw error;
  if (data) return data;
  const { data: created, error: cErr } = await supabase
    .from('savings')
    .insert({ profile_id: profileId, balance: 0, currency: 'NGN' })
    .select('*')
    .single();
  if (cErr) throw cErr;
  return created;
}

async function adjustSavings(profileId, delta) {
  const row = await getOrCreateSavings(profileId);
  const newBalance = Number(row.balance) + Number(delta);
  if (newBalance < 0) {
    const err = new Error('Insufficient savings balance');
    err.statusCode = 400;
    throw err;
  }
  const { data, error } = await supabase
    .from('savings')
    .update({ balance: newBalance })
    .eq('id', row.id)
    .select('*')
    .single();
  if (error) throw error;
  return data;
}

/**
 * GET /api/v1/savings
 */
router.get('/', async (req, res) => {
  try {
    const savings = await getOrCreateSavings(req.user.id);
    res.json({ success: true, savings });
  } catch (err) {
    logger.error('savings get error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/savings/deposit
 */
router.post(
  '/deposit',
  [body('amount').isFloat({ min: 0.01 }), body('goalId').optional().isUUID()],
  validate,
  async (req, res) => {
    try {
      const { amount, goalId, description } = req.body;
      await adjustBalance(req.user.id, -Number(amount));
      const savings = await adjustSavings(req.user.id, Number(amount));
      const txn = await recordTransaction(req.user.id, {
        type: 'debit',
        category: 'savings_deposit',
        amount,
        description: description || 'Savings deposit',
        meta: goalId ? { goalId } : {},
      });

      if (goalId) {
        const { data: goal } = await supabase
          .from('savings_goals')
          .select('*')
          .eq('id', goalId)
          .eq('profile_id', req.user.id)
          .maybeSingle();
        if (goal) {
          await supabase
            .from('savings_goals')
            .update({ saved_amount: Number(goal.saved_amount) + Number(amount) })
            .eq('id', goal.id);
        }
      }

      res.status(201).json({ success: true, savings, transaction: txn });
    } catch (err) {
      logger.error('savings deposit error:', err);
      res.status(err.statusCode || 500).json({ success: false, error: err.message });
    }
  }
);

/**
 * POST /api/v1/savings/withdraw
 */
router.post(
  '/withdraw',
  [body('amount').isFloat({ min: 0.01 })],
  validate,
  async (req, res) => {
    try {
      const { amount, description } = req.body;
      const savings = await adjustSavings(req.user.id, -Number(amount));
      await ensureWallet(req.user.id);
      await adjustBalance(req.user.id, Number(amount));
      const txn = await recordTransaction(req.user.id, {
        type: 'credit',
        category: 'savings_withdrawal',
        amount,
        description: description || 'Savings withdrawal',
      });
      res.status(201).json({ success: true, savings, transaction: txn });
    } catch (err) {
      res.status(err.statusCode || 500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/savings/goals
 */
router.get('/goals', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('savings_goals')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, goals: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/savings/goals
 */
router.post(
  '/goals',
  [
    body('name').isString().isLength({ min: 1, max: 200 }),
    body('targetAmount').isFloat({ min: 1 }),
    body('targetDate').optional().isISO8601(),
  ],
  validate,
  async (req, res) => {
    try {
      const { name, targetAmount, targetDate, category } = req.body;
      const { data, error } = await supabase
        .from('savings_goals')
        .insert({
          profile_id: req.user.id,
          name,
          target_amount: targetAmount,
          saved_amount: 0,
          target_date: targetDate || null,
          category: category || null,
          status: 'active',
        })
        .select('*')
        .single();
      if (error) throw error;
      res.status(201).json({ success: true, goal: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * PATCH /api/v1/savings/goals/:id
 */
router.patch(
  '/goals/:id',
  [param('id').isUUID()],
  validate,
  async (req, res) => {
    try {
      const update = {};
      if (req.body.name !== undefined) update.name = req.body.name;
      if (req.body.targetAmount !== undefined) update.target_amount = req.body.targetAmount;
      if (req.body.targetDate !== undefined) update.target_date = req.body.targetDate;
      if (req.body.status !== undefined) update.status = req.body.status;
      const { data, error } = await supabase
        .from('savings_goals')
        .update(update)
        .eq('id', req.params.id)
        .eq('profile_id', req.user.id)
        .select('*')
        .maybeSingle();
      if (error) throw error;
      if (!data) return res.status(404).json({ success: false, error: 'Goal not found' });
      res.json({ success: true, goal: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * DELETE /api/v1/savings/goals/:id
 */
router.delete('/goals/:id', [param('id').isUUID()], validate, async (req, res) => {
  try {
    const { error } = await supabase
      .from('savings_goals')
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
