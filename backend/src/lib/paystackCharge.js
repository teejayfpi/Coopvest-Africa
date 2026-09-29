/**
 * Paystack charge verification shared by the webhook, the member-facing verify
 * endpoint and the failed-charge reconcile worker.
 *
 * Extracted so all three paths agree on what "the gateway says" means. In
 * particular the `ok: false` contract: an unreachable Paystack is NOT a failed
 * payment. Callers must leave the charge pending and retry, never treat a
 * transport error as a declined charge — that would mark a member's real
 * payment as failed.
 */

const PAYSTACK_BASE = 'https://api.paystack.co';

function secretKey() {
  return process.env.PAYSTACK_SECRET_KEY || null;
}

/**
 * Whether the server can actually reach Paystack.
 *
 * The env var being *present* is not enough: a truncated or public (`pk_`)
 * value makes every `/transaction/initialize` fail at the gateway with an
 * opaque error the member sees as "online payment failed". Checking the shape
 * here turns that into a clear, actionable message at boot and at the first
 * request.
 */
function paystackConfigured() {
  const key = secretKey();
  if (!key) return { ok: false, reason: 'missing', message: 'PAYSTACK_SECRET_KEY is not set.' };
  if (!key.startsWith('sk_')) {
    return { ok: false, reason: 'not_a_secret_key', message: 'PAYSTACK_SECRET_KEY is not a secret key (expected an sk_… value).' };
  }
  if (key.length < 20) {
    return { ok: false, reason: 'truncated', message: 'PAYSTACK_SECRET_KEY looks truncated.' };
  }
  return { ok: true, reason: null, message: null };
}

async function paystackFetch(path, options = {}) {
  const key = secretKey();
  if (!key) {
    const err = new Error('Paystack is not configured on the server.');
    err.statusCode = 503;
    err.code = 'PAYMENT_UNAVAILABLE';
    throw err;
  }
  const response = await fetch(`${PAYSTACK_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const payload = await response.json().catch(() => ({}));
  return { ok: response.ok, status: response.status, payload };
}

/**
 * Ask Paystack what happened to a reference.
 *
 * Returns `{ ok, gatewayStatus, data }`. `ok` is true only when Paystack
 * answered with a usable status; `gatewayStatus` is one of
 * `success | failed | reversed | abandoned | pending` (or null when ok=false).
 */
async function verifyCharge(reference) {
  if (!reference) return { ok: false, gatewayStatus: null, data: null };
  try {
    const { ok, payload } = await paystackFetch(`/transaction/verify/${encodeURIComponent(reference)}`);
    if (!ok || !payload) return { ok: false, gatewayStatus: null, data: null };
    // Paystack returns `status: true` for a successful *API call*; the
    // transaction's own state is `data.status`.
    const data = payload.data || null;
    if (!data) return { ok: false, gatewayStatus: null, data: null };
    return { ok: true, gatewayStatus: data.status || null, data };
  } catch (err) {
    return { ok: false, gatewayStatus: null, data: null, error: err.message };
  }
}

/**
 * Classify a gateway failure payload.
 *
 * Pure and shared by the webhook, the verify endpoint and the reconcile worker
 * so all three agree. The branching that matters:
 *
 *   * `reversed` — Paystack reversed a debit. The member WAS debited. This is
 *     the case that must never be silently dropped.
 *   * `failed`   — a decline, or a debit-on-hold that has not resolved. A debit
 *     is possible, so it needs a look.
 *   * `abandoned`— the member closed the checkout. No debit; record, no alarm.
 */
function classifyFailure({ eventName, status, gatewayResponse } = {}) {
  const gatewayStatus = eventName === 'transfer.reversed'
    ? 'reversed'
    : (status || 'failed');

  return {
    gatewayStatus,
    // True whenever money may have left the member's account.
    possibleDebit: gatewayStatus === 'reversed' || gatewayStatus === 'failed',
    // Abandoned checkouts are noise for admins; everything else is actionable.
    alertAdmins: gatewayStatus !== 'abandoned',
    gatewayMessage: gatewayResponse || null,
  };
}

module.exports = { paystackFetch, verifyCharge, classifyFailure, secretKey, paystackConfigured, PAYSTACK_BASE };