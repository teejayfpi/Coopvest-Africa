/**
 * KYC Routes
 * 
 * Know Your Customer verification endpoints
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { User, KYC } = require('../models');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

/**
 * GET /api/v1/kyc/status
 * Get KYC status for current user
 */
router.get('/status', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    let kyc = await KYC.findOne({ userId });

    if (!kyc) {
      // Return basic status from user model
      const user = await User.findOne({ userId });
      return res.json({
        success: true,
        kyc: {
          status: 'not_started',
          completionPercentage: 0,
          personalInfo: user?.kyc?.verified || false,
          documents: [],
          selfie: null
        }
      });
    }

    res.json({
      success: true,
      kyc: {
        status: kyc.status,
        completionPercentage: kyc.completionPercentage || 0,
        verificationLevel: kyc.verificationLevel,
        personalInfo: kyc.personalInfo.firstName ? true : false,
        contactInfo: kyc.contactInfo.address.street ? true : false,
        employment: kyc.employment.status ? true : false,
        bankInfo: kyc.bankInfo.accountNumber ? true : false,
        documents: kyc.documents.length,
        selfie: kyc.selfie.imageUrl ? true : false,
        verifiedAt: kyc.verifiedAt,
        submittedAt: kyc.submittedAt
      }
    });
  } catch (error) {
    logger.error('Get KYC status error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/kyc/submit
 * Submit KYC data
 */
router.post('/submit', authenticate, [
  body('personalInfo').isObject(),
  body('contactInfo').isObject(),
  body('employment').isObject(),
  body('bankInfo').isObject()
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { personalInfo, contactInfo, employment, bankInfo } = req.body;

    let kyc = await KYC.findOne({ userId });

    if (!kyc) {
      kyc = new KYC({ userId });
    }

    kyc.personalInfo = { ...kyc.personalInfo, ...personalInfo };
    kyc.contactInfo = { ...kyc.contactInfo, ...contactInfo };
    kyc.employment = { ...kyc.employment, ...employment };
    kyc.bankInfo = { ...kyc.bankInfo, ...bankInfo };
    kyc.status = 'submitted';
    kyc.submittedAt = new Date();

    await kyc.save();

    // Update user KYC status
    await User.findOneAndUpdate(
      { userId },
      { $set: { 'kyc.verified': false } }
    );

    res.json({
      success: true,
      message: 'KYC submitted for verification',
      completionPercentage: kyc.completionPercentage
    });
  } catch (error) {
    logger.error('Submit KYC error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/kyc/document
 * Upload KYC document
 */
router.post('/document', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { type, documentNumber, expiryDate, frontImageUrl, backImageUrl } = req.body;

    let kyc = await KYC.findOne({ userId });

    if (!kyc) {
      kyc = new KYC({ userId });
    }

    const newDocument = {
      type,
      documentNumber,
      expiryDate: expiryDate ? new Date(expiryDate) : null,
      frontImageUrl,
      backImageUrl,
      uploadedAt: new Date(),
      status: 'pending'
    };

    kyc.documents.push(newDocument);
    await kyc.save();

    res.json({
      success: true,
      message: 'Document uploaded successfully',
      documentCount: kyc.documents.length
    });
  } catch (error) {
    logger.error('Upload document error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/kyc/selfie
 * Upload selfie for verification
 */
router.post('/selfie', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { imageUrl } = req.body;

    let kyc = await KYC.findOne({ userId });

    if (!kyc) {
      kyc = new KYC({ userId });
    }

    kyc.selfie = {
      imageUrl,
      uploadedAt: new Date(),
      status: 'pending'
    };

    await kyc.save();

    res.json({
      success: true,
      message: 'Selfie uploaded successfully'
    });
  } catch (error) {
    logger.error('Upload selfie error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/kyc/documents
 * Get uploaded documents
 */
router.get('/documents', authenticate, async (req, res) => {
  try {
    const userId = req.user.userId;

    const kyc = await KYC.findOne({ userId });

    if (!kyc) {
      return res.json({
        success: true,
        documents: []
      });
    }

    const documents = kyc.documents.map(doc => ({
      type: doc.type,
      status: doc.status,
      uploadedAt: doc.uploadedAt,
      verifiedAt: doc.verifiedAt
    }));

    res.json({
      success: true,
      documents
    });
  } catch (error) {
    logger.error('Get documents error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PUT /api/v1/kyc/bank
 * Update bank information
 */
router.put('/bank', authenticate, [
  body('bankName').notEmpty(),
  body('accountNumber').isLength({ min: 10, max: 10 }),
  body('accountName').notEmpty(),
  body('bvn').isLength({ min: 11, max: 11 })
], validate, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { bankName, accountNumber, accountName, accountType, bvn } = req.body;

    let kyc = await KYC.findOne({ userId });

    if (!kyc) {
      kyc = new KYC({ userId });
    }

    kyc.bankInfo = {
      bankName,
      accountNumber,
      accountName,
      accountType: accountType || 'savings',
      bvn,
      bankVerificationVerified: false
    };

    await kyc.save();

    res.json({
      success: true,
      message: 'Bank information updated'
    });
  } catch (error) {
    logger.error('Update bank info error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
