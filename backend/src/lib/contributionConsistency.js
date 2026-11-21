/**
 * Contribution consistency.
 *
 * `loanPolicy.countContributionMonths` answers "how many months has this member
 * ever contributed in". That is an entry gate, and it is the right question for
 * someone applying for their first loan. It is the wrong question afterwards:
 * a member who paid six months in a row, then stopped for eight, still shows
 * six, and remains fully loan-eligible. Nothing anywhere measured whether the
 * contributions were *current*.
 *
 * `savings.consecutive_months` looks like it should have covered this, and ten
 * places read it — the wallet, the member profile, the reports, the referral
 * service. Nothing ever wrote it, so it has always been 0.
 *
 * This module computes the streak from the contributions themselves, which are
 * the only source of truth. Two figures come out of it:
 *
 *   * `streak`     — consecutive months contributed, counting back from the
 *                    most recent month that has a payment.
 *   * `currentStreak` — the same, but it is 0 if the current month is unpaid and
 *                    its grace period has passed. This is the figure that
 *                    matters for standing: it says whether the member is
 *                    contributing *now*, not whether they once did.
 *
 * Deliberately free of I/O so the month arithmetic can be tested directly.
 */

/** Statuses that mean money actually arrived. Matches loanPolicy's set. */
const PAID_STATUSES = new Set(['successful', 'completed', 'approved', 'paid']);

/**
 * Transaction types that represent a contribution landing in savings.
 *
 * The wallet deposit flow writes `savings_deposit`, but payroll batches write
 * `salary_deduction` and older/admin paths write `deposit`, `transfer_in` or
 * `contribution`. The first version of this module counted only
 * `savings_deposit`, which reported payroll members as never having paid — the
 * same class of bug that made the "amount due" screen wrong.
 */
const CONTRIBUTION_TRANSACTION_TYPES = [
  'deposit',
  'savings_deposit',
  'transfer_in',
  'salary_deduction',
  'contribution',
];

/** Months a member may be late before the streak is considered broken. */
const DEFAULT_GRACE_DAYS = 10;

/**
 * The policy this check enforces, and the loan-agreement version that first
 * disclosed it.
 *
 * Enforcement is tied to this version on purpose. Members apply through a
 * Digital Loan Agreement dialog that states these terms and requires an explicit
 * tick; the version they ticked is stored on the loan (`agreement_version`). A
 * member whose application carries an older version never saw this clause, so
 * the rule is not applied to them. That keeps the platform from enforcing a
 * rule against someone who was never shown it.
 */
const POLICY = {
  version: 'v1.1',
  minAgreementVersion: 'v1.1',
  graceDays: DEFAULT_GRACE_DAYS,
  label: 'Contribution currency',
};

