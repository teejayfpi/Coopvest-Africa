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

const PAYSTACK_BASE = 'https://api.paystack.co';
const MIN_AMOUNT_NGN = 100;

// Map app allocation choices onto payment_proofs.payment_type values.
const ALLOWED_PAYMENT_TYPES = new Set([
  'monthly_contribution',
  'registration_fee',
  'investment',
  'other',
]);

function secretKey() {
  return process.env.PAYSTACK_SECRET_KEY || null;
}

async function paystackFetch(path, options = {}) {
  const key = secretKey();
  if (!key) {
    const err = new Error('Paystack is not configured on the server.');
    err.statusCode = 503;
    throw err;
  }
  const response = await fetch(`${PAYSTACK_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const payload = await response.json().catch(() => ({}));
  return { ok: response.ok, status: response.status, payload };
}

/**
 * Record a Paystack deposit as an approved payment proof so the existing
 * approval trigger (savings credit, transaction row, digital receipt) runs
 * through the exact same path as an admin-approved manual deposit.
 * Idempotent: a proof already approved for this reference is left alone.
 */
async function settleSuccessfulCharge(reference) {
  const { data: proof, error } = await supabase
    .from('payment_proofs')
    .select('*')
    .eq('transaction_reference', reference)
    .is('deleted_at', null)
    .maybeSingle();
  if (error) throw error;
  if (!proof) {
    logger.warn(`paystack settle: no payment proof parked for reference ${reference}`);
    return { settled: false, reason: 'no_proof' };
  }
  if (proof.status === 'approved') {
    return { settled: true, already: true, proof };
  }

  const now = new Date().toISOString();
  const { error: updErr } = await supabase
    .from('payment_proofs')
    .update({
      status: 'approved',
      approved_at: now,
      // approved_by stays null — settled by the gateway, not an admin.
      admin_notes: 'Auto-approved via Paystack charge confirmation.',
      updated_at: now,
    })
    .eq('id', proof.id);
  if (updErr) throw updErr;

  // Registration fee → flip the activation flag (same effect as the admin
  // approval handler; the DB trigger itself only writes the receipt).
  if (proof.payment_type === 'registration_fee') {
    await supabase
      .from('profiles')
      .update({
        registration_fee_paid: true,
        registration_fee_paid_at: now,
        registration_completed: true,
        updated_at: now,
      })
      .eq('id', proof.profile_id);
    await supabase
      .from('member_fees')
      .update({ status: 'paid', paid_at: now, deposit_id: proof.id })
      .eq('profile_id', proof.profile_id)
      .eq('fee_type', 'registration_fee')
      .eq('status', 'outstanding');
  }

  logger.info(`paystack settle: proof ${proof.id} approved (reference ${reference})`);
  return { settled: true, already: false, proof };
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
  ],
  validate,
  async (req, res) => {
    try {
      const amountNgn = Number(req.body.amount);
      const paymentType = ALLOWED_PAYMENT_TYPES.has(req.body.payment_type)
        ? req.body.payment_type
        : 'monthly_contribution';

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
        payment_type: paymentType,
        amount: amountNgn,
        currency: 'NGN',
        payment_date: new Date().toISOString().slice(0, 10),
        receiving_bank: 'Paystack',
        transaction_reference: reference,
        status: 'pending',
        metadata: { gateway: 'paystack', source: 'mobile_app' },
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
