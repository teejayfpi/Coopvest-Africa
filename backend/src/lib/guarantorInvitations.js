/**
 * Guarantor invitation lifecycle.
 *
 * A borrower invites a named guarantor; the row is `pending` with a
 * `consent_deadline`. This module owns the two decisions the worker and the
 * routes must agree on — is a reminder due, and has the invitation lapsed — so
 * the rule lives in one place instead of being re-derived at each call site.
 *
 * The QR flow is untouched: a scan moves a pending row to `consented` exactly
 * as before. An invitation just gives the borrower a way to name people and the
 * system a way to chase and lapse them.
 */

// A guarantor has this long to respond before the invitation lapses.
const DEFAULT_CONSENT_WINDOW_DAYS = 7;
// A reminder goes out once the deadline is within this window.
const REMINDER_LEAD_HOURS = 48;

function deadlineFrom(now = new Date(), days = DEFAULT_CONSENT_WINDOW_DAYS) {
  return new Date(now.getTime() + days * 24 * 60 * 60 * 1000).toISOString();
}

/**
 * Should a reminder be sent for this invitation?
 *
 * Only when it is still pending, has not already been reminded, has a deadline,
 * and that deadline falls within the lead window. A null deadline (a legacy QR
 * row) never reminds — there is nothing to remind against.
 */
function isReminderDue(invite, now = new Date()) {
  if (!invite || invite.status !== 'pending') return false;
  if (invite.reminder_sent_at) return false;
  if (!invite.consent_deadline) return false;
  const deadline = new Date(invite.consent_deadline);
  if (Number.isNaN(deadline.getTime())) return false;
  const msUntilDeadline = deadline.getTime() - now.getTime();
  // A lapsed invitation expires rather than reminds, so require the deadline to
  // still be in the future. Without the lower bound a past deadline also
  // satisfies "<= lead hours" and the row would both remind and expire.
  return msUntilDeadline >= 0 && msUntilDeadline <= REMINDER_LEAD_HOURS * 60 * 60 * 1000;
}

/**
 * Has this invitation lapsed?
 *
 * Pending and past its deadline. `isReminderDue` deliberately returns false once
 * the deadline has passed, so the two never both fire for the same row.
 */
function isExpired(invite, now = new Date()) {
  if (!invite || invite.status !== 'pending') return false;
  if (!invite.consent_deadline) return false;
  const deadline = new Date(invite.consent_deadline);
  if (Number.isNaN(deadline.getTime())) return false;
  return deadline.getTime() < now.getTime();
}

module.exports = {
  DEFAULT_CONSENT_WINDOW_DAYS,
  REMINDER_LEAD_HOURS,
  deadlineFrom,
  isReminderDue,
  isExpired,
};
