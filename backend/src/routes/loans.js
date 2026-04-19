/**
 * Loans Routes
 *
 * All data is persisted in Supabase (`loans`, `loan_qrs`). Routes rely on
 * Supabase Auth JWT via the `authenticate` middleware, which resolves the
 * acting user's profile row.
 */

const express = require('express');
const { body, param, query } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { verifyLoanOwnership } = require('../middleware/ownership');
const referralService = require('../services/referralService');
const qrCodeService = require('../services/qrCodeService');
const logger = require('../utils/logger');

const LOAN_TYPES = ['Quick Loan', 'Micro Loan', 'Business Loan', 'Emergency Loan'];

const auditLog = async (actorId, action, targetId, metadata = {}) => {
  try {
    await supabase.from('audit_logs').insert({
      actor_id: actorId,
      action,
      target_model: 'Loan',
      target_id: targetId,
      metadata,
    });
  } catch (err) {
    logger.warn('audit_logs insert failed:', err.message);
  }
};

const newLoanId = () => `LN-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

/**
 * POST /api/v1/loans/apply
 */
router.post(
  '/apply',
  authenticate,
  [
    body('loanType').isIn(LOAN_TYPES),
    body('amount').isFloat({ min: 1 }),
    body('tenureMonths').isInt({ min: 1, max: 60 }),
    body('purpose').optional().isString().isLength({ max: 500 }),
    body('applyReferralBonus').optional().isBoolean(),
  ],
  validate,
  async (req, res) => {
    try {
      const { loanType, amount, tenureMonths, purpose, applyReferralBonus } = req.body;
      const profileId = req.user.id;

      let bonusPercent = 0;
      if (applyReferralBonus) {
        const { summary } = await referralService.getReferralSummary(profileId);
        bonusPercent = summary.isBonusAvailable ? summary.currentTierBonus : 0;
      }

      const calc = referralService.calculateInterestWithBonus(loanType, amount, tenureMonths, bonusPercent);

      const loanId = newLoanId();
      const insertPayload = {
        loan_id: loanId,
        profile_id: profileId,
        loan_type: loanType,
        amount,
        tenure_months: tenureMonths,
        purpose: purpose || null,
        base_interest_rate: calc.baseInterestRate,
        referral_bonus_percent: calc.referralBonusPercent,
        effective_interest_rate: calc.effectiveInterestRate,
        monthly_repayment: calc.monthlyRepaymentAfterBonus,
        total_repayment: calc.monthlyRepaymentAfterBonus * tenureMonths,
        savings_from_bonus: calc.totalSavingsFromBonus,
        status: 'pending',
      };

      const { data: loan, error } = await supabase
        .from('loans')
        .insert(insertPayload)
        .select('*')
        .single();
      if (error) throw error;

      let bonusResult = null;
      if (applyReferralBonus && bonusPercent > 0) {
        bonusResult = await referralService.applyBonusToLoan(profileId, loanId, loanType);
      }

      await auditLog(profileId, 'LOAN_APPLIED', loan.id, { loanType, amount, bonusPercent });

      res.status(201).json({
        success: true,
        loan,
        interest: calc,
        bonus: bonusResult,
      });
    } catch (err) {
      logger.error('Loan apply error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * POST /api/v1/loans/:loanId/generate-qr
 */
router.post(
  '/:loanId/generate-qr',
  authenticate,
  [param('loanId').notEmpty()],
  validate,
  verifyLoanOwnership,
  async (req, res) => {
    try {
      const { loanId } = req.params;
      const { applicantName, applicantPhone, options } = req.body;
      const loan = req.loan;

      const qrResult = await qrCodeService.generateLoanQRCode(
        {
          loanId,
          applicantId: req.user.id,
          applicantName: applicantName || req.user.name,
          applicantPhone,
          loanAmount: loan.amount,
          loanCurrency: 'NGN',
          loanTenure: loan.tenure_months,
          interestRate: loan.effective_interest_rate,
          monthlyRepayment: loan.monthly_repayment,
          totalRepayment: loan.total_repayment,
          purpose: loan.purpose,
        },
        options
      );

      const { data: qrRow, error } = await supabase
        .from('loan_qrs')
        .insert({
          qr_id: qrResult.qrData.qrId,
          loan_id: loan.id,
          applicant_id: req.user.id,
          applicant_name: applicantName || req.user.name,
          applicant_phone: applicantPhone,
          qr_data: qrResult.qrData,
          qr_code: qrResult.qrCode,
          signature: qrResult.qrData.signature,
          expires_at: qrResult.qrData.expiresAt,
          guarantors_required: 3,
          guarantors_found: 0,
        })
        .select('*')
        .single();
      if (error) throw error;

      await auditLog(req.user.id, 'LOAN_QR_GENERATED', loan.id, { qrId: qrRow.qr_id });

      res.status(201).json({
        success: true,
        message: qrResult.message,
        qr: {
          id: qrRow.qr_id,
          loanId,
          expiresAt: qrRow.expires_at,
          qrCode: qrRow.qr_code,
          data: qrRow.qr_data,
        },
        progress: { found: 0, required: 3, percentage: 0 },
      });
    } catch (err) {
      logger.error('QR generation error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/loans
 */
router.get('/', authenticate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('loans')
      .select('*')
      .eq('profile_id', req.user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    res.json({ success: true, loans: data || [], total: (data || []).length });
  } catch (err) {
    logger.error('Error getting loans:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/loans/qr-codes
 */
router.get(
  '/qr-codes',
  authenticate,
  [
    query('status').optional().isIn(['active', 'expired', 'all']),
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
  ],
  validate,
  async (req, res) => {
    try {
      const status = req.query.status || 'all';
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;

      let q = supabase
        .from('loan_qrs')
        .select('*', { count: 'exact' })
        .eq('applicant_id', req.user.id)
        .order('created_at', { ascending: false })
        .range((page - 1) * limit, page * limit - 1);

      if (status === 'active') q = q.gt('expires_at', new Date().toISOString());
      if (status === 'expired') q = q.lte('expires_at', new Date().toISOString());

      const { data, error, count } = await q;
      if (error) throw error;

      const qrCodes = (data || []).map((qr) => {
        const found = qr.guarantors_found || 0;
        const required = qr.guarantors_required || 3;
        return {
          ...qr,
          progress: {
            found,
            required,
            percentage: required > 0 ? Math.round((found / required) * 100) : 0,
            remaining: required - found,
          },
          isExpired: new Date() > new Date(qr.expires_at),
        };
      });

      res.json({
        success: true,
        qrCodes,
        pagination: { page, limit, total: count || 0 },
      });
    } catch (err) {
      logger.error('Error listing QR codes:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/loans/qr-stats
 */
router.get('/qr-stats', async (req, res) => {
  try {
    res.json({ success: true, stats: qrCodeService.getLoanQRStats?.() || {} });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/loans/:loanId
 */
router.get(
  '/:loanId',
  authenticate,
  [param('loanId').notEmpty()],
  validate,
  verifyLoanOwnership,
  async (req, res) => {
    res.json({ success: true, loan: req.loan });
  }
);

module.exports = router;
