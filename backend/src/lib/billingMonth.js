/**
 * Billing months.
 *
 * A contribution is recorded against a `contribution_month` ('YYYY-MM'), not
 * against the instant it was paid. That distinction is what makes paying in
 * advance possible: a member who pays next month's contribution today must have
 * it credited to next month, otherwise the money lands on the current month (a
 * second payment for a month already paid) and next month still shows as owed.
 *
 * Kept in one place because `wallet.js` (what is due) and `payments.js` (which
 * month a payment settles) must agree exactly — a mismatch shows a member a
 * month that no payment can ever clear.
 */

/** 'YYYY-MM' for a date (defaults to now). */
function monthKey(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

/** 'YYYY-MM' for the calendar month `offset` months after `date`. */
function monthKeyOffset(date, offset) {
  const base = date instanceof Date ? date : new Date(date);
  return monthKey(new Date(base.getFullYear(), base.getMonth() + offset, 1));
}

/** 'YYYY-MM' for the calendar month after `date` (defaults to now). */
function nextMonthKey(date = new Date()) {
  return monthKeyOffset(date, 1);
}

/** True for a well-formed 'YYYY-MM' string. */
function isValidMonthKey(value) {
  if (typeof value !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(value)) return false;
  return true;
}

/**
 * How far ahead a member may pay, in months from the current one. Bounded so a
 * mistyped year cannot pre-pay a decade of contributions (which would also
 * mis-state the cooperative's liabilities). Override with
 * MAX_ADVANCE_MONTHS if the policy changes.
 */
const DEFAULT_MAX_ADVANCE_MONTHS = 12;

function maxAdvanceMonths() {
  const raw = Number(process.env.MAX_ADVANCE_MONTHS);
  return Number.isFinite(raw) && raw >= 0 ? raw : DEFAULT_MAX_ADVANCE_MONTHS;
}

/**
 * Validate a requested target month for a payment.
 *
 * Returns `{ ok: true, month }` for an acceptable month, otherwise
 * `{ ok: false, reason }`. `null`/absent means "the current month", which is the
 * default every existing caller relies on.
 */
function resolveTargetMonth(requested, now = new Date()) {
  if (requested === undefined || requested === null || requested === '') {
    return { ok: true, month: monthKey(now) };
  }
  const value = String(requested);
  if (!isValidMonthKey(value)) {
    return { ok: false, reason: `month must be formatted YYYY-MM (received "${value}")` };
  }
  const current = monthKey(now);
  if (value < current) {
    return { ok: false, reason: `month ${value} is in the past; arrears are settled through the outstanding balance, not by back-dating a payment` };
  }
  const latest = monthKeyOffset(now, maxAdvanceMonths());
  if (value > latest) {
    return { ok: false, reason: `month ${value} is more than ${maxAdvanceMonths()} months ahead` };
  }
  return { ok: true, month: value };
}

module.exports = {
  monthKey,
  monthKeyOffset,
  nextMonthKey,
  isValidMonthKey,
  resolveTargetMonth,
  maxAdvanceMonths,
  DEFAULT_MAX_ADVANCE_MONTHS,
};
