/**
 * Paystack Payments
 *
 * Live in-app deposits (card / bank transfer / USSD) via Paystack:
 *
 *   POST /api/v1/payments/initialize   — member starts a deposit; we create
 *       a Paystack transaction and park a pending payment_proofs row keyed by
 *       the Paystack reference.
 *   GET  /api/v1/payments/verify/:reference — the app calls this when the
 *       member returns from the Paystack checkout page. On success the parked
 *       proof is flipped to approved — the payment_proofs DB trigger then
 *       credits savings, writes the transaction and issues the receipt.
 *   POST /api/v1/payments/webhook — Paystack server-to-server confirmation
 *       (HMAC-SHA512 signature verified). Same crediting path; this is the
 *       authoritative channel, verify is the UX fallback.
 *
 * Registration-fee payments additionally flip the activation flag (mirrors
 * the admin payment-proof approval handler).
 */

const crypto = require('crypto');
const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');
const { ALLOWED_PAYMENT_TYPES, DB_PAYMENT_TYPE, normalizeAllocations } = require('../lib/allocations');

const PAYSTACK_BASE = 'https://api.paystack.co';
const MIN_AMOUNT_NGN = 100;

/**
 * Apply the allocations of an auto-approved Paystack charge (mirrors the
 * admin deposit-verification handler: PATCH /api/admin/deposits/:id/verify).
 * Savings credits the wallet, loan_repayment reduces the member's loan,and
 * fine/fee/registration_fee settle outstanding member_fees obligations.

 * Idempotent: loan payments are keyed by `reference` (this proof id)and
 * fee settlement flips member_fees.status → paid only once.

 * The DB trigger already handles monthly_contribution proofs (contribution +
 * savings credit), so we skip the savings leg for that stored type to avoid
 * double-crediting. For `other`-stored proofs (fine/fee/mixed) the
 * trigger creates only a receipt/transaction row — we apply everything here.


 * NOTE: registration_fee is settled separately in settleSuccessfulCharge
 * above (flips the activation flag + member_fees for the registration fee). This
 * helper handles the remaining allocation types.

 */
