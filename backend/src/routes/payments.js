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

const PAYSTACK_BASE = 'https://api.paystack.co';
const MIN_AMOUNT_NGN = 100;

// UI allocation choices accepted by /initialize. The DB proof row uses the
// legacy payment_proofs.payment_type CHECK set (see 007_payment_proofs.sql),
// so fine/fee/mixed are stored as `other` with the full breakdown in metadata.
const ALLOWED_PAYMENT_TYPES = new Set([
  'monthly_contribution',
  'loan_repayment',
  'registration_fee',
  'investment',
  'other',
  'fine',
  'fee',
  'mixed',
]);

// payment_proofs.payment_type CHECK-compatible storage type for a UI choice.

const DB_PAYMENT_TYPE = {
  monthly_contribution: 'monthly_contribution',
  loan_repayment: 'loan_repayment',
  registration_fee: 'registration_fee',
  investment: 'investment',
  other: 'other',
  fine: 'other',
  fee: 'other',
  mixed: 'other',
};

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

  // Apply the allocation breakdown (savings/loan/fines/fees) for every
  // instant type — straight monthly proofs reuse the DB trigger for savings,
  // while loan/fine/fee/mixed need this loop (rare non-fatal failures are
  // logged inside applyAllocations, never block the approval).
  await applyAllocations(proof);


  // Confirm the charge to the member in realtime — the app's in-app WebView
  // poll usually sees the success, but this push/in-app notification covers
  // weak-network handoffs where the poll fails or the app was backgrounded, so
  // the member still gets an explicit auto-confirmation (and the wallet/status
  // screens can refresh via the realtime notification listener).
  try {
    await notifyService.notifyPaymentProofApproved({
      profileId: proof.profile_id,
      amount: proof.amount,
      paymentType: proof.payment_type,
      transactionReference: proof.transaction_reference,
    });
    logger.info(`paystack settle: confirmation sent to ${proof.profile_id} (proof ${proof.id})`);
  } catch (notifyErr) {
    logger.warn(`paystack settle: confirmation notification failed (non-fatal): ${notifyErr.message}`);
  }

  logger.info(`paystack settle: proof ${proof.id} approved (reference ${reference})`);
  return { settled: true, already: false, proof };
}

/**
 * Normalize the mobile app's allocation choice into the same breakdown the
 * manual /wallet/contribute path produces (see wallet.js. This is what the
 * instant Paystack settlement applies (savings→wallet credit, loan_repayment
 * →loan reduction,and fine/fee/registration_fee→member_fees settlement).
 */
function normalizeAllocations(amount, allocationType, allocations) {
  const type = allocationType || (Array.isArray(allocations) && allocations.length ? 'mixed' : 'monthly_contribution');
  if (Array.isArray(allocations) && allocations.length > 0) {
    return allocations.map((a) => ({
      type: String(a.type || '').replace(/[^a-z_]/gi, '').toLowerCase(),
      amount: Number(a.amount) || 0,
      loan_id: a.loan_id || null,
      fee_id: a.fee_id || null,
    })).filter((a) => a.amount > 0);
  }
  if (type === 'monthly_contribution') {
    return [{ type: 'savings', amount: Number(amount) }];
  }
  if (type === 'loan_repayment') {
    return [{ type: 'loan_repayment', amount: Number(amount) }];
  }
  if (type === 'mixed') {
    return [];
  }
  return [{ type, amount: Number(amount) }];
}

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
    const allocations = Array.isArray(metadata.allocations) && metadata.allocations.length
      ? metadata.allocations
      : normalizeAllocations(Number(proof.amount) || 0, allocationType, null);
    const savingsAmt = allocations.reduce((s, a) => s + (a.type === 'savings' ? a.amount : 0), 0);
    const loanAmt = allocations.reduce((s, a) => s + (a.type === 'loan_repayment' ? a.amount : 0), 0);
    const feeAllocs = allocations.filter((a) => ['fine', 'fee', 'registration_fee'].includes(a.type));

    // 1. Savings → credit the wallet (skip when the DB trigger already did
    // it for straight monthly_contribution proofs).
    if (savingsAmt > 0 && proof.payment_type !== 'monthly_contribution') {

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
        const { data: memberLoans } = await supabase
          .from('loans')
          .select('id, loan_id, remaining_balance, total_repayment, status')
          .eq('profile_id', proof.profile_id)
          .in('status', ['active', 'approved'])
          .order('remaining_balance', { ascending: false, nullsFirst: false })
          .limit(1);
        const targetLoan = (memberLoans && memberLoans[0]) || null;
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
  ],
  validate,
  async (req, res) => {
    try {
      const amountNgn = Number(req.body.amount);
      const paymentType = ALLOWED_PAYMENT_TYPES.has(req.body.payment_type)
        ? req.body.payment_type
        : 'monthly_contribution';
      const allocations = normalizeAllocations(amountNgn, req.body.allocation_type, req.body.allocations);
      const allocationType = req.body.allocation_type || (Array.isArray(req.body.allocations) && req.body.allocations.length ? 'mixed' : paymentType);
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
