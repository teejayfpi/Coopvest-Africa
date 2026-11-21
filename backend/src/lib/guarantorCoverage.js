/**
 * Guarantor coverage rules.
 *
 * A guarantee used to record only *who* stood behind a loan, never *how much*
 * they were committing. `loan_guarantors` had no amount column, and the savings
 * lien in migration 065 read only the member's own loans — so a guarantor could
 * consent to a ₦300,000 loan and withdraw every naira the next minute. The
 * guarantee was reputational, not financial.
 *
 * This module decides two things:
 *
 *   * `pledgedAmount` — how much of a guarantor's savings to hold when they
 *     consent. A pledge is a lien, not a debit: the money stays in the member's
 *     savings and keeps earning, it simply cannot be withdrawn while the loan
 *     they backed is unpaid.
 *   * `assessCoverage` — whether a loan is actually backed. A loan is covered
 *     when the borrower's own savings plus every guarantor's free savings meets
 *     the amount owed.
 *
 * Why the borrower's savings count first. Migration 065 already holds a
 * borrower's savings against their own outstanding loan, so that money is
 * already security. Counting it again as the guarantors' job would overstate
 * what a guarantor must pledge, and a guarantee nobody can afford is refused at
 * consent rather than discovered at default.
 *
 * The arithmetic, for a borrower who saved ₦100,000 on a 3x product:
 *
 *   principal          ₦300,000
 *   owed with interest ₦350,000   (total_repayment)
 *   already held       ₦100,000   (borrower's own lien)
 *   gap                ₦250,000   -> about ₦83,000 per guarantor
 *
 * So guarantors cover the gap, which is roughly the principal minus the
 * borrower's own savings — not the whole loan. That is a materially smaller ask
 * than "each guarantor must cover the loan", and it is the correct one: the
 * borrower's savings are the first loss buffer and they are already frozen.
 *
 * This module is deliberately free of I/O and of Supabase. The same rules are
 * needed by the consent endpoint, the approval path and the member-facing
 * coverage card, and a rule that lives in three places drifts. The route passes
 * rows in; the module returns a decision.
 */

/**
 * Loan statuses that carry live debt and therefore count towards coverage.
 *
 * Mirrors the status list in `savings_move` (migration 065) so the number a
 * member is shown and the number the database enforces cannot disagree.
 * 'pending'/'under_review' are excluded: an application not yet disbursed must
 * not be treated as debt.
 */
const LIVE_LOAN_STATUSES = ['approved', 'active', 'repaying', 'overdue', 'defaulted', 'in_recovery'];

/** Money is stored as NUMERIC; compare in kobo to avoid float drift. */
function toKobo(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.round(n * 100);
}

function fromKobo(kobo) {
  return Math.round(kobo) / 100;
}

function naira(amount) {
  return `₦${Number(amount || 0).toLocaleString('en-NG')}`;
}

/**
 * What a loan still owes.
 *
 * `remaining_balance` is the live figure and is preferred. It is NULL until the
 * first repayment on some rows, so `total_repayment` (principal plus interest)
 * is the fallback, and `amount` the last resort. Same ordering as the lien in
 * migration 065, so the two agree.
 */
function outstandingFor(loan) {
  if (!loan) return 0;
  const candidates = [loan.remaining_balance, loan.total_repayment, loan.amount];
  for (const candidate of candidates) {
    if (candidate == null) continue;
    const n = Number(candidate);
    if (Number.isFinite(n)) return n;
  }
  return 0;
}

/**
 * The share of `amount` that one guarantor is asked to pledge.
 *
 * Split evenly, then rounded *up* to the naira so three pledges can never sum
 * to a hair less than the gap and leave the loan nominally uncovered.
 */
function pledgePerGuarantor(amount, guarantorCount) {
  const count = Math.floor(Number(guarantorCount) || 0);
  if (count <= 0) return 0;
  const kobo = toKobo(amount);
  if (kobo <= 0) return 0;
  return fromKobo(Math.ceil(kobo / count));
}

/**
 * How much of a guarantor's savings must be held for a given loan.
 *
 * Capped at what they actually hold: pledging more than a member has would
 * create a lien they can never satisfy, and the coverage check reports the
 * shortfall separately. A member with no savings pledges nothing and simply
 * contributes nothing to coverage — the loan is refused or reduced instead.
 */
function pledgedAmount(loanOutstanding, guarantorCount, guarantorSavings) {
  const share = pledgePerGuarantor(loanOutstanding, guarantorCount);
  const available = Math.max(Number(guarantorSavings) || 0, 0);
  return fromKobo(Math.min(toKobo(share), toKobo(available)));
}

