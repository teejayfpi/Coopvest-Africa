/**
 * Guarantor eligibility rules.
 *
 * A guarantee is only as strong as the party standing behind it, so a guarantor
 * must share the borrower's contribution channel:
 *
 *   * Salary-deduction borrower — the guarantor must be a salary-deduction
 *     member of the *same* organisation. A member of another organisation has
 *     no payroll relationship with the borrower's employer, so recovery cannot
 *     run through it.
 *   * Direct-deposit borrower — the guarantor must also be a direct-deposit
 *     member. A salaried member's standing rests on an employer deduction that
 *     has nothing to do with a self-funded borrower.
 *
 * Self-guarantee is never allowed.
 *
 * The decision is derived from the two profiles, never stored, so it cannot
 * drift out of sync with a member's contribution method. Extracted here so the
 * matrix can be unit-tested without standing up Express or Supabase; the routes
 * call `evaluateGuarantorEligibility` and there is one definition, not three.
 */

const { PAYROLL_METHODS } = require('./activationGate');

/** Member-facing copy. Kept beside the rule so the two cannot disagree. */
const REASON = {
  SELF: 'You cannot stand as a guarantor for your own loan.',
  SALARY_GUARANTOR_NOT_SALARY:
    'This borrower contributes by salary deduction, so their guarantors must also be salary-deduction members of the same organisation.',
  BORROWER_NO_ORG:
    'This borrower contributes by salary deduction but has no organisation on file yet, so guarantors cannot be verified. Please contact support.',
  ORG_MISMATCH:
    'Guarantors for a salary-deduction member must belong to the same organisation as the borrower.',
  DIRECT_GUARANTOR_SALARIED:
    'This borrower contributes by direct deposit, so a salary-deduction member cannot stand as their guarantor. Choose a direct-deposit member.',
  GUARANTOR_CHANNEL_UNKNOWN:
    'This member\'s contribution method is not set, so they cannot stand as a guarantor. Please contact support.',
  BORROWER_CHANNEL_UNKNOWN:
    'This borrower\'s contribution method is not set, so guarantors cannot be verified. Please contact support.',
  UNKNOWN:
    'Member details could not be loaded, so guarantor eligibility could not be verified.',
};

/**
 * The contribution channel a profile belongs to.
 *
 * The app writes `contribution_method` from the settings screen and
 * `contribution_type` from the KYC/sign-up screens; either identifies the
 * member, so they are read as one value (matching activationGate.js).
 *
 * @returns {'salary'|'direct'|'unknown'}
 */
function contributionChannel(profile) {
  if (!profile) return 'unknown';
  const method = profile.contribution_method || profile.contribution_type;
  if (PAYROLL_METHODS.includes(method)) return 'salary';
  if (method === 'direct_deposit' || method === 'manual') return 'direct';
  return 'unknown';
}

const isSalaryChannel = (profile) => contributionChannel(profile) === 'salary';
const isDirectChannel = (profile) => contributionChannel(profile) === 'direct';

/**
 * Decide whether `guarantor` may stand for `borrower`.
 *
 * @param {object|null} borrower  profile row: id, contribution_method/type, organization_id
 * @param {object|null} guarantor profile row with the same shape
 * @returns {{eligible: boolean, code: string|null, reason: string|null}}
 */
function guarantorEligibility(borrower, guarantor) {
  if (!borrower || !guarantor) {
    return { eligible: false, code: 'UNKNOWN', reason: REASON.UNKNOWN };
  }

  if (borrower.id && guarantor.id && borrower.id === guarantor.id) {
    return { eligible: false, code: 'SELF', reason: REASON.SELF };
  }

  const borrowerChannel = contributionChannel(borrower);

  if (borrowerChannel === 'salary') {
    if (!isSalaryChannel(guarantor)) {
      return { eligible: false, code: 'GUARANTOR_NOT_SALARY', reason: REASON.SALARY_GUARANTOR_NOT_SALARY };
    }
    if (!borrower.organization_id) {
      return { eligible: false, code: 'BORROWER_NO_ORG', reason: REASON.BORROWER_NO_ORG };
    }
    if (!guarantor.organization_id || guarantor.organization_id !== borrower.organization_id) {
      return { eligible: false, code: 'ORG_MISMATCH', reason: REASON.ORG_MISMATCH };
    }
    return { eligible: true, code: null, reason: null };
  }

  if (borrowerChannel === 'direct') {
    if (isSalaryChannel(guarantor)) {
      return { eligible: false, code: 'GUARANTOR_SALARIED', reason: REASON.DIRECT_GUARANTOR_SALARIED };
    }
    if (!isDirectChannel(guarantor)) {
      return { eligible: false, code: 'GUARANTOR_CHANNEL_UNKNOWN', reason: REASON.GUARANTOR_CHANNEL_UNKNOWN };
    }
    return { eligible: true, code: null, reason: null };
  }

  // Borrower channel unknown — refuse rather than guess which rule applies.
  return { eligible: false, code: 'BORROWER_CHANNEL_UNKNOWN', reason: REASON.BORROWER_CHANNEL_UNKNOWN };
}

/** True when the guarantor may stand for this borrower. */
function canGuarantee(borrower, guarantor) {
  return guarantorEligibility(borrower, guarantor).eligible;
}

/**
 * Load both profiles and decide. One query for the pair.
 *
 * @param {object} supabase configured client
 * @param {string} borrowerId  profiles.id of the borrower
 * @param {string} guarantorId profiles.id of the proposed guarantor
 * @returns {Promise<{eligible: boolean, code: string|null, reason: string|null}>}
 */
async function evaluateGuarantorEligibility(supabase, borrowerId, guarantorId) {
  if (!borrowerId || !guarantorId) {
    return { eligible: false, code: 'UNKNOWN', reason: REASON.UNKNOWN };
  }
  if (borrowerId === guarantorId) {
    return { eligible: false, code: 'SELF', reason: REASON.SELF };
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('id, contribution_method, contribution_type, organization_id')
    .in('id', [borrowerId, guarantorId]);
  if (error) throw error;

  const byId = new Map((data || []).map((p) => [p.id, p]));
  return guarantorEligibility(byId.get(borrowerId), byId.get(guarantorId));
}

module.exports = {
  REASON,
  contributionChannel,
  isSalaryChannel,
  isDirectChannel,
  guarantorEligibility,
  canGuarantee,
  evaluateGuarantorEligibility,
};
