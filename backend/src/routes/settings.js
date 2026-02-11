/**
 * Settings Routes
 * API endpoints for managing user preferences and settings
 */

const express = require('express');
const router = express.Router();
const { Settings } = require('../models');
const { auth: authMiddleware } = require('../middleware/auth');

// All routes require authentication
router.use(authMiddleware);

/**
 * GET /api/v1/settings
 * Get current user settings
 */
router.get('/', async (req, res) => {
  try {
    let settings = await Settings.getOrCreate(req.user.id);

    res.json({
      success: true,
      data: settings
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/settings/notifications
 * Update notification preferences
 */
router.patch('/notifications', async (req, res) => {
  try {
    const { type, channel, key, value } = req.body;

    let settings = await Settings.getOrCreate(req.user.id);

    if (!type || !channel || key === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Type, channel, and key are required'
      });
    }

    if (!settings.notifications[type] || !settings.notifications[type][channel]) {
      return res.status(400).json({
        success: false,
        error: 'Invalid notification type or channel'
      });
    }

    settings.notifications[type][channel][key] = value;
    await settings.save();

    res.json({
      success: true,
      message: 'Notification settings updated',
      data: settings.notifications
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/settings/security
 * Update security settings
 */
router.patch('/security', async (req, res) => {
  try {
    const { field, value } = req.body;

    let settings = await Settings.getOrCreate(req.user.id);

    const allowedFields = [
      'loginAlerts',
      'transactionPIN',
      'biometricEnabled',
      'sessionTimeout',
      'maxSessions'
    ];

    if (!allowedFields.includes(field)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid security field'
      });
    }

    // Handle nested updates
    const parts = field.split('.');
    if (parts.length === 2) {
      settings.security[parts[0]][parts[1]] = value;
    } else {
      settings.security[field] = value;
    }

    await settings.save();

    res.json({
      success: true,
      message: 'Security settings updated',
      data: settings.security
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/settings/security/2fa
 * Enable/disable 2FA
 */
router.post('/security/2fa', async (req, res) => {
  try {
    const { enable, method } = req.body;
    let settings = await Settings.getOrCreate(req.user.id);

    settings.security.twoFactorEnabled = enable;
    settings.security.twoFactorMethod = enable ? method : 'none';

    await settings.save();

    res.json({
      success: true,
      message: enable ? '2FA enabled' : '2FA disabled',
      data: {
        twoFactorEnabled: settings.security.twoFactorEnabled,
        twoFactorMethod: settings.security.twoFactorMethod
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/settings/security/device
 * Add trusted device
 */
router.post('/security/device', async (req, res) => {
  try {
    const { deviceId, deviceName, deviceToken } = req.body;

    if (!deviceId || !deviceName) {
      return res.status(400).json({
        success: false,
        error: 'Device ID and name are required'
      });
    }

    let settings = await Settings.getOrCreate(req.user.id);

    await settings.addTrustedDevice({ deviceId, deviceName, deviceToken });

    res.json({
      success: true,
      message: 'Device added successfully',
      data: settings.security.trustedDevices
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * DELETE /api/v1/settings/security/device/:deviceId
 * Remove trusted device
 */
router.delete('/security/device/:deviceId', async (req, res) => {
  try {
    let settings = await Settings.getOrCreate(req.user.id);

    settings.security.trustedDevices = settings.security.trustedDevices.filter(
      d => d.deviceId !== req.params.deviceId
    );

    await settings.save();

    res.json({
      success: true,
      message: 'Device removed',
      data: settings.security.trustedDevices
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/settings/privacy
 * Update privacy settings
 */
router.patch('/privacy', async (req, res) => {
  try {
    const { field, value } = req.body;

    let settings = await Settings.getOrCreate(req.user.id);

    const allowedFields = [
      'showOnLeaderboard',
      'showInvestmentPortfolio',
      'allowReferralTracking',
      'dataSharing'
    ];

    if (!allowedFields.includes(field)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid privacy field'
      });
    }

    settings.privacy[field] = value;
    await settings.save();

    res.json({
      success: true,
      message: 'Privacy settings updated',
      data: settings.privacy
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/settings/display
 * Update display preferences
 */
router.patch('/display', async (req, res) => {
  try {
    const { currency, language, timezone, dateFormat, theme, compactMode } = req.body;

    let settings = await Settings.getOrCreate(req.user.id);

    if (currency) settings.display.currency = currency;
    if (language) settings.display.language = language;
    if (timezone) settings.display.timezone = timezone;
    if (dateFormat) settings.display.dateFormat = dateFormat;
    if (theme) settings.display.theme = theme;
    if (compactMode !== undefined) settings.display.compactMode = compactMode;

    await settings.save();

    res.json({
      success: true,
      message: 'Display settings updated',
      data: settings.display
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/settings/limits
 * Update transaction limits
 */
router.patch('/limits', async (req, res) => {
  try {
    const { field, value } = req.body;

    let settings = await Settings.getOrCreate(req.user.id);

    const allowedFields = [
      'dailyWithdrawal',
      'singleWithdrawal',
      'dailyTransfer',
      'requirePIN'
    ];

    if (!allowedFields.includes(field)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid limit field'
      });
    }

    settings.limits[field] = value;
    await settings.save();

    res.json({
      success: true,
      message: 'Limits updated',
      data: settings.limits
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/settings/saved
 * Update saved preferences
 */
router.patch('/saved', async (req, res) => {
  try {
    const { defaultPaymentMethod, defaultSavingsFrequency, autoInvestPercentage, preferredInvestmentDuration } = req.body;

    let settings = await Settings.getOrCreate(req.user.id);

    if (defaultPaymentMethod) settings.saved.defaultPaymentMethod = defaultPaymentMethod;
    if (defaultSavingsFrequency) settings.saved.defaultSavingsFrequency = defaultSavingsFrequency;
    if (autoInvestPercentage !== undefined) settings.saved.autoInvestPercentage = autoInvestPercentage;
    if (preferredInvestmentDuration) settings.saved.preferredInvestmentDuration = preferredInvestmentDuration;

    await settings.save();

    res.json({
      success: true,
      message: 'Saved preferences updated',
      data: settings.saved
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/settings/onboarding-complete
 * Mark onboarding as complete
 */
router.post('/onboarding-complete', async (req, res) => {
  try {
    let settings = await Settings.getOrCreate(req.user.id);
    settings.onboardingCompleted = true;
    await settings.save();

    res.json({
      success: true,
      message: 'Onboarding marked as complete'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * DELETE /api/v1/settings
 * Reset settings to defaults
 */
router.delete('/', async (req, res) => {
  try {
    await Settings.deleteOne({ user: req.user.id });

    res.json({
      success: true,
      message: 'Settings reset to defaults'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
