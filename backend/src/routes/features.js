const express = require('express');
const router = express.Router();

// In-memory feature flags store (in production, use Supabase)
let featureFlags = {
  loan_requests: { enabled: true, name: 'Loan Requests', description: 'Allow members to submit loan requests' },
  registration: { enabled: true, name: 'Registration', description: 'Allow new users to register' },
  salary_deduction: { enabled: true, name: 'Salary Deduction', description: 'Enable salary deduction as contribution method' },
  direct_contribution: { enabled: true, name: 'Direct Contribution', description: 'Allow direct contributions via app' },
  wallet_transfers: { enabled: false, name: 'Wallet Transfers', description: 'Enable wallet-to-wallet transfers' },
  investment_pool: { enabled: true, name: 'Investment Pool', description: 'Allow investment pool participation' },
  guarantor_system: { enabled: true, name: 'Guarantor System', description: 'Enable guarantor selection for loans' },
  referral_program: { enabled: true, name: 'Referral Program', description: 'Allow member referrals' },
  push_notifications: { enabled: true, name: 'Push Notifications', description: 'Send push notifications' },
  withdrawals: { enabled: true, name: 'Withdrawals', description: 'Allow wallet withdrawals' },
  kyc_verification: { enabled: true, name: 'KYC Verification', description: 'Require identity verification' },
  biometric_login: { enabled: false, name: 'Biometric Login', description: 'Allow biometric authentication' },
};

// GET /api/features - Get all features
router.get('/', (req, res) => {
  try {
    const features = Object.entries(featureFlags).map(([id, data]) => ({
      id,
      ...data,
      lastUpdated: new Date().toISOString(),
      updatedBy: 'System',
    }));
    res.json({ success: true, data: features });
  } catch (err) {
    logger.error('Get features error:', err);
    res.status(500).json({ success: false, error: 'Failed to get features' });
  }
});

// GET /api/features/platform/mobile - Get mobile features (for mobile app)
router.get('/platform/mobile', (req, res) => {
  try {
    const features = Object.entries(featureFlags).map(([name, data]) => ({
      name,
      displayName: data.name,
      description: data.description,
      enabled: data.enabled,
      category: 'mobile',
      platforms: ['mobile'],
      rolloutPercentage: data.enabled ? 100 : 0,
      targetAudience: 'all',
      targetRegions: [],
      priority: 'medium',
      status: data.enabled ? 'active' : 'inactive',
      config: {},
    }));
    res.json({ success: true, data: features });
  } catch (err) {
    logger.error('Get mobile features error:', err);
    res.status(500).json({ success: false, error: 'Failed to get features' });
  }
});

// GET /api/features/:id - Get single feature
router.get('/:id', (req, res) => {
  try {
    const feature = featureFlags[req.params.id];
    if (!feature) {
      return res.status(404).json({ success: false, error: 'Feature not found' });
    }
    res.json({
      success: true,
      data: { id: req.params.id, ...feature, lastUpdated: new Date().toISOString() },
    });
  } catch (err) {
    logger.error('Get feature error:', err);
    res.status(500).json({ success: false, error: 'Failed to get feature' });
  }
});

// PUT /api/mobile-features - Update feature (for admin dashboard)
router.put('/', (req, res) => {
  try {
    const { featureId, enabled } = req.body;
    if (!featureId || typeof enabled !== 'boolean') {
      return res.status(400).json({ success: false, error: 'Invalid request' });
    }
    if (!featureFlags[featureId]) {
      return res.status(404).json({ success: false, error: 'Feature not found' });
    }
    featureFlags[featureId].enabled = enabled;
    res.json({ success: true, message: 'Feature updated', data: { id: featureId, enabled } });
  } catch (err) {
    logger.error('Update feature error:', err);
    res.status(500).json({ success: false, error: 'Failed to update feature' });
  }
});

module.exports = router;
