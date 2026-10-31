/**
 * KYC gate for credit products.
 *
 * A loan is credit, so a member must have passed identity verification before
 * an application can be reviewed. Until now the only check was client-side —
 * `loan_application_screen.dart` — and it treated a `rejected` submission as
 * "submitted", so a rejected member passed the app's gate and the server
 * accepted the application anyway. The server is now authoritative.
 *
 * `profiles.kyc_verified` is the single source of truth, exactly as it is for
 * the activation gate (`lib/activationGate.js`). The `kyc` row's lifecycle
 * status is consulted only to explain *why* a member is blocked, so the app can
 * send them to the right place.
 */

/** `kyc.status` values that mean the member has submitted and we are waiting. */
const KYC_PENDING_STATUSES = [
  'submitted',
  'in_review',
  'under_review',
  'pending_review',
];

/** Member-facing copy per block reason. */
const KYC_BLOCK_MESSAGES = {
  rejected:
    'Your identity verification (KYC) was not approved. Please review what was flagged, resubmit your details, and try again once they are approved.',
  pending:
    'Your identity verification (KYC) is still under review. You can apply for a loan once it has been approved.',
  not_started:
    'Please complete your identity verification (KYC) before applying for a loan.',
};

/**
 * Decide whether a member's KYC permits a loan application.
 *
 * @param {object|null} profile  the member's `profiles` row (needs kyc_verified)
 * @param {object|null} kycRow   the member's `kyc` row (needs status); optional
 * @returns {{allowed: boolean, reason: string, message: string|null}}
 */
function kycGateFor(profile, kycRow) {
  // Approved is the only state that opens the gate. Note this is `=== true`,
  // not truthy: a null/undefined flag must never read as verified.
  if (profile && profile.kyc_verified === true) {
    return { allowed: true, reason: 'verified', message: null };
  }

  const status = String((kycRow && kycRow.status) || '').toLowerCase();
  const reason = status === 'rejected'
    ? 'rejected'
    : KYC_PENDING_STATUSES.includes(status)
      ? 'pending'
      : 'not_started';

  return { allowed: false, reason, message: KYC_BLOCK_MESSAGES[reason] };
}

module.exports = { kycGateFor, KYC_PENDING_STATUSES, KYC_BLOCK_MESSAGES };
