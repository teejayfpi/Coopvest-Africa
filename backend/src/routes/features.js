const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const TABLE = 'mobile_features';

// Fallbacks used when Supabase is unavailable (e.g. migration not yet applied).
// They mirror the seeded defaults in migrations/011_mobile_features.sql so the
// API degrades gracefully instead of erroring while the table is being set up.
const FALLBACK_FEATURES = [
  { id: 'loan_requests', name: 'Loan Requests', description: 'Allow members to submit loan requests', enabled: true, updated_by: 'System' },
  { id: 'registration', name: 'Registration', description: 'Allow new users to register', enabled: true, updated_by: 'System' },
  { id: 'salary_deduction', name: 'Salary Deduction', description: 'Enable salary deduction as contribution method', enabled: true, updated_by: 'System' },
  { id: 'direct_contribution', name: 'Direct Contribution', description: 'Allow direct contributions via app', enabled: true, updated_by: 'System' },
  { id: 'wallet_transfers', name: 'Wallet Transfers', description: 'Enable wallet-to-wallet transfers', enabled: false, updated_by: 'System' },
  { id: 'investment_pool', name: 'Investment Pool', description: 'Allow investment pool participation', enabled: true, updated_by: 'System' },
  { id: 'guarantor_system', name: 'Guarantor System', description: 'Enable guarantor selection for loans', enabled: true, updated_by: 'System' },
  { id: 'referral_program', name: 'Referral Program', description: 'Allow member referrals', enabled: true, updated_by: 'System' },
  { id: 'push_notifications', name: 'Push Notifications', description: 'Send push notifications', enabled: true, updated_by: 'System' },
  { id: 'withdrawals', name: 'Withdrawals', description: 'Allow wallet withdrawals', enabled: true, updated_by: 'System' },
  { id: 'kyc_verification', name: 'KYC Verification', description: 'Require identity verification', enabled: true, updated_by: 'System' },
  { id: 'biometric_login', name: 'Biometric Login', description: 'Allow biometric authentication', enabled: false, updated_by: 'System' },
];

// Load all feature flags from Supabase. Returns the fallback set only when the
// mobile_features table is missing (e.g. before migration 011 is applied);
// genuine DB errors are thrown so callers can surface a 500.
async function loadFeatures() {
  const { data, error } = await supabase
    .from(TABLE)
    .select('id, name, description, enabled, updated_by, updated_at')
    .order('id', { ascending: true });

  if (error) {
    // 42P01 = undefined_table; the migration simply hasn't been run yet.
    if (error.code === '42P01' || /relation .* does not exist/i.test(error.message)) {
      logger.warn('mobile_features table missing — serving fallback defaults. Run migration 011.');
      return FALLBACK_FEATURES.map((f) => ({ ...f, updated_at: null }));
    }
    throw error;
  }
  return data || [];
}

// Shared handlers. The same logic is exposed under several URL prefixes because
// the admin dashboard calls /api/mobile-features while the Flutter app calls
// /api/features/platform/mobile; the router is mounted once at /api in server.js,
// so we register explicit paths for each client and keep the generic ones too.

async function listHandler(req, res) {
  try {
    const rows = await loadFeatures();
    const features = rows.map((r) => ({
      id: r.id,
      name: r.name,
      description: r.description,
      enabled: r.enabled,
      lastUpdated: (r.updated_at ? new Date(r.updated_at) : new Date()).toISOString(),
      updatedBy: r.updated_by || 'System',
    }));
    res.json({ success: true, data: features });
  } catch (err) {
    logger.error('Get features error:', err);
    res.status(500).json({ success: false, error: 'Failed to get features' });
  }
}

async function mobileHandler(req, res) {
  try {
    const rows = await loadFeatures();
    const features = rows.map((r) => ({
      name: r.id,
      displayName: r.name,
      description: r.description,
      enabled: r.enabled,
      category: 'mobile',
      platforms: ['mobile'],
      rolloutPercentage: r.enabled ? 100 : 0,
      targetAudience: 'all',
      targetRegions: [],
      priority: 'medium',
      status: r.enabled ? 'active' : 'inactive',
      config: {},
    }));
    res.json({ success: true, data: features });
  } catch (err) {
    logger.error('Get mobile features error:', err);
    res.status(500).json({ success: false, error: 'Failed to get features' });
  }
}

async function toggleHandler(req, res) {
  try {
    const { featureId, enabled } = req.body;
    if (!featureId || typeof enabled !== 'boolean') {
      return res.status(400).json({ success: false, error: 'Invalid request' });
    }

    const updatedBy = (req.user && (req.user.email || req.user.id)) || 'Admin';

    const { data, error } = await supabase
      .from(TABLE)
      .update({ enabled, updated_by: updatedBy })
      .eq('id', featureId)
      .select('id, enabled')
      .maybeSingle();

    if (error) throw error;
    if (!data) {
      return res.status(404).json({ success: false, error: 'Feature not found' });
    }
    res.json({ success: true, message: 'Feature updated', data: { id: data.id, enabled: data.enabled } });
  } catch (err) {
    logger.error('Update feature error:', err);
    res.status(500).json({ success: false, error: 'Failed to update feature' });
  }
}

// Explicit client paths — registered BEFORE the /:id catch-all so they win.
// Admin dashboard: GET/PUT /api/mobile-features
router.get('/mobile-features', listHandler);
router.put('/mobile-features', toggleHandler);
// Flutter app: GET /api/features/platform/mobile
router.get('/features/platform/mobile', mobileHandler);

// Generic paths kept for backward compatibility.
router.get('/', listHandler);
router.get('/platform/mobile', mobileHandler);

// GET /api/features/:id - Get single feature
router.get('/:id', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from(TABLE)
      .select('id, name, description, enabled, updated_by, updated_at')
      .eq('id', req.params.id)
      .maybeSingle();

    if (error) throw error;
    if (!data) {
      return res.status(404).json({ success: false, error: 'Feature not found' });
    }
    res.json({
      success: true,
      data: {
        id: data.id,
        name: data.name,
        description: data.description,
        enabled: data.enabled,
        lastUpdated: (data.updated_at ? new Date(data.updated_at) : new Date()).toISOString(),
        updatedBy: data.updated_by || 'System',
      },
    });
  } catch (err) {
    logger.error('Get feature error:', err);
    res.status(500).json({ success: false, error: 'Failed to get feature' });
  }
});

// Generic toggle path (kept for backward compatibility).
router.put('/', toggleHandler);

module.exports = router;