async function applyAllocations(proof, { recordedBy = null } = {}) {
  if (!proof || !proof.id) return;
  try {
    const metadata = (proof.metadata || {});
    const allocationType = metadata.allocation_type || 'monthly_contribution';
    // Derive the breakdown from the STORED payment type, not the allocation
    // label: an approved registration_fee/loan_repayment proof must never be
    // re-interpreted as savings (that credited registration fees and loan
    // repayments straight into member wallets).
    const derivedType = proof.payment_type === 'monthly_contribution'
      ? 'monthly_contribution'
      : (proof.allocation_type || allocationType);
    const allocations = Array.isArray(metadata.allocations) && metadata.allocations.length
      ? metadata.allocations
      : normalizeAllocations(Number(proof.amount) || 0, derivedType, null);
    const savingsAmt = allocations.reduce((s, a) => s + (a.type === 'savings' ? a.amount : 0), 0);
    const loanAmt = allocations.reduce((s, a) => s + (a.type === 'loan_repayment' ? a.amount : 0), 0);
    const feeAllocs = allocations.filter((a) => ['fine', 'fee', 'registration_fee'].includes(a.type));

    // 1. Savings → credit the wallet (skip when the DB trigger already did
    // it for straight monthly_contribution proofs, and never for a
    // registration_fee proof — that is a fee, not a member saving).
    if (savingsAmt > 0
      && proof.payment_type !== 'monthly_contribution'
      && proof.payment_type !== 'registration_fee') {

      const { ensureWallet } = require('./wallet');
      const wallet = await ensureWallet(proof.profile_id);
      if (wallet && wallet.id) {
        await supabase
          .from('wallets')
          .update({ balance: Number(wallet.balance) + savingsAmt, last_updated: new Date().toISOString() })
          .eq('id', wallet.id);
        logger.info(`paystack settle: saved ₦${savingsAmt} wallet credit → ${wallet.id} (proof ${proof.id})`);
      }
    }

    // 2. Loan repayment → reduce the active loan balance (same idempotent
    // guard as the admin proof-approval handler: keyed by reference = proof.id).

    if (loanAmt > 0) {
      const { data: alreadyApplied } = await supabase
        .from('loan_repayments')
        .select('id')
        .eq('reference', proof.id)
        .maybeSingle();
      if (!alreadyApplied) {
        // Prefer an explicitly targeted loan (loan_id from the allocation),
        // otherwise fall back to the member's active loan with the highest
        // remaining balance.
        const loanAlloc = allocations.find((a) => a.type === 'loan_repayment');
        const targetedLoanId = loanAlloc?.loan_id || null;
        let targetLoan = null;
        if (targetedLoanId) {
          const { data: targeted } = await supabase
            .from('loans')
            .select('id, loan_id, remaining_balance, total_repayment, status')
            .eq('id', targetedLoanId)
            .in('status', ['active', 'approved', 'repaying'])
            .maybeSingle();
          if (targeted) targetLoan = targeted;
        }
        if (!targetLoan) {
          const { data: memberLoans } = await supabase
            .from('loans')
            .select('id, loan_id, remaining_balance, total_repayment, status')
            .eq('profile_id', proof.profile_id)
            .in('status', ['active', 'approved', 'repaying'])
            .order('remaining_balance', { ascending: false, nullsFirst: false })
            .limit(1);
          targetLoan = (memberLoans && memberLoans[0]) || null;
        }
        if (targetLoan) {
          const now = new Date().toISOString();
          const currentBal = parseFloat(targetLoan.remaining_balance ?? targetLoan.total_repayment ?? 0) || 0;
          const newBalance = Math.max(0, currentBal - loanAmt);
          const loanUpdate = {
            remaining_balance: newBalance,
            updated_at: now,
          };
          if (newBalance <= 0) {
            loanUpdate.status = 'completed';
            loanUpdate.remaining_months = 0;
          }
          await supabase.from('loans').update(loanUpdate).eq('id', targetLoan.id);
          await supabase.from('loan_repayments').insert({
            loan_id: targetLoan.id,
            profile_id: proof.profile_id,
            amount: loanAmt,
            paid_at: now,
            status: 'paid',
            reference: proof.id,
            recorded_by: recordedBy || null,
          });
          logger.info(`paystack settle: loan repayment ₦${loanAmt} → ${targetLoan.loan_id || targetLoan.id} (proof ${proof.id})`);
        } else {
          logger.warn(`paystack settle: loan repayment proof ${proof.id} but no active/approved loan to apply it to`);
        }
      }
    }

    // 3. Fines / fees → settle outstanding member_fees obligations.



    for (const alloc of feeAllocs) {
      const amt = Number(alloc.amount) || 0;
      if (amt <= 0) continue;
      let feeRow = null;
      if (alloc.fee_id) {
        const { data } = await supabase
          .from('member_fees')
          .select('*')
          .eq('id', alloc.fee_id)
          .maybeSingle();
        if (data && data.status === 'outstanding') feeRow = data;
      }
      if (!feeRow) {
        const { data } = await supabase
          .from('member_fees')
          .select('*')
          .eq('profile_id', proof.profile_id)
          .eq('status', 'outstanding')
          .eq('fee_type', alloc.type === 'registration_fee' ? 'registration_fee' : alloc.type)
          .order('created_at', { ascending: true })
          .limit(1)
          .maybeSingle();
        feeRow = data;
      }
      if (feeRow) {
        await supabase
          .from('member_fees')
          .update({ status: 'paid', paid_at: new Date().toISOString(), deposit_id: proof.id, updated_at: new Date().toISOString() })
          .eq('id', feeRow.id);
        logger.info(`paystack settle: fee ${alloc.type} ₦${amt} settled (proof ${proof.id})`);
      }
    }
  } catch (err) {
    logger.warn(`paystack settle: applyAllocations error (non-fatal): ${err.message}`);
  }
}

/**
 * POST /api/v1/payments/initialize
 * Body: { amount, payment_type } → { authorization_url, reference }
 */
