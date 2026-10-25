/**
 * Guarantor invitation worker.
 *
 * Two jobs on one sweep, both over `pending` invitations that carry a
 * `consent_deadline` (migration 053):
 *
 *   1. Remind — a guarantee whose deadline is within 48h and that has not been
 *      nudged yet gets one reminder (in-app + push), then `reminder_sent_at` is
 *      stamped so it is never nudged twice.
 *   2. Expire — a guarantee past its deadline is marked `expired` so a stalled
 *      loan is visible instead of sitting `pending` forever.
 *
 * Legacy QR rows have no deadline and are left alone; they are resolved by a
 * scan, not by this sweep.
 *
 * Disable with GUARANTOR_INVITE_WORKER_DISABLED=1.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notify = require('../services/notifyService');
const { isReminderDue, isExpired } = require('../lib/guarantorInvitations');

const POLL_INTERVAL_MS = 60 * 60 * 1000; // hourly
const STARTUP_DELAY_MS = 90 * 1000;
const SCAN_LIMIT = 500;

let _timer = null;

async function loadPendingInvites() {
  const { data, error } = await supabase
    .from('loan_guarantors')
    .select('id, loan_id, guarantor_id, guarantor_name, status, consent_deadline, reminder_sent_at')
    .eq('status', 'pending')
    .not('consent_deadline', 'is', null)
    .order('consent_deadline', { ascending: true })
    .limit(SCAN_LIMIT);
  if (error) throw error;
  return data || [];
}

async function remind(invite, now) {
  const loanId = invite.loan_id;
  await notify.broadcast({
    profileIds: [invite.guarantor_id],
    channels: ['in_app', 'push'],
    title: 'Guarantee request expiring soon',
    body: 'A loan guarantee you were invited to give expires in under 48 hours. Open the app to accept or decline.',
    type: 'guarantor_request',
    category: 'action_required',
    priority: 'high',
    data: { loanId, guaranteeId: invite.id },
  });
  await supabase
    .from('loan_guarantors')
    .update({ reminder_sent_at: now.toISOString(), updated_at: now.toISOString() })
    .eq('id', invite.id);
  logger.info(`guarantorInviteWorker: reminded guarantor ${invite.guarantor_id} for loan ${loanId}`);
}

async function expire(invite, now) {
  const stamp = now.toISOString();
  // Guard on status='pending' so a consent that landed between the read and the
  // write is never overwritten.
  const { error } = await supabase
    .from('loan_guarantors')
    .update({ status: 'expired', expired_at: stamp, updated_at: stamp })
    .eq('id', invite.id)
    .eq('status', 'pending');
  if (error) throw error;

  await supabase.from('audit_logs').insert({
    actor_id: invite.guarantor_id,
    action: 'GUARANTOR_INVITE_EXPIRED',
    target_model: 'LoanGuarantor',
    target_id: invite.id,
    metadata: { loanId: invite.loan_id },
  }).then(() => {}, () => {});

  // Tell the borrower so they can invite someone else rather than wait.
  const { data: loan } = await supabase
    .from('loans')
    .select('profile_id')
    .eq('id', invite.loan_id)
    .maybeSingle();
  if (loan && loan.profile_id) {
    await notify.broadcast({
      profileIds: [loan.profile_id],
      channels: ['in_app', 'push'],
      title: 'A guarantor invitation expired',
      body: 'One of your guarantor invitations was not answered in time and has expired. You can invite another guarantor.',
      type: 'guarantor_request',
      category: 'warning',
      priority: 'normal',
      data: { loanId: invite.loan_id },
    });
  }
  logger.info(`guarantorInviteWorker: expired invite ${invite.id} for loan ${invite.loan_id}`);
}

/**
 * One sweep. Returns a summary; never throws.
 */
async function processInvitations(now = new Date()) {
  const summary = { scanned: 0, reminded: 0, expired: 0, errors: 0 };
  let invites;
  try {
    invites = await loadPendingInvites();
  } catch (err) {
    // The deadline columns only exist once migration 053 is applied; a missing
    // column must not crash the worker on an older environment.
    logger.warn('guarantorInviteWorker: could not load invitations:', err.message);
    return { ...summary, errors: 1 };
  }

  summary.scanned = invites.length;
  for (const invite of invites) {
    try {
      if (isExpired(invite, now)) {
        await expire(invite, now);
        summary.expired += 1;
      } else if (isReminderDue(invite, now)) {
        await remind(invite, now);
        summary.reminded += 1;
      }
    } catch (err) {
      summary.errors += 1;
      logger.warn(`guarantorInviteWorker: invite ${invite.id} failed:`, err.message);
    }
  }
  return summary;
}

function start() {
  if (process.env.GUARANTOR_INVITE_WORKER_DISABLED === '1') {
    logger.info('guarantorInviteWorker: disabled by GUARANTOR_INVITE_WORKER_DISABLED');
    return;
  }
  if (_timer) return;
  _timer = setInterval(() => {
    processInvitations().catch((err) => logger.warn('guarantorInviteWorker: sweep failed:', err.message));
  }, POLL_INTERVAL_MS);
  _timer.unref?.();
  setTimeout(() => {
    processInvitations().catch((err) => logger.warn('guarantorInviteWorker: initial sweep failed:', err.message));
  }, STARTUP_DELAY_MS).unref?.();
  logger.info('guarantorInviteWorker: started (hourly)');
}

function stop() {
  if (_timer) {
    clearInterval(_timer);
    _timer = null;
  }
}

module.exports = { start, stop, processInvitations, POLL_INTERVAL_MS };
