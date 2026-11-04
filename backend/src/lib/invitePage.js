/**
 * Renders the referral invite landing page served at `/join?ref=CODE`.
 *
 * Kept out of `server.js` so the sanitisation is unit-testable. `ref` arrives
 * straight from the query string, so it is never interpolated into the page
 * without being validated first.
 */

/** Referral codes are alphanumeric with `-`/`_`; anything else is discarded. */
function sanitiseReferralCode(raw) {
  const value = typeof raw === 'string' ? raw.trim().slice(0, 20) : '';
  return /^[A-Za-z0-9_-]*$/.test(value) ? value : '';
}

function escapeHtml(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.coopvest.app';

function renderInvitePage(rawRef) {
  const ref = sanitiseReferralCode(rawRef);
  const deepLink = ref
    ? `coopvest://register?ref=${encodeURIComponent(ref)}`
    : 'coopvest://register';

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Join Coopvest Africa</title>
<meta property="og:title" content="Join Coopvest Africa">
<meta property="og:description" content="Save, borrow and grow with a cooperative built for you.">
<style>
  body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#0f172a;color:#f8fafc;display:flex;min-height:100vh;align-items:center;justify-content:center}
  .card{max-width:420px;width:100%;margin:24px;padding:32px;background:#1e293b;border-radius:16px;text-align:center}
  h1{font-size:22px;margin:0 0 8px}
  p{color:#94a3b8;font-size:14px;line-height:1.5}
  .code{display:inline-block;margin:16px 0;padding:10px 18px;background:#0f172a;border:1px dashed #38bdf8;border-radius:8px;color:#38bdf8;font-weight:700;letter-spacing:2px}
  a.btn{display:block;margin:12px 0 0;padding:14px;border-radius:10px;text-decoration:none;font-weight:600}
  .primary{background:#38bdf8;color:#0f172a}
  .secondary{background:transparent;color:#94a3b8;border:1px solid #334155}
</style>
</head>
<body>
  <div class="card">
    <h1>You have been invited to Coopvest Africa</h1>
    <p>Open the app to create your account. Your friend's referral code is applied automatically.</p>
    ${ref ? `<div class="code">${escapeHtml(ref)}</div>` : ''}
    <a class="btn primary" href="${escapeHtml(deepLink)}">Open the app</a>
    <a class="btn secondary" href="${escapeHtml(PLAY_STORE_URL)}">Get it on Google Play</a>
    <p style="margin-top:20px;font-size:12px">Already have the app? Open it and enter the code on the sign-up screen.</p>
  </div>
</body>
</html>`;
}

module.exports = { renderInvitePage, sanitiseReferralCode, escapeHtml, PLAY_STORE_URL };
