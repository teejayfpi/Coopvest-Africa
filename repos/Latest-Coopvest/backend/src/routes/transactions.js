/**
 * Transactions Routes
 *
 * Read-only transaction history endpoints backed by the `transactions`
 * table in Supabase. All routes require Supabase Auth.
 */

const express = require('express');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

router.use(authenticate);

function parsePaging(req) {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
  return { page, limit };
}

/**
 * GET /api/v1/transactions
 */
router.get('/', async (req, res) => {
  try {
    const { page, limit } = parsePaging(req);
    let q = supabase
      .from('transactions')
      .select('*', { count: 'exact' })
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false })
      .range((page - 1) * limit, page * limit - 1);

    if (req.query.type) q = q.eq('type', req.query.type);
    if (req.query.category) q = q.eq('category', req.query.category);
    if (req.query.status) q = q.eq('status', req.query.status);
    if (req.query.from) q = q.gte('created_at', new Date(req.query.from).toISOString());
    if (req.query.to) q = q.lte('created_at', new Date(req.query.to).toISOString());

    const { data, error, count } = await q;
    if (error) throw error;

    res.json({
      success: true,
      transactions: data || [],
      pagination: { page, limit, total: count || 0 },
    });
  } catch (err) {
    logger.error('txn list error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/transactions/summary
 */
router.get('/summary', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('transactions')
      .select('type, amount')
      .eq('profile_id', req.user.id);
    if (error) throw error;

    const totals = (data || []).reduce(
      (acc, t) => {
        if (t.type === 'credit') acc.credits += Number(t.amount);
        else acc.debits += Number(t.amount);
        return acc;
      },
      { credits: 0, debits: 0 }
    );
    res.json({ success: true, summary: { ...totals, net: totals.credits - totals.debits } });
  } catch (err) {
    logger.error('txn summary error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

router.get('/credits', async (req, res) => {
  req.query.type = 'credit';
  return router.handle(Object.assign(req, { url: '/', method: 'GET' }), res);
});

router.get('/debits', async (req, res) => {
  req.query.type = 'debit';
  return router.handle(Object.assign(req, { url: '/', method: 'GET' }), res);
});

/**
 * GET /api/v1/transactions/by-type/:type
 */
router.get('/by-type/:type', async (req, res) => {
  try {
    const { page, limit } = parsePaging(req);
    const { data, error, count } = await supabase
      .from('transactions')
      .select('*', { count: 'exact' })
      .eq('profile_id', req.user.id)
      .eq('type', req.params.type)
      .order('created_at', { ascending: false })
      .range((page - 1) * limit, page * limit - 1);
    if (error) throw error;
    res.json({
      success: true,
      transactions: data || [],
      pagination: { page, limit, total: count || 0 },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/transactions/stats/monthly
 */
router.get('/stats/monthly', async (req, res) => {
  try {
    const since = new Date();
    since.setMonth(since.getMonth() - 12);
    const { data, error } = await supabase
      .from('transactions')
      .select('type, amount, created_at')
      .eq('profile_id', req.user.id)
      .gte('created_at', since.toISOString());
    if (error) throw error;

    const buckets = {};
    for (const t of data || []) {
      const key = new Date(t.created_at).toISOString().slice(0, 7);
      if (!buckets[key]) buckets[key] = { month: key, credits: 0, debits: 0, count: 0 };
      if (t.type === 'credit') buckets[key].credits += Number(t.amount);
      else buckets[key].debits += Number(t.amount);
      buckets[key].count += 1;
    }
    const stats = Object.values(buckets).sort((a, b) => a.month.localeCompare(b.month));
    res.json({ success: true, stats });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/transactions/reference/:reference
 */
router.get('/reference/:reference', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('transactions')
      .select('*')
      .eq('profile_id', req.user.id)
      .eq('reference', req.params.reference)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Transaction not found' });
    res.json({ success: true, transaction: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/transactions/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('transactions')
      .select('*')
      .eq('profile_id', req.user.id)
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, error: 'Transaction not found' });
    res.json({ success: true, transaction: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/transactions/statement
 */
router.post('/statement', async (req, res) => {
  try {
    const { from, to, type } = req.body || {};
    let q = supabase
      .from('transactions')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (from) q = q.gte('created_at', new Date(from).toISOString());
    if (to) q = q.lte('created_at', new Date(to).toISOString());
    if (type) q = q.eq('type', type);
    const { data, error } = await q;
    if (error) throw error;
    res.json({ success: true, transactions: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
