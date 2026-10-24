/**
 * Contribution-channel persistence.
 *
 * A member's channel is stored on `profiles.contribution_method` /
 * `contribution_type`, plus an employer link (`organization_id` or
 * `pending_organization_name`). Two rules read it back and must not be told
 * different stories:
 *
 *   * the registration-fee exemption (lib/activationGate.js) — a
 *     salary-deduction member with an employer on file is exempt, so their fee
 *     is recovered by payroll rather than paid in-app;
 *   * guarantor eligibility (lib/guarantorEligibility.js) — a guarantor must
 *     share the borrower's channel, and a salary-deduction guarantor must share
 *     the borrower's organisation.
 *
 * Two sign-up routes can record the channel: the shortened path posts to
 * `POST /kyc/contribution-type`, and the full wizard posts everything to
 * `POST /auth/complete-registration`. They used to disagree — only the former
 * wrote the profile — so a member who came through the wizard ended up with a
 * NULL channel and was mis-classified by both rules. `planProfileChannelUpdate`
 * is the single definition both now call.
 */

/**
 * Build the `profiles` update that records a member's contribution channel.
 *
 * Pure: the caller resolves whether a requested organisation is a real, active
 * employer and passes that in, so the decision itself is unit-testable.
 *
 * @param {object}   input
 * @param {string}   input.contributionType  'salary_deduction' | 'direct_deposit'
 * @param {string}   [input.employerName]    free-text employer (enrolment not yet known)
 * @param {string}   [input.requestedOrgId]  an enrolled organisation the member picked
 * @param {boolean}  [input.orgIsActive]     whether `requestedOrgId` is a real, active org
 * @returns {object|null} a partial profiles update, or null when no channel was chosen
 */
function planProfileChannelUpdate({ contributionType, employerName, requestedOrgId, orgIsActive }) {
  const type =
    contributionType === 'salary_deduction'
      ? 'salary_deduction'
      : contributionType === 'direct_deposit'
        ? 'direct_deposit'
        : null;

  // No channel chosen yet (e.g. a partial save before the member picks one):
  // leave the profile untouched rather than guessing a channel.
  if (!type) return null;

  const update = {
    contribution_method: type === 'salary_deduction' ? 'payroll' : 'manual',
    contribution_type: type,
    updated_at: new Date().toISOString(),
  };

  if (type === 'salary_deduction') {
    const name = (employerName ?? '').toString().trim();
    if (requestedOrgId && orgIsActive) {
      // A real, active employer: link it and drop any stale pending request.
      update.organization_id = requestedOrgId;
      update.pending_organization_name = null;
    } else if (name) {
      // Employer named but not enrolled (or the id did not resolve): record it
      // as a pending request, which still counts as an employer on file so the
      // fee is recovered once payroll runs. Never link an unverified id.
      //
      // Clear any existing link too. This path is reached when a member changes
      // employer, and leaving the previous `organization_id` in place would
      // keep them attached to an employer they have left — payroll would go on
      // deducting for the old organisation, and the same-organisation guarantor
      // rule would match their guarantors against it.
      update.organization_id = null;
      update.pending_organization_name = name;
    } else {
      // Channel set to salary deduction with no employer named at all. Leave any
      // existing employer untouched: a settings toggle that does not collect an
      // employer must not erase the one already on file.
    }
  } else {
    // Self-funded: clear the employer so a stale link cannot keep the
    // salary-deduction exemption alive on a member who is no longer on payroll.
    update.organization_id = null;
    update.pending_organization_name = null;
  }

  return update;
}

module.exports = { planProfileChannelUpdate };