/**
 * Whether a loan is backed by the savings standing behind it.
 *
 * @param {object}   input
 * @param {number}   input.loanAmount       what the loan owes in total
 * @param {number}   input.borrowerSavings  borrower's own savings (already held)
 * @param {Array}    input.guarantors       [{ savings }] free savings per guarantor
 * @param {number}   [input.required]       guarantors required (default 3)
 * @returns {{covered: boolean, shortfall: number, coveredAmount: number,
 *            requiredAmount: number, guarantorsNeeded: number,
 *            guarantorsAvailable: number}}
 */
function assessCoverage({ loanAmount, borrowerSavings, guarantors, required = 3 }) {
  const owed = Math.max(Number(loanAmount) || 0, 0);
  const borrower = Math.max(Number(borrowerSavings) || 0, 0);
  const list = Array.isArray(guarantors) ? guarantors : [];

  const guarantorsAvailable = list.filter((g) => (Number(g && g.savings) || 0) > 0).length;
  const guarantorTotal = list.reduce((sum, g) => sum + Math.max(Number(g && g.savings) || 0, 0), 0);

  const coveredAmount = fromKobo(toKobo(borrower) + toKobo(guarantorTotal));
  const shortfall = fromKobo(Math.max(toKobo(owed) - toKobo(coveredAmount), 0));

  return {
    covered: shortfall === 0,
    shortfall,
    coveredAmount,
    requiredAmount: owed,
    guarantorsNeeded: Math.floor(Number(required) || 0),
    guarantorsAvailable,
  };
}

/**
 * Member-facing explanation of a coverage shortfall.
 *
 * Written for the person applying, not for an operator: it names the gap and
 * the two ways to close it. Returned as a string so callers can put it straight
 * into a 400 body without inventing their own wording.
 */
function coverageMessage(result) {
  const { shortfall, coveredAmount, requiredAmount } = result;
  return (
    `This loan is not fully backed. It needs ${naira(requiredAmount)} in savings across you and your guarantors, `
    + `and ${naira(coveredAmount)} is available, leaving ${naira(shortfall)} uncovered. `
    + 'Either borrow a smaller amount, or choose guarantors with more savings.'
  );
}

/**
 * Load the savings standing behind a loan and assess it.
 *
 * Mirrors `evaluateGuarantorEligibility` in guarantorEligibility.js: the pure
 * rule stays pure and this is the one place that knows how to fetch the rows.
 *
 * Borrower savings are read from `savings.balance`, the column `savings_move`
 * actually maintains, falling back to `total_saved` for rows the payment-proof
 * triggers wrote before that column existed.
 *
 * @returns {Promise<object>} the `assessCoverage` result plus the figures used
 */
async function evaluateLoanCoverage(supabase, loan) {
  const empty = {
    covered: true, shortfall: 0, coveredAmount: 0, requiredAmount: 0,
    guarantorsNeeded: 3, guarantorsAvailable: 0,
    borrowerSavings: 0, guarantors: [],
  };
  if (!loan || !loan.id) return empty;

  const owed = outstandingFor(loan);

  const { data: savingsRow } = await supabase
    .from('savings')
    .select('balance, total_saved')
    .eq('profile_id', loan.profile_id)
    .maybeSingle();

  const borrowerSavings = Number(
    savingsRow?.balance > 0 ? savingsRow.balance : (savingsRow?.total_saved || 0),
  );

  const { data: guarantorRows } = await supabase
    .from('loan_guarantors')
    .select('guarantor_profile_id, guarantor_id, status')
    .eq('loan_id', loan.id)
    .eq('status', 'consented');

  const guarantorIds = [...new Set(
    (guarantorRows || [])
      .map((g) => g.guarantor_profile_id || g.guarantor_id)
      .filter(Boolean),
  )];

  let guarantorSavings = [];
  if (guarantorIds.length) {
    const { data: rows } = await supabase
      .from('savings')
      .select('profile_id, balance, total_saved')
      .in('profile_id', guarantorIds);
    guarantorSavings = guarantorIds.map((id) => {
      const row = (rows || []).find((r) => r.profile_id === id);
      return { savings: Number(row?.balance > 0 ? row.balance : (row?.total_saved || 0)) };
    });
  }

  const result = assessCoverage({
    loanAmount: owed,
    borrowerSavings,
    guarantors: guarantorSavings,
  });

  return { ...result, borrowerSavings, guarantors: guarantorSavings };
}

module.exports = {
  LIVE_LOAN_STATUSES,
  outstandingFor,
  pledgePerGuarantor,
  pledgedAmount,
  assessCoverage,
  coverageMessage,
  evaluateLoanCoverage,
};
