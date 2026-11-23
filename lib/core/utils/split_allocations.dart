/// Builds the `allocations` payload for a split payment.
///
/// The split view rebuilds allocations from four amount fields (savings, loan,
/// fine, fee), which loses the identity of the rows those amounts came from.
/// Without an id the backend settles the *oldest* outstanding row of that type,
/// which may not be the one the member was shown as due.
///
/// Two rows of the same type cannot be collapsed into one allocation either: a
/// single `{fine, 3500}` against a ₦3,000 and a ₦500 row settles only the first
/// and marks it paid for the whole sum. So each known row is emitted on its own,
/// and only an amount typed beyond the known rows is sent without an id.
library;

/// A known outstanding row: its `member_fees` id and the amount shown as due.
class KnownFeeRow {
  const KnownFeeRow({required this.id, required this.amount});

  final String id;
  final double amount;
}

/// One entry of the `allocations` list sent to `POST /payments/initialize`.
Map<String, dynamic> allocation(
  String type,
  double amount, {
  String? feeId,
}) {
  return {
    'type': type,
    'amount': amount,
    if (feeId != null && feeId.isNotEmpty) 'fee_id': feeId,
  };
}

/// Split [amount] across [rows] in order, then emit any remainder unlinked.
///
/// A typed amount smaller than the rows covers only as many as it reaches, so
/// the member is never charged for a row they did not include.
List<Map<String, dynamic>> allocateFeeAmount(
  String type,
  double amount,
  List<KnownFeeRow> rows,
) {
  final allocations = <Map<String, dynamic>>[];
  var remaining = amount;

  for (final row in rows) {
    if (remaining <= 0) break;
    final applied = row.amount > remaining ? remaining : row.amount;
    if (applied <= 0) continue;
    allocations.add(allocation(type, applied, feeId: row.id));
    remaining -= applied;
  }

  if (remaining > 0) allocations.add(allocation(type, remaining));
  return allocations;
}
