/**
 * Analytics Routes
 *
 * Small aggregate reporting endpoints. All rely on Supabase client-side
 * reducers for portability; heavier aggregations should be expressed as
 * SQL views or Postgres functions when we outgrow this.
 */

const express = require('express');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

router.use(authenticate);

router.get('/overview', async (req, res) => {
  try {
    const profileId = req.user.id;
    const [walletRes, savingsRes, loansRes, txnRes] = await Promise.all([
      supabase.from('wallets').select('balance, currency').eq('profile_id', profileId).maybeSingle(),
      supabase.from('savings').select('balance, currency').eq('profile_id', profileId).maybeSingle(),
      supabase.from('loans').select('status, amount, total_repayment').eq('profile_id', profileId),
      supabase.from('transactions').select('type, amount').eq('profile_id', profileId),
    ]);

    const loans = loansRes.data || [];
    const txns = txnRes.data || [];
    const loansSummary = loans.reduce(
      (acc, l) => {
        acc.totalAmount += Number(l.amount);
        acc.totalRepayment += Number(l.total_repayment || 0);
        acc.byStatus[l.status] = (acc.byStatus[l.status] || 0) + 1;
        return acc;
      },
      { totalAmount: 0, totalRepayment: 0, byStatus: {} }
    );

    const txnSummary = txns.reduce(
      (acc, t) => {
        if (t.type === 'credit') acc.credits += Number(t.amount);
        else acc.debits += Number(t.amount);
        return acc;
      },
      { credits: 0, debits: 0 }
    );

    res.json({
      success: true,
      overview: {
        wallet: walletRes.data || { balance: 0, currency: 'NGN' },
        savings: savingsRes.data || { balance: 0, currency: 'NGN' },
        loans: { count: loans.length, ...loansSummary },
        transactions: { count: txns.length, ...txnSummary },
      },
    });
  } catch (err) {
    logger.error('analytics overview error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