function monthKey(value) {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

function shiftMonth(key, delta) {
  const [y, m] = key.split('-').map(Number);
  const d = new Date(Date.UTC(y, m - 1 + delta, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

/**
 * Parse a `vMAJOR.MINOR` agreement version. Anything unparseable sorts as 0 so
 * an unrecognised value can never silently grant the stricter treatment.
 */
function parseVersion(value) {
  const match = /^v?(\d+)\.(\d+)$/.exec(String(value || '').trim());
  if (!match) return [0, 0];
  return [Number(match[1]), Number(match[2])];
}

/**
 * True when `version` is at least `minimum` (e.g. v1.1 >= v1.1).
 */
function versionAtLeast(version, minimum) {
  const [aMaj, aMin] = parseVersion(version);
  const [bMaj, bMin] = parseVersion(minimum);
  if (aMaj !== bMaj) return aMaj > bMaj;
  return aMin >= bMin;
}

/**
 * Whether this application consented to the contribution-currency policy.
 */
function policyAppliesTo(agreementVersion) {
  return versionAtLeast(agreementVersion, POLICY.minAgreementVersion);
}

/**
 * Every month in which a contribution actually landed.
 *
 * Reads both flows: a `contributions` row, or a wallet deposit dated in that
 * month. Wallet deposits never write a `contributions` row, so counting only
 * that table would report most members as having never contributed.
 */
function paidMonths(contributions, deposits = []) {
  const months = new Set();
  for (const c of contributions || []) {
    if (!PAID_STATUSES.has(String((c && c.status) || '').toLowerCase())) continue;
    const key = monthKey(c.contribution_month) || monthKey(c.created_at) || monthKey(c.paid_at);
    if (key) months.add(key);
  }
  for (const d of deposits || []) {
    const key = monthKey(d && (d.created_at || d.paid_at));
    if (key) months.add(key);
  }
  return months;
}

/**
 * Length of the unbroken run of contributed months ending at `fromMonth`.
 */
function streakEndingAt(months, fromMonth) {
  let streak = 0;
  let cursor = fromMonth;
  while (months.has(cursor)) {
    streak += 1;
    cursor = shiftMonth(cursor, -1);
  }
  return streak;
}

/**
 * Assess a member's contribution standing.
 *
 * @param {object} input
 * @param {Array}  input.contributions  rows with status/contribution_month/created_at
 * @param {Array}  [input.deposits]     wallet deposits, for the flow that writes no row
 * @param {Date}   [input.now]
 * @param {number} [input.graceDays]    days into the current month before it counts as missed
 * @returns {{paidMonths: number, streak: number, currentStreak: number,
 *            monthsSinceLast: number|null, inGoodStanding: boolean,
 *            graceActive: boolean, lastPaidMonth: string|null}}
 */
function assessConsistency({
  contributions,
  deposits = [],
  now = new Date(),
  graceDays = DEFAULT_GRACE_DAYS,
} = {}) {
  const months = paidMonths(contributions, deposits);
  const currentMonth = monthKey(now);

  if (months.size === 0) {
    return {
      paidMonths: 0,
      streak: 0,
      currentStreak: 0,
      monthsSinceLast: null,
      inGoodStanding: false,
      graceActive: false,
      lastPaidMonth: null,
    };
  }

  const sorted = [...months].sort();
  const lastPaidMonth = sorted[sorted.length - 1];
  const streak = streakEndingAt(months, lastPaidMonth);

  // How many whole months have passed since the last payment.
  const [ly, lm] = lastPaidMonth.split('-').map(Number);
  const monthsSinceLast = (now.getUTCFullYear() - ly) * 12 + (now.getUTCMonth() + 1 - lm);

  // The current month still counts as part of the streak until the grace period
  // ends. Without this, every member would appear to be in arrears on the first
  // day of each month.
  const dayOfMonth = now.getUTCDate();
  const graceActive = dayOfMonth <= graceDays;
  const currentPaid = months.has(currentMonth);

  let currentStreak;
  if (currentPaid) {
    currentStreak = streakEndingAt(months, currentMonth);
  } else if (graceActive && lastPaidMonth === shiftMonth(currentMonth, -1)) {
    // Last month was paid and this month's grace has not run out yet.
    currentStreak = streak;
  } else {
    currentStreak = 0;
  }

  return {
    paidMonths: months.size,
    streak,
    currentStreak,
    monthsSinceLast,
    inGoodStanding: currentStreak > 0,
    graceActive,
    lastPaidMonth,
  };
}

/**
 * What a lapse should do to a member's standing.
 *
 *   0            good standing
 *   1            arrears warning — borrowing paused, no penalty
 *   2            restricted — borrowing paused, new guarantees refused
 *   3 or more    review — an officer decides
 *
 * Borrowing is paused from the first missed month. That is the consequence that
 * actually matters to a member, and it is reversible the moment they pay.
 */
function standingFor(currentStreak, monthsSinceLast) {
  if (currentStreak > 0) return 'good';
  if (monthsSinceLast == null) return 'never_contributed';
  if (monthsSinceLast <= 1) return 'warning';
  if (monthsSinceLast === 2) return 'restricted';
  return 'review';
}

/**
 * Member-facing explanation of a lapse, and what clears it.
 */
function consistencyMessage(assessment) {
  const { currentStreak, monthsSinceLast, inGoodStanding } = assessment;
  if (inGoodStanding) {
    return `You are up to date: ${currentStreak} consecutive month${currentStreak === 1 ? '' : 's'} contributed.`;
  }
  if (monthsSinceLast == null) {
    return 'You have not made a contribution yet. Your first contribution starts your record.';
  }
  return (
    `Your contribution is ${monthsSinceLast} month${monthsSinceLast === 1 ? '' : 's'} behind. `
    + 'Borrowing is paused until it is brought up to date, and it resumes as soon as the outstanding months are paid.'
  );
}

module.exports = {
  PAID_STATUSES,
  CONTRIBUTION_TRANSACTION_TYPES,
  DEFAULT_GRACE_DAYS,
  POLICY,
  monthKey,
  shiftMonth,
  parseVersion,
  versionAtLeast,
  policyAppliesTo,
  paidMonths,
  streakEndingAt,
  assessConsistency,
  standingFor,
  consistencyMessage,
};
