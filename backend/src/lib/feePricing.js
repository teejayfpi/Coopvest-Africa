/**
 * Fee obligations are priced by the server, never by the client.
 *
 * The deposit screen lets a member edit the split of a "Pay Now" payment, which
 * is fine for savings but not for a fee: a fee is a fixed obligation, and the
 * settlement path marks a `member_fees` row paid on *any* positive amount
 * (`settleFeeRow` does not compare the amount). A client that sends
 * `{ fee: 1 }` therefore cleared a NGN1,500 administrative fee for NGN1.
 *
 * This module resolves what a fee leg should actually cost and whether the
 * amount sent covers it. The route refuses the charge when it does not, so the
 * member is told before any money moves rather than discovering it later.
 */

const FEE_TYPE_NAME = {
  fee: 'Administrative Fee',
  fine: 'Late Loan Repayment Fine',
  registration_fee: 'Registration Fee',
};

/**
 * Resolve the price a fee allocation must cover.
 *
 * An explicit `fee_id` is authoritative: it is the exact row shown to the
 * member, so its amount is what they owe. Otherwise fall back to the fee
 * catalogue for the type.
 *
 * @param {object} args
 * @param {Array<{id: string, amount: number, fee_type?: string, status?: string}>} args.rows
 *   Candidate `member_fees` rows (for `fee_id` resolution).
 * @param {Array<{name?: string, category?: string, amount?: number}>} args.catalogue
 *   `fee_types` rows.
 * @param {string} args.type  Allocation type: 'fee' | 'fine' | 'registration_fee'.
 * @returns {number|null} The amount owed, or null when it cannot be priced.
 */
function feePriceFor({ rows = [], catalogue = [], type }) {
  const match = rows.find((r) => r && r.amount != null);
  if (match) return Number(match.amount) || 0;

  const name = FEE_TYPE_NAME[type];
  if (!name) return null;
  const entry = catalogue.find(
    (f) => f && String(f.name || '').toLowerCase() === name.toLowerCase(),
  );
  if (!entry) return null;
  return Number(entry.amount) || 0;
}

/**
 * Which fee legs are underpaid.
 *
 * A leg is checked against the row it targets when it carries a `fee_id` — that
 * row's amount is what the member was shown, so paying less than it is the
 * part-payment this guard exists to stop.
 *
 * A leg with no `fee_id` is the remainder the app produces when a member pays
 * *more* than the outstanding row (`allocateFeeAmount` covers the row, then
 * emits the excess separately). That excess is not itself a price, so it is
 * only priced against the catalogue when it is the sole leg of its type;
 * otherwise the targeted row already accounts for the obligation and checking
 * the remainder again would reject a legitimate overpayment.
 *
 * A fee the server cannot price is left to the settlement path rather than
 * blocking a payment on a lookup failure. One kobo of tolerance absorbs float
 * dust without letting a real shortfall through.
 *
 * @returns {Array<{type: string, fee_id: string|null, sent: number, required: number}>}
 */
function findUnderpaidFees({ allocations = [], priceFor }) {
  const targetedTypes = new Set(
    allocations.filter((a) => a.fee_id).map((a) => a.type),
  );

  const short = [];
  for (const alloc of allocations) {
    if (!['fee', 'fine', 'registration_fee'].includes(alloc.type)) continue;
    if (!alloc.fee_id && targetedTypes.has(alloc.type)) continue;

    const required = priceFor(alloc);
    if (required == null) continue;
    const sent = Number(alloc.amount) || 0;
    if (sent + 0.01 < required) {
      short.push({ type: alloc.type, fee_id: alloc.fee_id || null, sent, required });
    }
  }
  return short;
}

module.exports = { feePriceFor, findUnderpaidFees, FEE_TYPE_NAME };
