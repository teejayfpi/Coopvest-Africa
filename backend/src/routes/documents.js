/**
 * Documents Routes
 *
 * KYC document uploads and status tracking.
 * Files are stored in Supabase Storage; metadata lives in `documents`.
 *
 * Flutter endpoints used by DocumentApiService:
 *   GET    /documents/my-documents    — list user's documents
 *   GET    /documents/required        — list required KYC document types
 *   GET    /documents/kyc-status      — overall KYC completion status
 *   GET    /documents/pending-count   — count of pending/unreviewed docs
 *   GET    /documents/:id             — single document metadata
 *   POST   /documents/upload          — multipart upload
 *   DELETE /documents/:id             — delete pending document
 */

const express = require('express');
const { param } = require('express-validator');
const router = express.Router();
const multer = require('multer');

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');

router.use(authenticate);

const REQUIRED_DOCUMENT_TYPES = [
  'national_id',
  'proof_of_address',
  'passport_photo',
  'employment_letter',
];

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'application/pdf'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE },
  fileFilter: (req, file, cb) => {
    if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Allowed: JPG, PNG, PDF'), false);
    }
  },
});

/**
 * GET /api/v1/documents/required
 * Must be defined before /:id to avoid route collision.
 */
router.get('/required', (req, res) => {
  res.json({ success: true, types: REQUIRED_DOCUMENT_TYPES });
});

/**
 * GET /api/v1/documents/my-documents
 */
router.get('/my-documents', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('documents')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, documents: data || [] });
  } catch (err) {
    logger.error('documents my-documents error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * GET /api/v1/documents/kyc-status
 */
router.get('/kyc-status', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('documents')
      .select('id, document_type, status')
      .eq('profile_id', req.user.id);
    if (error) throw error;

    const docs = data || [];
    const submittedTypes = new Set(docs.map((d) => d.document_type));
    const approvedTypes = new Set(
      docs.filter((d) => d.status === 'approved').map((d) => d.document_type)
    );
    const missingTypes = REQUIRED_DOCUMENT_TYPES.filter((t) => !submittedTypes.has(t));

    res.json({
      success: true,
      isComplete: missingTypes.length === 0 && approvedTypes.size >= REQUIRED_DOCUMENT_TYPES.length,
      submittedCount: submittedTypes.size,
      approvedCount: approvedTypes.size,
      requiredCount: REQUIRED_DOCUMENT_TYPES.length,
      missingTypes,
    });
  } catch (err) {
    logger.error('documents kyc-status error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * GET /api/v1/documents/pending-count
 */
router.get('/pending-count', async (req, res) => {
  try {
    const { count, error } = await supabase
      .from('documents')
      .select('id', { count: 'exact', head: true })
      .eq('profile_id', req.user.id)
      .eq('status', 'pending');
    if (error) throw error;
    res.json({ success: true, count: count || 0 });
  } catch (err) {
    logger.error('documents pending-count error:', err);
    res.json({ success: true, count: 0 });
  }
});

/**
 * POST /api/v1/documents/upload
 */
router.post('/upload', upload.single('document'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file uploaded.' });
    }

    const { type, name } = req.body;
    if (!type) {
      return res.status(400).json({ success: false, message: 'Document type is required.' });
    }

    const ext = req.file.originalname.split('.').pop().toLowerCase();
    const storagePath = `documents/${req.user.id}/${Date.now()}-${type}.${ext}`;

    // Upload to Supabase Storage
    const { error: uploadError } = await supabase.storage
      .from('kyc-documents')
      .upload(storagePath, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: false,
      });

    if (uploadError) throw uploadError;

    const { data: { publicUrl } } = supabase.storage
      .from('kyc-documents')
      .getPublicUrl(storagePath);

    const { data: doc, error: insertError } = await supabase
      .from('documents')
      .insert({
        profile_id: req.user.id,
        document_type: type,
        name: name || req.file.originalname,
        file_url: publicUrl,
        storage_path: storagePath,
        file_size: req.file.size,
        mime_type: req.file.mimetype,
        status: 'pending',
      })
      .select('*')
      .single();

    if (insertError) throw insertError;

    res.status(201).json({
      success: true,
      message: 'Document uploaded successfully.',
      document: doc,
    });
  } catch (err) {
    logger.error('documents upload error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * GET /api/v1/documents/:id
 */
router.get('/:id', [param('id').notEmpty()], validate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('documents')
      .select('*')
      .eq('id', req.params.id)
      .eq('profile_id', req.user.id)
      .maybeSingle();

    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Document not found.' });

    res.json({ success: true, ...data });
  } catch (err) {
    logger.error('documents get error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * DELETE /api/v1/documents/:id
 * Only pending documents may be deleted.
 */
router.delete('/:id', [param('id').notEmpty()], validate, async (req, res) => {
  try {
    const { data, error: findErr } = await supabase
      .from('documents')
      .select('id, status, storage_path, profile_id')
      .eq('id', req.params.id)
      .maybeSingle();

    if (findErr) throw findErr;
    if (!data) return res.status(404).json({ success: false, message: 'Document not found.' });
    if (data.profile_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Not authorised.' });
    }
    if (data.status !== 'pending') {
      return res.status(400).json({ success: false, message: 'Only pending documents can be deleted.' });
    }

    // Remove from storage
    if (data.storage_path) {
      await supabase.storage.from('kyc-documents').remove([data.storage_path]).catch(() => {});
    }

    const { error } = await supabase.from('documents').delete().eq('id', data.id);
    if (error) throw error;

    res.json({ success: true, message: 'Document deleted.' });
  } catch (err) {
    logger.error('documents delete error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
