/**
 * Reporting period resolution.
 *
 * Turns a period descriptor ("this week", "Q1 2026", "January 2025", a custom
 * range) into a concrete inclusive [start, end] date range. Everything the
 * comparison engine does is expressed in terms of these ranges, so defining a
 * period correctly once is enough for every metric and every export.
 *
 * All boundaries are computed in UTC. Mixing local and UTC boundaries would
 * make a "month" mean different things depending on where the report was
 * generated, which is exactly the kind of drift a financial report must not
 * have.
 *
 * Week convention: **Monday to Sunday**, ISO-8601. Weeks are numbered within
 * the calendar year in which Monday falls, so "week 3" of 2026 is unambiguous.
 */

const MS_PER_DAY = 86400000;

const PERIOD_TYPES = ['week', 'month', 'quarter', 'year', 'custom'];

class PeriodError extends Error {
  constructor(message) {
    super(message);
    this.name = 'PeriodError';
    this.status = 400;
  }
}

// ── primitive helpers ────────────────────────────────────────────────────────

function toUtcDate(value) {
  if (value instanceof Date) {
    return new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
  }
  const s = String(value);
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (m) return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) throw new PeriodError(`Invalid date: ${value}`);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function iso(date) {
  return date.toISOString().slice(0, 10);
}

function addDays(date, n) {
  return new Date(date.getTime() + n * MS_PER_DAY);
}

/** Inclusive range as ISO date strings. */
function makeRange(start, end) {
  return { start: iso(start), end: iso(end) };
}

/** Monday of the ISO week containing `date`. */
function mondayOf(date) {
  const d = toUtcDate(date);
  // getUTCDay(): 0=Sun..6=Sat. Shift so Monday=0.
  const shift = (d.getUTCDay() + 6) % 7;
  return addDays(d, -shift);
}

/**
 * ISO week-year and week number for a date.
 *
 * Returned together because they can disagree with the calendar year: ISO week
 * 1 of 2026 begins on 2025-12-29, so the date's calendar year is 2025 while its
 * week-year is 2026. Anything enumerating weeks must use the week-year or it
 * silently produces an empty list.
 */
function isoWeekParts(date) {
  const d = toUtcDate(date);
  const thursday = addDays(d, 3 - ((d.getUTCDay() + 6) % 7));
  const weekYear = thursday.getUTCFullYear();
  const firstThursday = new Date(Date.UTC(weekYear, 0, 4));
  const week = Math.floor((thursday - mondayOf(firstThursday)) / (7 * MS_PER_DAY)) + 1;
  return { year: weekYear, week };
}

/** ISO week number (1-53) for a date. */
function isoWeekNumber(date) {
  return isoWeekParts(date).week;
}

/** Number of days in a month (1-12) of a year. */
function daysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

// ── period builders ──────────────────────────────────────────────────────────

function weekRange(year, week) {
  // Week 1 is the week containing the first Thursday of the year, matching
  // isoWeekNumber so the two agree.
  const firstThursday = new Date(Date.UTC(year, 0, 4));
  const week1Monday = mondayOf(firstThursday);
  const monday = addDays(week1Monday, (week - 1) * 7);
  return makeRange(monday, addDays(monday, 6));
}

function monthRange(year, month) {
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month - 1, daysInMonth(year, month)));
  return makeRange(start, end);
}

function quarterRange(year, quarter) {
  const startMonth = (quarter - 1) * 3;
  const start = new Date(Date.UTC(year, startMonth, 1));
  const end = new Date(Date.UTC(year, startMonth + 3, 0));
  return makeRange(start, end);
}

function yearRange(year) {
  return makeRange(new Date(Date.UTC(year, 0, 1)), new Date(Date.UTC(year, 11, 31)));
}

/**
 * Resolve one period descriptor.
 *
 * Accepted shapes:
 *   { type:'week',    year, week }        e.g. { type:'week', year:2026, week:3 }
 *   { type:'month',   year, month }       e.g. { type:'month', year:2026, month:1 }
 *   { type:'quarter', year, quarter }     e.g. { type:'quarter', year:2026, quarter:1 }
 *   { type:'year',    year }              e.g. { type:'year', year:2025 }
 *   { type:'custom',  start, end }        e.g. { type:'custom', start:'2026-03-01', end:'2026-03-15' }
 *   { type:'month',   from:'2026-01' }    shorthand: '2026-01'
 *   { type:'quarter', from:'2026-Q1' }    shorthand: '2026-Q1'
 *   { type:'week',    from:'2026-W03' }   shorthand: '2026-W03'
 *   { type:'year',    from:'2025' }       shorthand: '2025'
 */
