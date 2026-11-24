/**
 * Stop a single payment intent being charged twice.
 *
 * A member paid the NGN1,500 administrative fee twice, six minutes apart, and
 * the NGN5,000 November contribution twice two minutes apart. In both cases the
 * app showed no change after the first payment — once because the fee write
 * silently failed, once because the screen had not refreshed — so the member
 * tapped again and Paystack opened a second checkout. Each call to
 * `/payments/initialize` mints its own reference, so the gateway has no way to
 * see the two as the same intent.
 *
 * The guard therefore compares a *payment intent* — payment type, amount and
 * target month — against proofs created moments ago. Two windows, because the
 * two failure shapes differ:
 *
 * - `pending` (default 2 min): the existing checkout is still open. This is a
 *   double-tap, and the member should finish the checkout they already have
 *   rather than be charged on a second one. Kept short so that an abandoned
 *   checkout — which leaves a pending row and never resolves — does not lock the
 *   member out of retrying after a genuine failure.
 * - `approved` (default 15 min): the money already moved and the app has not
 *   caught up. This is the fee-bug shape: the member saw no change and paid
 *   again. Deliberately longer than the pending window, because the member only
 *   retries once they have given up on the first payment succeeding.
 *
 * Pure: the caller queries the candidate rows, this decides. Keeping the rule
 * here makes the window behaviour testable without a database.
 */

const DEFAULT_PENDING_WINDOW_MS = 2 * 60 * 1000;
const DEFAULT_APPROVED_WINDOW_MS = 15 * 60 * 1000;

function toKobo(value) {
  return Math.round(Number(value) * 100);
}

/**
 * The intent a proof represents, as stored.
 *
 * `payment_type` alone is not enough: `fine`, `fee` and `mixed` all persist as
 * `'other'` (see DB_PAYMENT_TYPE), so a NGN3,000 fine and a NGN3,000 fee payment
 * are indistinguishable by type and amount. The allocation breakdown keeps the
 * distinction, so it is folded into a stable signature — `fee:1500`, or
 * `mixed:1000+2000` for a split.
 */
function intentOf({ paymentType, allocations = [] }) {
  const legs = (Array.isArray(allocations) ? allocations : [])
    .filter((a) => a && Number(a.amount) > 0)
    .map((a) => `${a.type}:${toKobo(a.amount)}`)
    .sort();
  return `${paymentType}|${legs.join('+')}`;
}

/**
 * @param {object} args
 * @param {Array<object>} args.proofs  Recent proofs for this member, any status.
 * @param {string} args.paymentType    Stored payment type (e.g. 'other', 'monthly_contribution').
 * @param {Array<{type: string, amount: number}>} args.allocations  Intended breakdown.
 * @param {string|null} args.targetMonth 'YYYY-MM' the payment settles.
 * @param {number} [args.nowMs]
 * @param {number} [args.pendingWindowMs]
 * @param {number} [args.approvedWindowMs]
 * @returns {{proof: object, status: string, code: string}|null}
 */
function findDuplicatePayment({
  proofs = [],
  paymentType,
  allocations = [],
  targetMonth = null,
  nowMs = Date.now(),
  pendingWindowMs = DEFAULT_PENDING_WINDOW_MS,
  approvedWindowMs = DEFAULT_APPROVED_WINDOW_MS,
} = {}) {
  const wanted = intentOf({ paymentType, allocations });
  if (wanted.endsWith('|')) return null;

  for (const proof of proofs) {
    if (!proof || proof.deleted_at) continue;
    if (proof.payment_type !== paymentType) continue;

    const stored = intentOf({
      paymentType: proof.payment_type,
      allocations: proof.metadata?.allocations,
    });
    if (stored !== wanted) continue;

    // Months are only compared when both sides state one. Proofs written before
    // `target_month` existed carry null, and refusing to match them would let
    // exactly the legacy double-charge this guard exists to stop through.
    const proofMonth = proof.metadata?.target_month ?? null;
    if (targetMonth && proofMonth && proofMonth !== targetMonth) continue;

    const createdAt = new Date(proof.created_at).getTime();
    if (!Number.isFinite(createdAt)) continue;
    const age = nowMs - createdAt;
    if (age < 0) continue;

    if (proof.status === 'pending' && age <= pendingWindowMs) {
      return { proof, status: 'pending', code: 'PAYMENT_IN_PROGRESS' };
    }
    if (proof.status === 'approved' && age <= approvedWindowMs) {
      return { proof, status: 'approved', code: 'ALREADY_PAID' };
    }
  }
  return null;
}

module.exports = {
  findDuplicatePayment,
  DEFAULT_PENDING_WINDOW_MS,
  DEFAULT_APPROVED_WINDOW_MS,
};
