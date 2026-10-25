/**
 * Annual contribution & interest certificate.
 *
 * A member (and, for salary-deduction staff, their employer) needs a yearly
 * statement of what they contributed and what interest they earned — for tax and
 * HR. The numbers must come from the transaction ledger, not a derived table:
 * the platform's rule is that a headline figure has to be traceable to real
 * transactions (`contributions` has drifted in production before).
 *
 * This module is a pure aggregator over already-fetched transactions, so the
 * arithmetic is unit-testable without a database. The route supplies the rows.
 */

// Transaction types that count as a member contribution for the year.
const CONTRIBUTION_TYPES = new Set(['savings', 'deposit', 'contribution']);
// Transaction type recorded when the cooperative credits interest.
const INTEREST_TYPES = new Set(['interest']);

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function money(n) {
  return Math.round(toNumber(n) * 100) / 100;
}

/**
 * A completed transaction moves money; anything else has not settled yet and is
 * excluded, so a pending charge never inflates a certificate.
 */
function isSettled(t) {
  return t && t.status === 'completed';
}

function isCredit(t) {
  // `category` is the ledger's credit/debit marker; fall back to the sign.
  if (t.category === 'credit') return true;
  if (t.category === 'debit') return false;
  return toNumber(t.amount) >= 0;
}

/**
 * Build the certificate payload.
 *
 * @param {object}   opts
 * @param {object}   opts.profile      { id, name, email, organization_id? }
 * @param {Array}    opts.transactions ledger rows (any order)
 * @param {number}   opts.year
 * @param {string}   [opts.organizationName]
 * @param {Date}     [opts.now]
 * @returns {object} certificate data
 */
function buildCertificate({ profile, transactions = [], year, organizationName = null, now = new Date() }) {
  const yearNum = Number(year);
  if (!Number.isInteger(yearNum)) {
    throw new Error('A valid year is required');
  }

  const inYear = transactions.filter((t) => {
    if (!isSettled(t) || !t.created_at) return false;
    const d = new Date(t.created_at);
    return !Number.isNaN(d.getTime()) && d.getUTCFullYear() === yearNum;
  });

  const beforeYear = transactions.filter((t) => {
    if (!isSettled(t) || !t.created_at) return false;
    const d = new Date(t.created_at);
    return !Number.isNaN(d.getTime()) && d.getUTCFullYear() < yearNum;
  });

  const netOf = (rows) => rows.reduce((s, t) => s + (isCredit(t) ? toNumber(t.amount) : -toNumber(t.amount)), 0);

  const openingBalance = money(netOf(beforeYear));

  const contributions = inYear.filter((t) => CONTRIBUTION_TYPES.has(t.type) && isCredit(t));
  const interest = inYear.filter((t) => INTEREST_TYPES.has(t.type) && isCredit(t));
  const withdrawals = inYear.filter((t) => !isCredit(t) && !INTEREST_TYPES.has(t.type));

  const totalContributions = money(contributions.reduce((s, t) => s + toNumber(t.amount), 0));
  const totalInterest = money(interest.reduce((s, t) => s + toNumber(t.amount), 0));
  const totalWithdrawals = money(withdrawals.reduce((s, t) => s + toNumber(t.amount), 0));
  const closingBalance = money(openingBalance + netOf(inYear));

  // Monthly breakdown of contributions, so an employer can reconcile deductions.
  const monthly = MONTH_NAMES.map((name, idx) => {
    const rows = contributions.filter((t) => new Date(t.created_at).getUTCMonth() === idx);
    const interestRows = interest.filter((t) => new Date(t.created_at).getUTCMonth() === idx);
    return {
      month: idx + 1,
      name,
      contributions: money(rows.reduce((s, t) => s + toNumber(t.amount), 0)),
      interest: money(interestRows.reduce((s, t) => s + toNumber(t.amount), 0)),
      count: rows.length,
    };
  });

  // A stable, human-quotable reference: CV-<year>-<profile short>.
  const shortId = String(profile && profile.id ? profile.id : 'unknown').replace(/-/g, '').slice(0, 8).toUpperCase();
  const reference = `CV-${yearNum}-${shortId}`;

  return {
    certificateType: 'annual_contribution_and_interest',
    reference,
    year: yearNum,
    generatedAt: now.toISOString(),
    member: {
      id: profile && profile.id ? profile.id : null,
      name: (profile && profile.name) || 'Coopvest Member',
      email: (profile && profile.email) || null,
      organizationId: (profile && profile.organization_id) || null,
      organizationName,
    },
    currency: 'NGN',
    summary: {
      openingBalance,
      totalContributions,
      totalInterest,
      totalWithdrawals,
      closingBalance,
      transactionCount: inYear.length,
    },
    monthly,
  };
}

module.exports = {
  buildCertificate,
  CONTRIBUTION_TYPES,
  INTEREST_TYPES,
  MONTH_NAMES,
};