function resolvePeriod(input) {
  if (!input || typeof input !== 'object') {
    throw new PeriodError('A period descriptor object is required');
  }
  const type = String(input.type || '').toLowerCase();
  if (!PERIOD_TYPES.includes(type)) {
    throw new PeriodError(`Unsupported period type: ${input.type}. Use one of ${PERIOD_TYPES.join(', ')}`);
  }

  let { year, month, quarter, week, start, end } = input;

  // Shorthand "from" strings.
  if (input.from) {
    const f = String(input.from).trim();
    if (type === 'month') {
      const m = /^(\d{4})-(\d{1,2})$/.exec(f);
      if (!m) throw new PeriodError(`Invalid month shorthand: ${f} (expected YYYY-MM)`);
      year = Number(m[1]); month = Number(m[2]);
    } else if (type === 'quarter') {
      const m = /^(\d{4})-?Q([1-4])$/i.exec(f);
      if (!m) throw new PeriodError(`Invalid quarter shorthand: ${f} (expected YYYY-Q1..Q4)`);
      year = Number(m[1]); quarter = Number(m[2]);
    } else if (type === 'week') {
      const m = /^(\d{4})-?W(\d{1,2})$/i.exec(f);
      if (!m) throw new PeriodError(`Invalid week shorthand: ${f} (expected YYYY-Wnn)`);
      year = Number(m[1]); week = Number(m[2]);
    } else if (type === 'year') {
      if (!/^\d{4}$/.test(f)) throw new PeriodError(`Invalid year shorthand: ${f}`);
      year = Number(f);
    }
  }

  if (type === 'week') {
    if (!Number.isInteger(year)) throw new PeriodError('week period requires { year, week }');
    if (!Number.isInteger(week) || week < 1 || week > 53) {
      throw new PeriodError('week must be an integer 1-53');
    }
    return { type, label: `${year} Week ${week}`, ...weekRange(year, week) };
  }

  if (type === 'month') {
    if (!Number.isInteger(year)) throw new PeriodError('month period requires { year, month }');
    if (!Number.isInteger(month) || month < 1 || month > 12) {
      throw new PeriodError('month must be an integer 1-12');
    }
    const monthName = new Date(Date.UTC(year, month - 1, 1)).toLocaleString('en-GB', {
      month: 'long', timeZone: 'UTC',
    });
    return { type, label: `${monthName} ${year}`, ...monthRange(year, month) };
  }

  if (type === 'quarter') {
    if (!Number.isInteger(year)) throw new PeriodError('quarter period requires { year, quarter }');
    if (!Number.isInteger(quarter) || quarter < 1 || quarter > 4) {
      throw new PeriodError('quarter must be an integer 1-4');
    }
    return { type, label: `Q${quarter} ${year}`, ...quarterRange(year, quarter) };
  }

  if (type === 'year') {
    if (!Number.isInteger(year)) throw new PeriodError('year period requires { year }');
    return { type, label: String(year), ...yearRange(year) };
  }

  // custom
  if (!start || !end) throw new PeriodError('custom period requires { start, end }');
  const s = toUtcDate(start);
  const e = toUtcDate(end);
  if (s > e) throw new PeriodError('custom period start must not be after end');
  const days = Math.round((e - s) / MS_PER_DAY) + 1;
  return {
    type,
    label: `${iso(s)} → ${iso(e)}`,
    start: iso(s),
    end: iso(e),
    days,
  };
}

/**
 * Build a period descriptor for the period immediately preceding `period`.
 *
 * Used for the "vs previous period" shortcut, so the caller does not have to
 * know that the previous month of January is December of the year before.
 */
