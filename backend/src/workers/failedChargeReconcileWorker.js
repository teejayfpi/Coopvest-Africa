/**
 * Reconcile Paystack charges that never reached a terminal state.
 *
 * The problem this solves: a card charge can fail after the member's bank has
 * authorised — or actually debited — the amount. The app shows the member an
 * indefinite "Payment not confirmed yet. If you were debited, it will reflect
 * shortly"; the parked `payment_proofs` row stays `pending`; and nothing in the
 * system records that money may have left their account. Support had no way to
 * tell "never paid" from "debited but not credited".
 *
 * The webhook (`charge.failed` / `transfer.reversed`) handles this in real
 * time. This sweep is the safety net for the cases a webhook cannot cover:
 *   * the webhook never arrived (endpoint down, signature mismatch, deploy),
 *   * the member abandoned checkout and closed the app,
 *   * Paystack reported a failure the webhook handler did not yet know about.
 *
 * For every stale `pending` proof it asks Paystack what actually happened and
 * records the truth: success → settle (credits the member exactly once, the
 * existing idempotent path); failed → mark failed + flag for admin follow-up.
 * A charge that is still genuinely awaiting payment is left alone.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const { verifyCharge } = require('../lib/paystackCharge');
const { recordFailedCharge } = require('../lib/failedChargeAudit');

const POLL_INTERVAL_MS = 30 * 60 * 1000; // every 30 minutes
const STARTUP_DELAY_MS = 3 * 60 * 1000;
const STALE_AFTER_MS = 20 * 60 * 1000; // only look at proofs older than 20 min
const MAX_PER_SWEEP = 40;

// Paystack terminal statuses that mean "no money will be collected".
// `abandoned` = the member closed the checkout without paying; there is no debit,
// so it is closed quietly rather than queued for refund.
const FAILED_STATUSES = new Set(['failed', 'reversed', 'abandoned']);

async function settleReference(reference) {
  // Lazy require: payments.js builds an express Router that pulls the auth
  // middleware, and loading it at module top would risk a cycle through
  // server.js. Deferring it to first use keeps startup order irrelevant.
  // eslint-disable-next-line global-require
  const { settleSuccessfulCharge } = require('../routes/payments');
  return settleSuccessfulCharge(reference);
}

async function reconcileProof(proof) {
  const reference = proof.transaction_reference;
  const { ok, gatewayStatus, data } = await verifyCharge(reference);

  // We could not reach Paystack, or it answered ambiguous — leave the proof
  // pending and retry on the next sweep. Never guess about money.
  if (!ok) return { outcome: 'unavailable' };

  if (gatewayStatus === 'success') {
    const result = await settleReference(reference);
    return { outcome: 'settled', already: result.already };
  }

  if (FAILED_STATUSES.has(gatewayStatus)) {
    const now = new Date().toISOString();
    await supabase
      .from('payment_proofs')
      .update({
        status: 'failed',
        failed_at: now,
        failure_reason: data?.gateway_response || gatewayStatus,
        updated_at: now,
      })
      .eq('id', proof.id)
      .eq('status', 'pending'); // guard against racing a webhook success

    // `reversed` proves the debit-and-reversal already happened, so it needs
    // the most urgent look; `failed`/`abandoned` are recorded so an admin can
    // cross-check the bank statement before deciding.
    await recordFailedCharge({
      profileId: proof.profile_id,
      reference,
      amount: proof.amount,
      gatewayStatus,
      gatewayMessage: data?.gateway_response || null,
      possibleDebit: gatewayStatus === 'reversed',
      payload: data || {},
    });
    return { outcome: gatewayStatus };
  }

  return { outcome: gatewayStatus || 'pending' };
}

async function processSweep() {
  try {
    const cutoff = new Date(Date.now() - STALE_AFTER_MS).toISOString();
    const { data: proofs, error } = await supabase
      .from('payment_proofs')
      .select('id, profile_id, amount, transaction_reference, payment_method, created_at')
      .eq('status', 'pending')
      .eq('payment_method', 'paystack')
      .is('deleted_at', null)
      .lt('created_at', cutoff)
      .not('transaction_reference', 'is', null)
      .order('created_at', { ascending: true })
      .limit(MAX_PER_SWEEP);
    if (error) throw error;
    if (!proofs || proofs.length === 0) return { checked: 0 };

    const tally = {};
    for (const proof of proofs) {
      try {
        const { outcome } = await reconcileProof(proof);
        tally[outcome] = (tally[outcome] || 0) + 1;
      } catch (err) {
        tally.error = (tally.error || 0) + 1;
        logger.warn(`failedChargeReconcileWorker: ${proof.transaction_reference} failed:`, err.message);
      }
    }
    logger.info(`failedChargeReconcileWorker: swept ${proofs.length} pending — ${JSON.stringify(tally)}`);
    return { checked: proofs.length, tally };
  } catch (err) {
    logger.warn('failedChargeReconcileWorker: sweep failed:', err.message);
    return { error: err.message };
  }
}

function start() {
  if (process.env.FAILED_CHARGE_RECONCILE_DISABLED === '1') {
    logger.info('failedChargeReconcileWorker: disabled via env');
    return null;
  }
  logger.info('failedChargeReconcileWorker: started (poll every 30 min)');
  const handle = setInterval(processSweep, POLL_INTERVAL_MS);
  setTimeout(() => processSweep().catch(() => {}), STARTUP_DELAY_MS);
  return handle;
}

module.exports = { start, processSweep, reconcileProof, FAILED_STATUSES };
