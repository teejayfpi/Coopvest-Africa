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
    'This borrower is paid by salary deduction, but their employer is still being enrolled, so guarantors cannot be verified yet. This usually clears once the employer is on the platform — check back shortly, or contact support if it does not.',
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
 * What the member can actually do about a refusal.
 *
 * A blocked borrower needs more than an explanation: the pending-employer case
 * clears itself once the employer is enrolled, so the app can say "check back"
 * and link to the employer's status instead of a dead-end "contact support".
 */
const HELP = {
  SELF: { action: 'pick_another', url: null },
  GUARANTOR_NOT_SALARY: { action: 'pick_another', url: null },
  BORROWER_NO_ORG: { action: 'employer_pending', url: '/organizations/me' },
  ORG_MISMATCH: { action: 'pick_another', url: null },
  GUARANTOR_SALARIED: { action: 'pick_another', url: null },
  GUARANTOR_CHANNEL_UNKNOWN: { action: 'contact_support', url: null },
  BORROWER_CHANNEL_UNKNOWN: { action: 'contact_support', url: null },
  UNKNOWN: { action: 'contact_support', url: null },
};

/** The help entry for a refusal code, defaulting to contact support. */
function helpFor(code) {
  return HELP[code] || HELP.UNKNOWN;
}

/**
 * Build a refusal. One shape for every "no", so callers can rely on `help` and
 * `helpUrl` being present rather than re-deriving what to do from the code.
 *
 * @param {string} code    refusal code (also the HELP key)
 * @param {string} reason  member-facing copy
 * @param {object|null} [borrower] borrower profile, for the pending-employer name
 */
function refusal(code, reason, borrower) {
  const help = helpFor(code);
  return {
    eligible: false,
    code,
    reason,
    help: help.action,
    helpUrl: help.url,
    ...(code === 'BORROWER_NO_ORG'
      ? { pendingEmployerName: (borrower && borrower.pending_organization_name) || null }
      : {}),
  };
}


/**
 * The contribution channel a profile belongs to.
 *
 * The app writes `contribution_method` from the settings screen and
 * `contribution_type` from the KYC/sign-up screens; either identifies the
 * member, so they are read as one value (matching activationGate.js).
 *
 * When neither is set — legacy rows, or a member mid-onboarding — the employer
 * link decides, exactly as `activationGate.js` derives the fee exemption: an
 * organisation on file (linked or requested) means the member is paid by salary
 * deduction, because that is the only reason to hold an employer. A member with
 * no employer and no explicit channel is self-funded, i.e. direct deposit.
 * Refusing these members would lock out existing users over a NULL column, so
 * the channel is derived rather than treated as unknown.
 *
 * @returns {'salary'|'direct'|'unknown'}
 */
function contributionChannel(profile) {
  if (!profile) return 'unknown';
  const method = profile.contribution_method || profile.contribution_type;
  if (PAYROLL_METHODS.includes(method)) return 'salary';
  if (method === 'direct_deposit' || method === 'manual') return 'direct';

  // No explicit channel: fall back to the employer link.
  if (profile.organization_id || profile.pending_organization_name) return 'salary';
  if (method == null) return 'direct';

  // An unrecognised explicit value — refuse rather than guess.
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
    return refusal('UNKNOWN', REASON.UNKNOWN);
  }

  if (borrower.id && guarantor.id && borrower.id === guarantor.id) {
    return refusal('SELF', REASON.SELF);
  }

  const borrowerChannel = contributionChannel(borrower);

  if (borrowerChannel === 'salary') {
    if (!isSalaryChannel(guarantor)) {
      return refusal('GUARANTOR_NOT_SALARY', REASON.SALARY_GUARANTOR_NOT_SALARY);
    }
    if (!borrower.organization_id) {
      // The borrower is salaried but their employer is not enrolled yet, so
      // there is no organisation to match a guarantor against. Carry the
      // employer name so the app can tell the member which employer we are
      // waiting on rather than showing a bare "cannot be verified".
      return refusal('BORROWER_NO_ORG', REASON.BORROWER_NO_ORG, borrower);
    }
    if (!guarantor.organization_id || guarantor.organization_id !== borrower.organization_id) {
      return refusal('ORG_MISMATCH', REASON.ORG_MISMATCH);
    }
    return { eligible: true, code: null, reason: null, help: null, helpUrl: null };
  }

  if (borrowerChannel === 'direct') {
    if (isSalaryChannel(guarantor)) {
      return refusal('GUARANTOR_SALARIED', REASON.DIRECT_GUARANTOR_SALARIED);
    }
    if (!isDirectChannel(guarantor)) {
      return refusal('GUARANTOR_CHANNEL_UNKNOWN', REASON.GUARANTOR_CHANNEL_UNKNOWN);
    }
    return { eligible: true, code: null, reason: null, help: null, helpUrl: null };
  }

  // Borrower channel unknown — refuse rather than guess which rule applies.
  return refusal('BORROWER_CHANNEL_UNKNOWN', REASON.BORROWER_CHANNEL_UNKNOWN);
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
    return refusal('UNKNOWN', REASON.UNKNOWN);
  }
  if (borrowerId === guarantorId) {
    return refusal('SELF', REASON.SELF);
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('id, contribution_method, contribution_type, organization_id, pending_organization_name')
    .in('id', [borrowerId, guarantorId]);
  if (error) throw error;

  const byId = new Map((data || []).map((p) => [p.id, p]));
  return guarantorEligibility(byId.get(borrowerId), byId.get(guarantorId));
}

module.exports = {
  REASON,
  HELP,
  helpFor,
  refusal,
  contributionChannel,
  isSalaryChannel,
  isDirectChannel,
  guarantorEligibility,
  canGuarantee,
  evaluateGuarantorEligibility,
};