function previousPeriod(period) {
  const start = toUtcDate(period.start);
  const end = toUtcDate(period.end);

  if (period.type === 'week') {
    return resolvePeriod({
      type: 'custom',
      start: iso(addDays(start, -7)),
      end: iso(addDays(end, -7)),
      // keep it self-describing rather than inheriting 'custom'
    });
  }
  if (period.type === 'month') {
    const y = start.getUTCFullYear();
    const m = start.getUTCMonth() + 1;
    const pm = m === 1 ? 12 : m - 1;
    const py = m === 1 ? y - 1 : y;
    return resolvePeriod({ type: 'month', year: py, month: pm });
  }
  if (period.type === 'quarter') {
    const y = start.getUTCFullYear();
    const q = Math.floor(start.getUTCMonth() / 3) + 1;
    const pq = q === 1 ? 4 : q - 1;
    const py = q === 1 ? y - 1 : y;
    return resolvePeriod({ type: 'quarter', year: py, quarter: pq });
  }
  if (period.type === 'year') {
    return resolvePeriod({ type: 'year', year: start.getUTCFullYear() - 1 });
  }

  // Custom: shift the whole window back by its own length, which keeps
  // "1-15 March" comparing against "13-27 February" rather than a partial range.
  const days = Math.round((end - start) / MS_PER_DAY) + 1;
  const prevEnd = addDays(start, -1);
  const prevStart = addDays(prevEnd, -(days - 1));
  return resolvePeriod({ type: 'custom', start: iso(prevStart), end: iso(prevEnd) });
}

/** The same period one year earlier — the year-on-year comparison. */
function previousYearPeriod(period) {
  const shift = (d) => {
    const date = toUtcDate(d);
    const targetYear = date.getUTCFullYear() - 1;
    // Guard 29 Feb: clamping to 28 Feb is what an accountant would expect.
    const day = Math.min(date.getUTCDate(), daysInMonth(targetYear, date.getUTCMonth() + 1));
    return iso(new Date(Date.UTC(targetYear, date.getUTCMonth(), day)));
  };
  return {
    type: period.type,
    label: `${period.label} (prior year)`,
    start: shift(period.start),
    end: shift(period.end),
  };
}

/**
 * Every period of a given granularity in a year, so the UI can offer a picker
 * (e.g. all 4 quarters, all 12 months, weeks 1..53).
 */
function enumeratePeriods(type, year) {
  if (type === 'month') {
    return Array.from({ length: 12 }, (_, i) => resolvePeriod({ type: 'month', year, month: i + 1 }));
  }
  if (type === 'quarter') {
    return Array.from({ length: 4 }, (_, i) => resolvePeriod({ type: 'quarter', year, quarter: i + 1 }));
  }
  if (type === 'week') {
    const periods = [];
    for (let w = 1; w <= 53; w += 1) {
      const p = weekRange(year, w);
      // Stop when the week no longer belongs to the requested week-year.
      // Comparing week *numbers* alone is not enough: week 1 of the next
      // week-year also reports week number 1.
      const parts = isoWeekParts(toUtcDate(p.start));
      if (parts.year !== year || parts.week !== w) break;
      periods.push({ type: 'week', label: `${year} Week ${w}`, ...p });
    }
    return periods;
  }
  if (type === 'year') {
    return [resolvePeriod({ type: 'year', year })];
  }
  return [];
}

/** True when `dateIso` falls inside `range` (inclusive, whole days, UTC). */
function inRange(dateIso, range) {
  if (!dateIso) return false;
  const t = new Date(dateIso).getTime();
  if (Number.isNaN(t)) return false;
  const lo = new Date(`${range.start}T00:00:00.000Z`).getTime();
  const hi = new Date(`${range.end}T23:59:59.999Z`).getTime();
  return t >= lo && t <= hi;
}

/** Number of days in a resolved range, inclusive. */
function rangeDays(range) {
  const s = toUtcDate(range.start);
  const e = toUtcDate(range.end);
  return Math.round((e - s) / MS_PER_DAY) + 1;
}

/** Inclusive PostgREST-friendly timestamp bounds for a range. */
function rangeBounds(range) {
  return { fromIso: `${range.start}T00:00:00.000Z`, toIso: `${range.end}T23:59:59.999Z` };
}

module.exports = {
  PERIOD_TYPES,
  MS_PER_DAY,
  PeriodError,
  resolvePeriod,
  previousPeriod,
  previousYearPeriod,
  enumeratePeriods,
  inRange,
  rangeDays,
  rangeBounds,
  isoWeekNumber,
  weekRange,
  monthRange,
  quarterRange,
  yearRange,
  daysInMonth,
  toUtcDate,
  iso,
};
