/**
 * Employer-enrolment status for a member.
 *
 * A salary-deduction member can only be guaranteed for once their employer is a
 * real, enrolled organisation: the same-organisation guarantor rule needs an
 * organisation id to match against, and recovery runs through that employer's
 * payroll. While the employer is still a pending name there is nothing to match,
 * so the member cannot name guarantors yet.
 *
 * That is a temporary, self-clearing state — the employer gets enrolled and the
 * block lifts — so the member should see it as a wait with a reason, not a
 * dead-end. This is the single definition of the state; the route and the
 * guarantor refusal both describe the same situation.
 *
 * @param {object|null} profile       profiles row (pending_organization_name, pending_organization_requested_at)
 * @param {object|null} organization  the enrolled organisation, when linked
 * @returns {{pending: boolean, employerName: string|null, requestedAt: string|null, blocksGuarantors: boolean, message: string|null}}
 */
function employerEnrollmentStatus(profile, organization) {
  const employerName = (profile && profile.pending_organization_name) || null;
  const requestedAt = (profile && profile.pending_organization_requested_at) || null;

  // A real link wins: the employer is enrolled, so there is nothing pending.
  const pending = Boolean(employerName) && !organization;

  return {
    pending,
    employerName,
    requestedAt,
    blocksGuarantors: pending,
    message: pending
      ? `We are enrolling ${employerName}. Once they are on the platform your salary deduction is enabled and you can add guarantors.`
      : null,
  };
}

module.exports = { employerEnrollmentStatus };
