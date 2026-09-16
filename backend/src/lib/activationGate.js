/**
 * Membership activation-gate rules.
 *
 * Extracted from `middleware/auth.js` so the exemption logic can be unit-tested
 * without standing up Express or Supabase. The middleware imports these; there
 * is one definition, not two.
 *
 * The pipeline is:
 *   REGISTERED → KYC APPROVED → REGISTRATION FEE SETTLED → ACCOUNT ACTIVE
 *
 * "Settled" covers two cases, and the distinction matters to the member:
 *   * `registration_fee_paid = TRUE` — they paid it (in-app, or an admin
 *     verified a proof).
 *   * **Exempt** — they contribute by salary deduction and have an employer on
 *     file, so the fee is recovered from their salary and remitted alongside
 *     their contributions. Requiring them to also pay in-app would double-charge
 *     them and lock them out of the app until payroll happened to run.
 *
 * The exemption is derived, never stored: a stored flag can drift out of sync
 * with the contribution method, whereas the derivation cannot. This mirrors
 * `public.member_registration_fee_settled()` in migration 035 — keep the two in
 * step.
 */

/** Contribution-method values that mean "employer deducts at source". */
const PAYROLL_METHODS = ['payroll', 'salary_deduction', 'salary-based'];

/**
 * True when the member's registration fee is settled or they are exempt from
 * paying it in-app.
 */
function isRegistrationFeeSettled(profile) {
  if (!profile) return false;
  if (profile.registration_fee_paid === true) return true;

  // The app writes `contribution_method` from the settings screen and
  // `contribution_type` from the KYC screen; either identifies the member.
  const method = profile.contribution_method || profile.contribution_type;
  const onPayroll = PAYROLL_METHODS.includes(method);
  return onPayroll && Boolean(profile.organization_id);
}

/** True when the fee is waived rather than paid — used for member-facing copy. */
function isRegistrationFeeExempt(profile) {
  if (!profile) return false;
  if (profile.registration_fee_paid === true) return false;
  return isRegistrationFeeSettled(profile);
}

/**
 * Build the machine-readable gate summary returned to the app, so it can route
 * to the right onboarding step instead of showing a generic 403.
 */
function gateStatusFor(profile) {
  const kycApproved = profile?.kyc_verified === true;
  const feePaid = profile?.registration_fee_paid === true;
  const feeSettled = isRegistrationFeeSettled(profile);
  const blocked = profile?.is_active === false || profile?.is_flagged === true;

  return {
    activated: kycApproved && feeSettled && !blocked,
    kyc_approved: kycApproved,
    // Kept for compatibility with the app's existing gate logic;
    // `registration_fee_settled` is the field the gate now acts on.
    registration_fee_paid: feePaid,
    registration_fee_exempt: isRegistrationFeeExempt(profile),
    registration_fee_settled: feeSettled,
    blocked,
  };
}

module.exports = {
  PAYROLL_METHODS,
  isRegistrationFeeSettled,
  isRegistrationFeeExempt,
  gateStatusFor,
};
