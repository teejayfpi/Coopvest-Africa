/**
 * Referral confirmation worker.
 *
 * Why this exists: nothing confirmed referrals. `confirmReferralEvent` was only
 * reachable from an admin action, so an event sat `confirmed = false` forever
 * and the referrer never earned a tier. The member saw "0 confirmed referrals"
 * no matter how many friends they invited, which made the whole program inert.
 *
 * Each tick scans pending events, asks the service whether the referred member
 * now qualifies, and confirms the ones that do. The decision itself lives in
 * `referralService.canConfirm`, so this worker and the admin action can never
 * disagree about what "qualified" means.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const referralService = require('../services/referralService');
const notifyService = require('../services/notifyService');

const POLL_INTERVAL_MS = 6 * 60 * 60 * 1000; // every 6 hours
const STARTUP_DELAY_MS = 8 * 60 * 1000;
const BATCH_SIZE = 200;

/**
 * Confirm one pending event. Returns a short outcome string for the tally so a
 * run is observable without reading every row.
 */
async function confirmIfEligible(event) {
  let qualification;
  try {
    qualification = await referralService.getQualification(event.referred_id);
  } catch (err) {
    return 'qualification_error';
  }

  const gate = referralService.canConfirm(event, qualification);
  if (!gate.ok) {
    // "Lock-in period has not elapsed" is the normal case for a fresh referral,
    // not an error, so it must not be logged as one.
    return gate.reason === 'Lock-in period has not elapsed' ? 'not_due' : 'not_qualified';
  }

  try {
    const result = await referralService.confirmReferralEvent(event.id);
    if (!result.success) return 'confirm_failed';
  } catch (err) {
    logger.warn(`referralConfirmationWorker: confirm failed for ${event.id}: ${err.message}`);
    return 'confirm_failed';
  }

  await notifyReferrer(event);
  return 'confirmed';
}

/** Tell the referrer their referral counted, and what it moved them to. */
async function notifyReferrer(event) {
  try {
    const { summary } = await referralService.getReferralSummary(event.referrer_id);
    const bonus = Number(summary?.current_tier_bonus) || 0;
    const confirmed = Number(summary?.confirmed_referrals) || 0;
    const name = event.referred_name || 'Your referral';

    await notifyService.notifyMember({
      profileId: event.referrer_id,
      title: 'Referral Confirmed',
      body: bonus > 0
        ? `${name} has been confirmed. You now have ${confirmed} confirmed referrals, giving you a ${bonus}% loan interest discount.`
        : `${name} has been confirmed. You now have ${confirmed} confirmed referrals.`,
      type: 'referral',
      category: 'success',
      data: { screen: '/referrals', confirmedReferrals: confirmed, tierBonus: bonus },
    });
  } catch (err) {
    // The confirmation already succeeded; a failed notification must not undo it.
    logger.warn('referralConfirmationWorker: notify failed:', err.message);
  }
}

async function processDue() {
  try {
    const { data: events, error } = await supabase
      .from('referral_events')
      .select('id, referrer_id, referrer_name, referred_id, referred_name, confirmed, is_flagged, lock_in_end_date, created_at')
      .eq('confirmed', false)
      .eq('is_flagged', false)
      .order('created_at', { ascending: true })
      .limit(BATCH_SIZE);
    if (error) throw error;

    const tally = {};
    for (const event of events || []) {
      const outcome = await confirmIfEligible(event);
      tally[outcome] = (tally[outcome] || 0) + 1;
    }
    logger.info(`referralConfirmationWorker: ${JSON.stringify(tally)}`);
    return { checked: (events || []).length, tally };
  } catch (err) {
    logger.warn('referralConfirmationWorker: tick failed:', err.message);
    return { error: err.message };
  }
}

function start() {
  if (process.env.REFERRAL_CONFIRMATION_DISABLED === '1') {
    logger.info('referralConfirmationWorker: disabled via env');
    return null;
  }
  logger.info('referralConfirmationWorker: started (poll every 6h)');
  const handle = setInterval(processDue, POLL_INTERVAL_MS);
  setTimeout(() => processDue().catch(() => {}), STARTUP_DELAY_MS);
  return handle;
}

module.exports = { start, processDue, confirmIfEligible };
