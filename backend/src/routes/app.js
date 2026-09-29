/**
 * Mobile onboarding home.
 *
 * The app's root gate (`AuthGuard`) needs one authoritative answer — "is this
 * member activated?" — before it shows either the member dashboard or the
 * registration-fee screen. Everything that gate acts on already lives on the
 * profile, so this endpoint returns just that summary and nothing else.
 *
 * Why a dedicated endpoint rather than reusing `GET /user/dashboard`: that
 * route is now gated behind `requireRegistrationPaid` (it returns savings and
 * referral figures, which belong to an activated member only). The gate itself
 * must stay reachable by an *unpaid* member, or they cannot learn what they
 * owe — so the summary has to live on an ungated route. It deliberately leaks
 * no balances or personal data: it is the same handful of booleans the server
 * already returns from `/auth/me`, expressed as a route the app can call
 * cheaply on every launch and resume.
 *
 * The decision is derived, never stored, and comes from `gateStatusFor` so the
 * app is routing on exactly what `requireActivated` / `requireRegistrationPaid`
 * will enforce — there is no second, client-side definition of "exempt".
 */

const express = require('express');
const supabase = require('../config/supabase');
const { authenticate, gateStatusFor } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

/** The profile columns the activation gate reads — see middleware/auth.js. */
const GATE_COLUMNS = [
  'id',
  'kyc_verified',
  'registration_fee_paid',
  'is_active',
  'is_flagged',
  'organization_id',
  'contribution_method',
  'contribution_type',
  'pending_organization_name',
].join(', ');

/**
 * GET /api/v1/app/home-status
 *
 * Returns the activation-gate summary for the signed-in member:
 *
 *   { activated, kyc_approved, registration_fee_paid,
 *     registration_fee_exempt, registration_fee_settled, blocked }
 *
 * The app routes on `registration_fee_settled`: the dashboard is gated on the
 * fee, not on KYC approval (members may see their own money while KYC is
 * reviewed), so `activated` — which also requires `kyc_approved` — is the wrong
 * field to route the dashboard on. `registration_fee_settled` is exactly what
 * `requireRegistrationPaid` enforces. A salary-deduction member with an
 * employer on file is `registration_fee_settled: true` and
 * `registration_fee_exempt: true` without paying in-app; a Direct Deposit
 * member stays `false` until the fee settles.
 *
 * On a lookup failure the settled flag is `false` — fail closed. The one caller
 * is the gate that re-fetches on launch and resume, so a transient failure
 * shows the activation screen for a moment rather than handing an unpaid member
 * the dashboard.
 */
router.get('/home-status', authenticate, async (req, res) => {
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select(GATE_COLUMNS)
      .eq('id', req.user.id)
      .maybeSingle();

    if (error) throw error;

    res.json({ success: true, gate: gateStatusFor(profile) });
  } catch (err) {
    logger.error('Get home status error:', err.message);
    res.json({
      success: true,
      gate: {
        activated: false,
        kyc_approved: false,
        registration_fee_paid: false,
        registration_fee_exempt: false,
        registration_fee_settled: false,
        blocked: false,
      },
    });
  }
});

module.exports = router;
