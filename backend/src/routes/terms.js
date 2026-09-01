/**
 * Terms Routes
 *
 * Serves the current Terms & Conditions document (version + sections) so the
 * legal text shown in the mobile app can be updated without an app release.
 * The document lives in config/terms.json — bump its `version` whenever the
 * text changes; the app records the version each member accepts.
 */

const express = require('express');
const router = express.Router();

const logger = require('../utils/logger');
const termsDocument = require('../config/terms.json');

/**
 * GET /api/v1/terms
 *
 * Public, non-sensitive legal content.
 */
router.get('/', (req, res) => {
  try {
    res.json({
      success: true,
      version: termsDocument.version,
      sections: termsDocument.sections,
    });
  } catch (err) {
    logger.error('terms fetch error:', err);
    res.status(500).json({ success: false, error: 'Could not load terms' });
  }
});

module.exports = router;
