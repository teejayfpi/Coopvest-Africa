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
 * GET /api/v1/admin/payment-settings
 * Returns the current payment account details shown on the deposit screen.
 */
router.get('/payment-settings', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'payment_account')
      .maybeSingle();

    if (error) throw error;

    if (data?.value) {
      return res.json({ success: true, ...data.value });
    }

    return res.json({
      success: true,
      bank: process.env.DEFAULT_PAYMENT_BANK || 'Opay',
      account_name: process.env.DEFAULT_PAYMENT_ACCOUNT_NAME || 'Coopvest Africa',
      account_number: process.env.DEFAULT_PAYMENT_ACCOUNT_NUMBER || '',
    });
  } catch (err) {
    logger.error('admin payment-settings error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

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

/**
 * PUT /api/v1/admin/payment-settings
 * Update payment account details
 */
router.put('/payment-settings', async (req, res) => {
  try {
    const { bank, account_name, account_number } = req.body;

    if (!bank || !account_name || !account_number) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: bank, account_name, account_number'
      });
    }

    const paymentSettings = { bank, account_name, account_number, updated_at: new Date().toISOString() };

    // Upsert payment settings
    const { data, error } = await supabase
      .from('settings')
      .upsert(
        { key: 'payment_account', value: paymentSettings },
        { onConflict: 'key' }
      )
      .select()
      .single();

    if (error) throw error;

    logger.info('Payment settings updated by admin');
    res.json({ success: true, ...paymentSettings });
  } catch (err) {
    logger.error('admin payment-settings update error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/salary-deduction
 * Get global salary deduction setting
 */
router.get('/salary-deduction', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'salary_deduction_global')
      .maybeSingle();

    if (error) throw error;

    res.json({
      success: true,
      enabled: data?.value?.enabled ?? false,
    });
  } catch (err) {
    logger.error('admin salary-deduction get error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PUT /api/v1/admin/salary-deduction
 * Update global salary deduction setting
 */
router.put('/salary-deduction', async (req, res) => {
  try {
    const { enabled } = req.body;

    if (typeof enabled !== 'boolean') {
      return res.status(400).json({
        success: false,
        error: 'enabled must be a boolean'
      });
    }

    const { data, error } = await supabase
      .from('settings')
      .upsert(
        { key: 'salary_deduction_global', value: { enabled, updated_at: new Date().toISOString() } },
        { onConflict: 'key' }
      )
      .select()
      .single();

    if (error) throw error;

    logger.info(`Salary deduction global setting updated to: ${enabled}`);
    res.json({ success: true, enabled });
  } catch (err) {
    logger.error('admin salary-deduction update error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/admin/organizations
 * Get enrolled organizations
 */
router.get('/organizations', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('organizations')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.json({ success: true, organizations: data || [] });
  } catch (err) {
    logger.error('admin organizations get error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/admin/organizations
 * Create new organization
 */
router.post('/organizations', async (req, res) => {
  try {
    const { name, deduction_type } = req.body;

    if (!name) {
      return res.status(400).json({
        success: false,
        error: 'Organization name is required'
      });
    }

    const { data, error } = await supabase
      .from('organizations')
      .insert({
        name,
        deduction_type: deduction_type || 'manual_upload',
        deduction_enabled: false,
        remittance_cycle: 'monthly',
      })
      .select()
      .single();

    if (error) throw error;

    logger.info(`Organization created: ${name}`);
    res.json({ success: true, organization: data });
  } catch (err) {
    logger.error('admin organizations create error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PATCH /api/v1/admin/organizations/:id
 * Update organization
 */
router.patch('/organizations/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { deduction_enabled, ...rest } = req.body;

    const updateData = { ...rest };
    if (typeof deduction_enabled === 'boolean') {
      updateData.deduction_enabled = deduction_enabled;
    }

    const { data, error } = await supabase
      .from('organizations')
      .update({ ...updateData, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    if (!data) {
      return res.status(404).json({ success: false, error: 'Organization not found' });
    }

    logger.info(`Organization ${id} updated`);
    res.json({ success: true, organization: data });
  } catch (err) {
    logger.error('admin organizations update error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * DELETE /api/v1/admin/organizations/:id
 * Delete organization
 */
router.delete('/organizations/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase
      .from('organizations')
      .delete()
      .eq('id', id);

    if (error) throw error;

    logger.info(`Organization ${id} deleted`);
    res.json({ success: true });
  } catch (err) {
    logger.error('admin organizations delete error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
