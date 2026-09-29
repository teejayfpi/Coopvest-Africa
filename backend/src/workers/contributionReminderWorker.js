/**
 * Monthly contribution reminder worker.
 *
 * Server-side replacement for the (never-deployed, FCM-legacy) Supabase edge
 * function `process-contribution-reminders`. It runs in-process like the other
 * workers, so no separate deployment is required.
 *
 * Why this exists: the mobile app used to decide "overdue" locally from the
 * `contributions` table alone. The wallet-deposit flow — the one most members
 * actually use — never writes a `contributions` row; it only updates
 * `savings.last_savings_date`. So paid members were pushed "your contribution
 * is N days overdue. Please pay immediately…" and brand-new members were nagged
 * before their first due date.
 *
 * This worker reuses `computeObligations` (the same rule the member's
 * obligations card uses), so the push and the app can never disagree. A member
 * with nothing due simply gets no notification.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');
const { computeObligations } = require('../routes/wallet');
const { PAYROLL_METHODS } = require('../lib/activationGate');

const POLL_INTERVAL_MS = 24 * 60 * 60 * 1000; // daily
const STARTUP_DELAY_MS = 5 * 60 * 1000;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

function formatNaira(amount) {
  return `₦${Number(amount || 0).toLocaleString('en-NG')}`;
}

/**
 * Days past this month's due date: 0 = due today, negative = still upcoming.
 * Pure so the calendar boundary is unit-testable without freezing the clock.
 */
function daysSincePreferredDay(preferredDay, now = new Date()) {
  const day = Number(preferredDay) || 1;
  const due = new Date(now.getFullYear(), now.getMonth(), day);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.round((today - due) / MS_PER_DAY);
}

/**
 * The reminder decision, or null when the member should not be told anything.
 *
 * Pure and free of I/O so the rule is unit-testable. `savingsDue` already
 * encodes paid-this-month and joined-this-month (see `applyPaidMonthRule`), so
 * a paid or new member is filtered out here — that is what stops the false
 * "24 days overdue" push from ever being produced.
 */
function decideReminder({ savingsDue, days, contributionMethod, isFlagged }) {
  if (!(Number(savingsDue) > 0)) return null; // paid, new, or nothing owed
  if (PAYROLL_METHODS.includes(contributionMethod)) return null; // employer deducts
  if (isFlagged) return null;
  if (days < 0) return null; // not due yet

  const amount = formatNaira(savingsDue);
  if (days === 0) {
    return {
      kind: 'due_today',
      title: 'Contribution Due Today',
      body: `You haven't made your monthly contribution of ${amount} yet. Pay today to stay on track!`,
    };
  }
  const unit = days === 1 ? 'day' : 'days';
  return {
    kind: 'overdue',
    title: 'Contribution Overdue',
    body: `Your contribution of ${amount} is ${days} ${unit} overdue. Please pay immediately to maintain your good standing.`,
  };
}

/** True when this month's reminder (tagged in `data.tag`) is already stored. */
async function alreadyRemindedThisMonth(profileId, tag) {
  const since = new Date();
  since.setDate(1);
  since.setHours(0, 0, 0, 0);
  try {
    const { data } = await supabase
      .from('notifications')
      .select('id')
      .eq('profile_id', profileId)
      .eq('type', 'reminder')
      .gte('created_at', since.toISOString())
      .eq('data->>tag', tag)
      .limit(1);
    return Array.isArray(data) && data.length > 0;
  } catch (err) {
    logger.warn('contributionReminderWorker: de-dupe lookup failed:', err.message);
    return false;
  }
}

async function remindMember(profile) {
  try {
    const obligations = await computeObligations(profile.id);
    const decision = decideReminder({
      savingsDue: obligations.savings_due,
      days: daysSincePreferredDay(profile.preferred_payment_day || profile.contribution_day, new Date()),
      contributionMethod: profile.contribution_method || profile.contribution_type,
      isFlagged: profile.is_flagged === true || profile.is_active === false,
    });
    if (!decision) return 'skip';

    // One reminder per member per calendar month, so a restart or a re-run
    // cannot turn a single overdue month into a stream of pushes. The tag lives
    // in `data`, not the body — appending it to the body leaked the internal
    // tag into the member's notification feed.
    const tag = `reminder:${obligations.current_month}`;
    if (await alreadyRemindedThisMonth(profile.id, tag)) return 'dupe';

    await notifyService.broadcast({
      profileIds: [profile.id],
      channels: ['in_app', 'push'],
      title: decision.title,
      body: decision.body,
      type: 'reminder',
      category: 'warning',
      data: { tag },
    });
    return decision.kind;
  } catch (err) {
    logger.warn(`contributionReminderWorker: member ${profile.id} failed:`, err.message);
    return 'error';
  }
}

async function processDue() {
  try {
    const { data: members, error } = await supabase
      .from('profiles')
      .select(
        'id, preferred_payment_day, contribution_day, contribution_method, contribution_type, is_active, is_flagged',
      );
    if (error) throw error;
    if (!members || members.length === 0) return { checked: 0 };

    const tally = {};
    for (const member of members) {
      const outcome = await remindMember(member);
      tally[outcome] = (tally[outcome] || 0) + 1;
    }
    logger.info(`contributionReminderWorker: ${JSON.stringify(tally)}`);
    return { checked: members.length, tally };
  } catch (err) {
    logger.warn('contributionReminderWorker: tick failed:', err.message);
    return { error: err.message };
  }
}

function start() {
  if (process.env.CONTRIBUTION_REMINDERS_DISABLED === '1') {
    logger.info('contributionReminderWorker: disabled via env');
    return null;
  }
  logger.info('contributionReminderWorker: started (poll every 24h)');
  const handle = setInterval(processDue, POLL_INTERVAL_MS);
  // Run once shortly after startup (after the server is fully initialised).
  setTimeout(() => processDue().catch(() => {}), STARTUP_DELAY_MS);
  return handle;
}

module.exports = { start, processDue, remindMember, decideReminder, daysSincePreferredDay };
