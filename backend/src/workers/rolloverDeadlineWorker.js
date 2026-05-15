/**
 * Rollover Deadline Reminder Worker
 *
 * Polls every 10 minutes for rollover guarantors whose consent deadline
 * falls within the next 24 hours and who have not yet responded.
 * Sends a single reminder push + in-app notification to each such guarantor.
 *
 * Deduplication: before sending, checks the `notifications` table for an
 * existing row of type `rollover_deadline_reminder` for the same
 * (profile_id, rollover_id) pair — no schema migration needed.
 *
 * Disable by setting ROLLOVER_DEADLINE_WORKER_DISABLED=1.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notify = require('../services/notifyService');

const POLL_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes

async function processDeadlines() {
  try {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    // Find all guarantors that:
    //   1. Have not yet responded (status = 'invited' or 'pending')
    //   2. Belong to a rollover whose consent deadline is in the next 0–24h
    //   3. That rollover is still 'pending' (not yet resolved)
    const { data: rows, error } = await supabase
      .from('rollover_guarantors')
      .select(`
        id,
        guarantor_id,
        guarantor_name,
        rollover_id,
        status,
        rollovers!inner (
          id,
          profile_id,
          extension_months,
          status,
          guarantor_consent_deadline
        )
      `)
      .in('status', ['invited', 'pending'])
      .eq('rollovers.status', 'pending')
      .gte('rollovers.guarantor_consent_deadline', now.toISOString())
      .lte('rollovers.guarantor_consent_deadline', in24h.toISOString());

    if (error) throw error;
    if (!rows || rows.length === 0) return;

    logger.info(`rolloverDeadlineWorker: ${rows.length} guarantor(s) approaching deadline`);

    for (const row of rows) {
      try {
        const rollover = row.rollovers;
        const rolloverId = row.rollover_id;
        const guarantorProfileId = row.guarantor_id;

        // Deduplication check — has a reminder already been sent for this pair?
        const { data: existing } = await supabase
          .from('notifications')
          .select('id')
          .eq('profile_id', guarantorProfileId)
          .eq('type', 'rollover_deadline_reminder')
          // Store rollover_id in the body as a lightweight tag — check with ilike
          .ilike('body', `%${rolloverId}%`)
          .maybeSingle();

        if (existing) {
          logger.info(
            `rolloverDeadlineWorker: reminder already sent to guarantor ${guarantorProfileId} for rollover ${rolloverId} — skipping`
          );
          continue;
        }

        // Calculate hours remaining for a human-readable message
        const deadline = new Date(rollover.guarantor_consent_deadline);
        const hoursLeft = Math.ceil((deadline - now) / (60 * 60 * 1000));

        // Fetch borrower's name for the notification body
        const { data: borrowerProfile } = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', rollover.profile_id)
          .maybeSingle();
        const borrowerName = borrowerProfile?.full_name || 'A member';

        const title = 'Rollover Consent Reminder';
        const body =
          `⏰ You have ${hoursLeft} hour${hoursLeft !== 1 ? 's' : ''} left to respond to ${borrowerName}'s loan rollover consent request (rollover:${rolloverId}). Please act before it expires.`;

        // Send in-app + push with the custom rollover sound
        await Promise.all([
          notify.sendInApp({
            profileId: guarantorProfileId,
            title,
            body,
            type: 'rollover_deadline_reminder',
            priority: 'high',
          }),
          notify.pushToProfile({
            profileId: guarantorProfileId,
            title,
            body,
            type: 'rollover_deadline_reminder',
            data: {
              rolloverId: String(rolloverId),
              guarantorId: String(row.id),
            },
          }),
        ]);

        logger.info(
          `rolloverDeadlineWorker: reminder sent → guarantor ${guarantorProfileId}, rollover ${rolloverId}, ${hoursLeft}h left`
        );
      } catch (inner) {
        logger.warn(
          `rolloverDeadlineWorker: failed for guarantor ${row.guarantor_id}:`,
          inner.message
        );
      }
    }
  } catch (err) {
    logger.warn('rolloverDeadlineWorker: tick failed:', err.message);
  }
}

function start() {
  if (process.env.ROLLOVER_DEADLINE_WORKER_DISABLED === '1') {
    logger.info('rolloverDeadlineWorker: disabled via env');
    return null;
  }
  logger.info('rolloverDeadlineWorker: started (poll every 10 min)');
  // Run once immediately on startup to catch anything already in-window
  processDeadlines().catch(() => {});
  const handle = setInterval(processDeadlines, POLL_INTERVAL_MS);
  return handle;
}

module.exports = { start, processDeadlines };
