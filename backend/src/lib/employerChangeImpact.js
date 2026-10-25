/**
 * Employer-change impact on an active loan.
 *
 * A salary-deduction borrower's guarantors must belong to the *same*
 * organisation as the borrower (lib/guarantorEligibility.js), and recovery runs
 * through that employer's payroll. Both facts are read from the borrower's
 * profile at the moment a guarantee is given.
 *
 * Changing employer — or switching channel — rewrites those profile columns.
 * Any guarantor who consented under the old details may no longer satisfy the
 * rule, and the payroll link the recovery depends on is gone. The guarantee
 * itself is stored, not re-derived, so nothing else notices. This module is the
 * single definition of "this change affects an active loan", extracted so it can
 * be unit-tested without Express or Supabase.
 *
 * The member is still allowed to correct their employment details — refusing
 * would leave them unable to tell us they have moved, which is worse. The change
 * is applied, but it is not applied *silently*: the caller raises it for admin
 * review and warns the member.
 */

const REASON =
  'This member has an active loan. Changing their employer or contribution channel can invalidate the guarantors who consented under the previous details, because a salary-deduction guarantor must belong to the same organisation as the borrower. Review the guarantors on the active loan and re-source them if needed.';

const MEMBER_WARNING =
  'Your contribution details were updated. Because you have an active loan, our team will review your guarantors — they may need to be replaced if your employer changed.';

const CODE = {
  ORGANISATION_CHANGED: 'ORGANISATION_CHANGED',
  CHANNEL_CHANGED: 'CHANNEL_CHANGED',
};

/**
 * Decide whether a contribution change needs admin review because the member
 * holds an active loan.
 *
 * @param {object}      input
 * @param {boolean}     input.hasActiveLoan  member has a loan in an active status
 * @param {string|null} input.previousOrgId  employer link before the change
 * @param {string|null} input.nextOrgId      employer link after the change
 * @param {string}      input.previousChannel 'salary' | 'direct' | 'unknown' before
 * @param {string}      input.nextChannel     'salary' | 'direct' | 'unknown' after
 * @returns {{reviewRequired: boolean, codes: string[], reason: string|null, memberWarning: string|null}}
 */
function assessEmployerChangeImpact({
  hasActiveLoan,
  previousOrgId = null,
  nextOrgId = null,
  previousChannel = 'unknown',
  nextChannel = 'unknown',
}) {
  const none = { reviewRequired: false, codes: [], reason: null, memberWarning: null };

  if (!hasActiveLoan) return none;

  const codes = [];
  if ((previousOrgId ?? null) !== (nextOrgId ?? null)) {
    codes.push(CODE.ORGANISATION_CHANGED);
  }
  if (previousChannel !== nextChannel) {
    codes.push(CODE.CHANNEL_CHANGED);
  }

  if (!codes.length) return none;

  return {
    reviewRequired: true,
    codes,
    reason: REASON,
    memberWarning: MEMBER_WARNING,
  };
}

module.exports = { REASON, MEMBER_WARNING, CODE, assessEmployerChangeImpact };
