/**
 * Audit + alert for gateway charges that failed after a possible debit.
 *
 * Two jobs, deliberately separated from the reconcile worker so both the
 * webhook and the sweep can share them:
 *
 *   1. Record the event in `payment_failed_charges` (idempotent on
 *      reference+status) so support has a permanent, queryable trail that money
 *      may have left a member's account.
 *   2. Alert the member ("if you were debited, you'll be refunded") and the
 *      admins (actionable) so a debited-but-failed charge is never silent.
 *
 * Nothing here credits or refunds — a human decides that, from the admin queue.
 * Automating a refund is a policy decision, not a bug fix.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');

/**
 * Persist a failed charge. Returns the row. Never throws — a failure to record
 * must not stop the caller from completing the state change it already made.
 */
async function recordFailedCharge({
  profileId,
  reference,
  amount,
  gatewayStatus,
  gatewayMessage = null,
  possibleDebit = false,
  payload = {},
}) {
  try {
    const { data, error } = await supabase
      .from('payment_failed_charges')
      .upsert(
        {
          profile_id: profileId || null,
          reference,
          amount: amount != null ? Number(amount) : null,
          gateway: 'paystack',
          gateway_status: gatewayStatus || 'failed',
          gateway_message: gatewayMessage,
          possible_debit: Boolean(possibleDebit),
          needs_followup: Boolean(possibleDebit),
          payload: payload || {},
        },
        { onConflict: 'reference,gateway_status', ignoreDuplicates: true },
      )
      .select()
      .maybeSingle();
    if (error) throw error;
    return data || null;
  } catch (err) {
    logger.warn(`failedChargeAudit: could not record ${reference} (${gatewayStatus}):`, err.message);
    return null;
  }
}

/**
 * Tell the member and the admins about a failed charge.
 *
 * The member copy avoids asserting they were debited (we usually cannot know
 * from the payload alone) but tells them what to do if they were. The admin
 * copy is actionable and carries the reference, which is the thing support
 * needs to trace it at the bank.
 */
async function alertFailedCharge({
  profileId,
  reference,
  amount,
  gatewayStatus,
  gatewayMessage = null,
  possibleDebit = false,
  alertAdmins = true,
}) {
  const amountFmt = `₦${Number(amount || 0).toLocaleString('en-NG')}`;
  const isReversal = gatewayStatus === 'reversed';

  try {
    if (profileId) {
      const body = isReversal || possibleDebit
        ? `Your payment of ${amountFmt} (ref ${reference}) did not go through and your bank may have debited you. If you were debited, it will be reversed automatically — no action is needed, but contact support if it is not reversed within 24 hours.`
        : `Your payment of ${amountFmt} (ref ${reference}) did not go through, so you have not been charged. You can try again whenever you are ready.`;
      await notifyService.broadcast({
        profileIds: [profileId],
        channels: ['in_app', 'push'],
        title: 'Payment Not Completed',
        body,
        type: 'transaction',
        category: 'warning',
      });
    }
  } catch (err) {
    logger.warn(`failedChargeAudit: member alert failed for ${reference}:`, err.message);
  }

  try {
    if (!alertAdmins) return;
    const payer = profileId
      ? (await supabase.from('profiles').select('name, email').eq('id', profileId).maybeSingle()).data
      : null;
    const who = payer?.name || payer?.email || 'A member';
    await notifyService.notifyAdmins({
      title: possibleDebit ? 'Failed Payment — Possible Debit' : 'Failed Payment',
      body: `${who}'s payment of ${amountFmt} failed (${gatewayStatus}${gatewayMessage ? `: ${gatewayMessage}` : ''}). Reference ${reference}.${possibleDebit ? ' The member may have been debited — check the bank and credit or refund.' : ' No debit expected, recorded for the record.'}`,
      type: 'transaction',
      category: possibleDebit ? 'action_required' : 'warning',
      priority: possibleDebit ? 'high' : 'normal',
    });
  } catch (err) {
    logger.warn(`failedChargeAudit: admin alert failed for ${reference}:`, err.message);
  }
}

module.exports = { recordFailedCharge, alertFailedCharge };