router.post(
  '/initialize',
  authenticate,
  [
    body('amount').isFloat({ min: MIN_AMOUNT_NGN }),
    body('payment_type').optional().isString(),
    body('allocation_type').optional().isIn(['monthly_contribution', 'loan_repayment', 'fine', 'fee', 'registration_fee', 'mixed']),
    body('allocations').optional().isArray(),
    body('loan_id').optional().isString(),
  ],
  validate,
  async (req, res) => {
    try {
      const amountNgn = Number(req.body.amount);
      const paymentType = ALLOWED_PAYMENT_TYPES.has(req.body.payment_type)
        ? req.body.payment_type
        : 'monthly_contribution';
      const requestedAllocation = req.body.allocation_type || paymentType;
      const allocations = normalizeAllocations(amountNgn, requestedAllocation, req.body.allocations)
        // Carry an explicitly targeted loan into the loan_repayment allocation
        // so settlement reduces THAT loan rather than the highest-balance one.
        .map((a) => (a.type === 'loan_repayment' && req.body.loan_id && !a.loan_id
          ? { ...a, loan_id: req.body.loan_id }
          : a));
      const allocationType = requestedAllocation;
      const dbPaymentType = (DB_PAYMENT_TYPE[paymentType] || 'other');

      const reference = `CVP-${req.user.id.slice(0, 8)}-${Date.now()}`;
      const { ok, status, payload } = await paystackFetch('/transaction/initialize', {
        method: 'POST',
        body: JSON.stringify({
          email: req.user.email,
          amount: Math.round(amountNgn * 100), // kobo
          reference,
          currency: 'NGN',
          metadata: {
            profile_id: req.user.id,
            payment_type: paymentType,
            allocation_type: allocationType,
            allocations,
            source: 'mobile_app',
          },
        }),
      });
      if (!ok || !payload.status) {
        logger.error(`paystack initialize failed (${status}): ${payload.message}`);
        return res.status(502).json({
          success: false,
          error: payload.message || 'Could not start the payment. Please try again.',
        });
      }

      // Park the pending proof; verify/webhook flips it to approved and the
      // DB trigger does the financial posting. payment_method: prefer
      // 'paystack' (migration 025), fall back to 'card' on the CHECK constraint.
      const baseRow = {
        profile_id: req.user.id,
        payment_type: dbPaymentType,
        amount: amountNgn,
        currency: 'NGN',
        payment_date: new Date().toISOString().slice(0, 10),
        receiving_bank: 'Paystack',
        transaction_reference: reference,
        status: 'pending',
        metadata: {
          gateway: 'paystack',
          source: 'mobile_app',
          allocation_type: allocationType,
          allocations,
          ...(req.body.loan_id ? { loan_id: req.body.loan_id } : {}),
        },
      };
      let { error: insertErr } = await supabase
        .from('payment_proofs')
        .insert({ ...baseRow, payment_method: 'paystack' });
      if (insertErr && insertErr.code === '23514') {
        ({ error: insertErr } = await supabase
          .from('payment_proofs')
          .insert({ ...baseRow, payment_method: 'card' }));
      }
      if (insertErr) throw insertErr;

      res.json({
        success: true,
        authorization_url: payload.data.authorization_url,
        reference,
      });
    } catch (err) {
      logger.error('paystack initialize error:', err);
      res.status(err.statusCode || 500).json({ success: false, error: err.message });
    }
  }
);

/**
 * GET /api/v1/payments/verify/:reference
 * Called by the app after the member returns from the Paystack checkout.
 */
router.get(
  '/verify/:reference',
  authenticate,
  [param('reference').isString().isLength({ min: 6, max: 100 })],
  validate,
  async (req, res) => {
    try {
      const { reference } = req.params;

      // Members may only poll their own references.
      if (!reference.startsWith(`CVP-${req.user.id.slice(0, 8)}-`)) {
        return res.status(403).json({ success: false, error: 'Not your payment reference.' });
      }

      const { ok, payload } = await paystackFetch(`/transaction/verify/${encodeURIComponent(reference)}`);
      if (!ok || !payload.status) {
        return res.status(502).json({ success: false, error: 'Could not confirm the payment yet.' });
      }

      const paid = payload.data?.status === 'success';
      if (paid) {
        const result = await settleSuccessfulCharge(reference);
        return res.json({ success: true, status: 'success', settled: result.settled });
      }
      res.json({ success: true, status: payload.data?.status || 'pending' });
    } catch (err) {
      logger.error('paystack verify error:', err);
      res.status(err.statusCode || 500).json({ success: false, error: err.message });
    }
  }
);

/**
 * POST /api/v1/payments/webhook
 * Paystack server-to-server events. Requires the raw body (see server.js)
 * for the HMAC-SHA512 signature check. No auth middleware — Paystack calls
 * this directly.
 */
router.post('/webhook', async (req, res) => {
  try {
    const key = secretKey();
    if (!key) return res.sendStatus(503);

    const raw = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));
    const signature = req.headers['x-paystack-signature'];
    const expected = crypto.createHmac('sha512', key).update(raw).digest('hex');
    if (!signature || signature !== expected) {
      logger.warn('paystack webhook: signature mismatch — rejected');
      return res.sendStatus(401);
    }

    const event = req.body || {};
    if (event.event === 'charge.success' && event.data?.reference) {
      await settleSuccessfulCharge(event.data.reference);
    }
    res.sendStatus(200);
  } catch (err) {
    logger.error('paystack webhook error:', err);
    // 200 anyway — a 5xx would make Paystack retry a charge we may have
    // already settled (settleSuccessfulCharge is idempotent, but keep the
    // noise down).
    res.sendStatus(200);
  }
});

module.exports = router;
