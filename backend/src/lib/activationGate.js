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
 * `public.member_registration_fee_settled()` in migration 063 — keep the two in
 * step.
 *
 * A *linked* employer (`organization_id`) is verified — an admin approved the
 * enrolment — so it exempts indefinitely. A *named* employer
 * (`pending_organization_name`) is self-declared and unverified, so it defers
 * the fee only for a bounded grace window anchored on
 * `pending_organization_requested_at`. Without that bound, a member could
 * register as salary deduction, name an employer that is never enrolled, and
 * never pay the registration fee or the monthly administrative fee while
 * nothing recovers either. When the window lapses the fee becomes payable in
 * the app again; the honest member who is merely waiting on enrolment can pay
 * it and be reimbursed when payroll posts, and the member who named a
 * non-existent employer simply pays what they owe.
 */

/** Contribution-method values that mean "employer deducts at source". */
const PAYROLL_METHODS = ['payroll', 'salary_deduction', 'salary-based'];

/** How long a self-declared (unverified) employer defers the fee, in days. */
const DEFAULT_PENDING_EMPLOYER_GRACE_DAYS = 45;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Tolerance for an anchor that reads slightly in the future, absorbing ordinary
 * clock skew between the app server and the database.
 */
const ANCHOR_FUTURE_TOLERANCE_MS = 5 * 60 * 1000;

/**
 * Grace window for a self-declared employer, overridable so operations can
 * tighten or widen it without a code change.
 */
function pendingEmployerGraceDays() {
  const raw = Number(process.env.PENDING_EMPLOYER_FEE_GRACE_DAYS);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_PENDING_EMPLOYER_GRACE_DAYS;
}

/**
 * True when the member named an employer that is not enrolled yet and the
 * deferral window it opened is still running.
 *
 * The window is anchored on `pending_organization_requested_at`, written once
 * when the request is first recorded and never reset by re-submitting. A
 * missing or unparseable anchor does not defer anything: an unverifiable claim
 * must not be able to grant the exemption.
 *
 * An anchor in the future is rejected. A far-future anchor would otherwise make
 * the elapsed time negative, pass the window check, and defer the fee
 * permanently — and the anchor is a member-writable column, so that is reachable
 * without any privileged access. Small skew is tolerated.
 */
function isPendingEmployerWithinGrace(profile, nowMs = Date.now()) {
  if (!profile?.pending_organization_name) return false;
  const anchoredAt = Date.parse(profile.pending_organization_requested_at || '');
  if (!Number.isFinite(anchoredAt)) return false;
  if (anchoredAt > nowMs + ANCHOR_FUTURE_TOLERANCE_MS) return false;
  return nowMs - anchoredAt <= pendingEmployerGraceDays() * DAY_MS;
}

/**
 * True when the member's registration fee is settled or they are exempt from
 * paying it in-app.
 */
function isRegistrationFeeSettled(profile, nowMs = Date.now()) {
  if (!profile) return false;
  if (profile.registration_fee_paid === true) return true;

  // The app writes `contribution_method` from the settings screen and
  // `contribution_type` from the KYC/sign-up screens; either identifies the
  // member.
  const method = profile.contribution_method || profile.contribution_type;
  const onPayroll = PAYROLL_METHODS.includes(method);
  if (!onPayroll) return false;

  // An employer must be on file, because that is the mechanism the fee is
  // recovered through. A linked organisation is verified and exempts
  // indefinitely. A named employer that is not enrolled yet still counts, but
  // only inside the deferral window — the member has committed to payroll
  // deduction and named the employer, and the fee is recovered once that
  // employer is enrolled and the next remittance posts. Withholding the
  // exemption until an admin approves the request would lock the member out of
  // the app over admin latency, so the window covers that latency without
  // deferring the fee forever.
  return Boolean(profile.organization_id) || isPendingEmployerWithinGrace(profile, nowMs);
}

/** True when the fee is waived rather than paid — used for member-facing copy. */
function isRegistrationFeeExempt(profile, nowMs = Date.now()) {
  if (!profile) return false;
  if (profile.registration_fee_paid === true) return false;
  return isRegistrationFeeSettled(profile, nowMs);
}

/**
 * True when the member's contributions are withheld by an employer.
 *
 * The app writes `contribution_method` from the settings screen and
 * `contribution_type` from the KYC/sign-up screens; either identifies the
 * member, so accept both.
 */
function isPayrollMember(profile) {
  if (!profile) return false;
  const method = profile.contribution_method || profile.contribution_type;
  return PAYROLL_METHODS.includes(method);
}

/**
 * True when the monthly administrative fee is recovered from the member's
 * salary rather than paid in-app.
 *
 * Same mechanism as the registration-fee exemption above: the employer
 * deduction is the channel, so showing the fee as an in-app obligation would
 * charge the member a second time for money their employer already withholds.
 * An employer must be on file for the same reason — without one there is no
 * deduction to recover the fee from, so the in-app obligation stands. And, as
 * above, only a *linked* employer or a named one still inside its deferral
 * window counts; a stale self-declared name must not hide the fee forever.
 *
 * Fines are deliberately NOT covered: a penalty is not part of the standard
 * monthly deduction, so it stays payable in the app.
 */
function isAdministrativeFeeExempt(profile, nowMs = Date.now()) {
  if (!profile) return false;
  if (!isPayrollMember(profile)) return false;
  return Boolean(profile.organization_id) || isPendingEmployerWithinGrace(profile, nowMs);
}

/**
 * Build the machine-readable gate summary returned to the app, so it can route
 * to the right onboarding step instead of showing a generic 403.
 */
function gateStatusFor(profile, nowMs = Date.now()) {
  const kycApproved = profile?.kyc_verified === true;
  const feePaid = profile?.registration_fee_paid === true;
  const feeSettled = isRegistrationFeeSettled(profile, nowMs);
  const blocked = profile?.is_active === false || profile?.is_flagged === true;

  return {
    activated: kycApproved && feeSettled && !blocked,
    kyc_approved: kycApproved,
    // Kept for compatibility with the app's existing gate logic;
    // `registration_fee_settled` is the field the gate now acts on.
    registration_fee_paid: feePaid,
    registration_fee_exempt: isRegistrationFeeExempt(profile, nowMs),
    registration_fee_settled: feeSettled,
    // True while a self-declared employer is still deferring the fee (as opposed
    // to a verified linked employer, which is a genuine exemption). The app uses
    // it to explain the waiver, and once the window lapses, why the fee is due.
    registration_fee_deferred: !feePaid && isPendingEmployerWithinGrace(profile, nowMs),
    blocked,
  };
}

module.exports = {
  PAYROLL_METHODS,
  DEFAULT_PENDING_EMPLOYER_GRACE_DAYS,
  isPendingEmployerWithinGrace,
  isRegistrationFeeSettled,
  isRegistrationFeeExempt,
  isPayrollMember,
  isAdministrativeFeeExempt,
  gateStatusFor,
};
