/**
 * KYC Routes
 *
 * Persists KYC state into Supabase tables `kyc` (one row per profile) and
 * `kyc_documents` (N uploaded documents per profile).
 */

const express = require('express');
const { body } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

async function getOrCreateKyc(profileId) {
  const { data, error } = await supabase
    .from('kyc')
    .select('*')
    .eq('profile_id', profileId)
    .maybeSingle();
  if (error) throw error;
  if (data) return data;

  const { data: created, error: cErr } = await supabase
    .from('kyc')
    .insert({ profile_id: profileId, status: 'pending' })
    .select('*')
    .single();
  if (cErr) throw cErr;
  return created;
}

/**
 * GET /api/v1/kyc/status
 */
router.get('/status', async (req, res) => {
  try {
    const kyc = await getOrCreateKyc(req.user.id);
    res.json({ success: true, kyc });
  } catch (err) {
    logger.error('kyc status error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/kyc/submit
 */
router.post(
  '/submit',
  [
    body('personalInfo').isObject(),
    body('address').optional().isObject(),
    body('employmentInfo').optional().isObject(),
  ],
  validate,
  async (req, res) => {
    try {
      const { personalInfo, address, employmentInfo, bvn, nin } = req.body;
      const kyc = await getOrCreateKyc(req.user.id);
      const { data, error } = await supabase
        .from('kyc')
        .update({
          personal_info: personalInfo,
          address: address || kyc.address,
          employment_info: employmentInfo || kyc.employment_info,
          bvn: bvn || kyc.bvn,
          nin: nin || kyc.nin,
          status: 'submitted',
          submitted_at: new Date().toISOString(),
        })
        .eq('id', kyc.id)
        .select('*')
        .single();
      if (error) throw error;
      res.json({ success: true, kyc: data });
    } catch (err) {
      logger.error('kyc submit error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * POST /api/v1/kyc/document
 */
router.post('/document', async (req, res) => {
  try {
    const { type, url, meta } = req.body || {};
    if (!type || !url) {
      return res.status(400).json({ success: false, error: 'type and url are required' });
    }
    await getOrCreateKyc(req.user.id);
    const { data, error } = await supabase
      .from('kyc_documents')
      .insert({ profile_id: req.user.id, type, url, meta: meta || {} })
      .select('*')
      .single();
    if (error) throw error;
    res.status(201).json({ success: true, document: data });
  } catch (err) {
    logger.error('kyc document error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/kyc/selfie
 */
router.post('/selfie', async (req, res) => {
  try {
    const { url } = req.body || {};
    if (!url) return res.status(400).json({ success: false, error: 'url is required' });
    const kyc = await getOrCreateKyc(req.user.id);
    const { data, error } = await supabase
      .from('kyc')
      .update({ selfie_url: url })
      .eq('id', kyc.id)
      .select('*')
      .single();
    if (error) throw error;
    res.json({ success: true, kyc: data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/kyc/documents
 */
router.get('/documents', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('kyc_documents')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, documents: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * PUT /api/v1/kyc/bank
 */
router.put(
  '/bank',
  [body('bankName').isString(), body('accountNumber').isString(), body('accountName').isString()],
  validate,
  async (req, res) => {
    try {
      const { bankName, accountNumber, accountName } = req.body;
      const kyc = await getOrCreateKyc(req.user.id);
      const { data, error } = await supabase
        .from('kyc')
        .update({
          bank_info: { bankName, accountNumber, accountName },
        })
        .eq('id', kyc.id)
        .select('*')
        .single();
      if (error) throw error;
      res.json({ success: true, kyc: data });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

module.exports = router;
