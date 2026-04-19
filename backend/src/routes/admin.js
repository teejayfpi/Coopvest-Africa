/**
 * Admin Console Routes (member-JWT, admin role)
 *
 * Used by admin users logging into the mobile admin surface with their own
 * Supabase JWT. The cross-backend proxy (admin web portal) uses the
 * /api/v1/admin/* routes in `adminApi.js` which are service-token
 * authenticated instead.
 */

const express = require('express');
const router = express.Router();

const supabase = require('../config/supabase');
const { requireAdmin } = require('../middleware/auth');
const logger = require('../utils/logger');

router.use(requireAdmin);

/**
 * GET /api/v1/admin/overview
 */
router.get('/overview', async (req, res) => {
  try {
    const [members, loans, tickets, kyc] = await Promise.all([
      supabase.from('profiles').select('id', { count: 'exact', head: true }),
      supabase.from('loans').select('status, amount'),
      supabase.from('tickets').select('status', { count: 'exact' }),
      supabase.from('kyc').select('status'),
    ]);

    const loansSummary = (loans.data || []).reduce(
      (acc, l) => {
        acc.total += Number(l.amount || 0);
        acc.byStatus[l.status] = (acc.byStatus[l.status] || 0) + 1;
        return acc;
      },
      { total: 0, byStatus: {} }
    );

    const kycSummary = (kyc.data || []).reduce((acc, k) => {
      acc[k.status] = (acc[k.status] || 0) + 1;
      return acc;
    }, {});

    res.json({
      success: true,
      overview: {
        members: members.count || 0,
        loans: { count: (loans.data || []).length, ...loansSummary },
        tickets: { open: tickets.count || 0, byStatus: {} },
        kyc: kycSummary,
      },
    });
  } catch (err) {
    logger.error('admin overview error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
