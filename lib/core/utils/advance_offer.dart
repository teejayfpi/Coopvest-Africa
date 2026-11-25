import '../extensions/number_extensions.dart';

/// The backend's priced offer for paying a month ahead (`obligations.advance`).
///
/// Parsing, the payment allocation and the human-readable caption all live here
/// so the obligations card and the wallet's advance card cannot drift apart. A
/// leg that is priced in one place but not the other silently undercharges the
/// member, which is the failure this type exists to prevent.
class AdvanceOffer {
  const AdvanceOffer({
    required this.month,
    required this.savings,
    required this.administrativeFee,
    required this.loans,
    required this.fines,
    required this.total,
  });

  /// `yyyy-MM` of the month being paid. Empty when the backend priced nothing.
  final String month;
  final double savings;
  final double administrativeFee;
  final List<AdvanceLoanLeg> loans;
  final List<AdvanceFineLeg> fines;
  final double total;

  /// Whether there is anything to offer. A blank month, or a fully exempt member
  /// with no contribution and no outstanding loan, has nothing to pre-pay.
  bool get isPayable => month.isNotEmpty && total > 0;

  double get loansTotal => loans.fold(0.0, (s, l) => s + l.amount);
  double get finesTotal => fines.fold(0.0, (s, f) => s + f.amount);

  /// The legs `POST /payments/initialize` expects, in the order settlement
  /// applies them. The fee leg is omitted when the fee is zero: an exempt
  /// member's employer withholds it, and sending a zero leg would take it twice.
  List<Map<String, dynamic>> toAllocations() => [
        {'type': 'savings', 'amount': savings},
        if (administrativeFee > 0) {'type': 'fee', 'amount': administrativeFee},
        for (final l in loans)
          {
            'type': 'loan_repayment',
            'amount': l.amount,
            'loan_id': l.loanId,
          },
        for (final f in fines)
          {'type': 'fine', 'amount': f.amount, 'fee_id': f.id},
      ];

  /// '2026-09' → 'September 2026'. Falls back to the raw key so a malformed
  /// month never renders as blank.
  String get monthLabel => formatMonthKey(month);

  /// What the offer covers, spelled out so the total is never a mystery. An
  /// exempt member has no fee line at all, so naming a ₦0 fee would mislead.
  String get caption {
    final parts = <String>[
      '\u20a6${savings.formatNumber()} contribution',
      if (administrativeFee > 0)
        '\u20a6${administrativeFee.formatNumber()} administrative fee',
      if (loansTotal > 0) '\u20a6${loansTotal.formatNumber()} loan repayment',
      if (finesTotal > 0) '\u20a6${finesTotal.formatNumber()} in outstanding fines',
    ];
    final covered = parts.length == 1
        ? parts.single
        : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    final feeNote = administrativeFee > 0
        ? ''
        : ' Your administrative fee is deducted from salary, so it is not included.';
    return 'Covers your $covered for $monthLabel.$feeNote';
  }

  /// Reads the offer out of an `obligations` payload. Unknown or malformed
  /// entries are dropped rather than rendered as zero-value rows.
  static AdvanceOffer fromObligations(Map<String, dynamic> data) {
    final advance = (data['advance'] as Map?) ?? const {};
    final month = advance['month']?.toString() ?? '';
    final savings = (advance['savings'] as num?)?.toDouble() ?? 0.0;
    final fee = (advance['administrative_fee'] as num?)?.toDouble() ?? 0.0;

    final loans = ((advance['loans'] as List?) ?? const [])
        .whereType<Map>()
        .map((l) => AdvanceLoanLeg(
              loanId: l['loan_id']?.toString() ?? '',
              amount: (l['amount'] as num?)?.toDouble() ?? 0.0,
            ))
        .where((l) => l.amount > 0)
        .toList();

    final fines = ((advance['fines'] as List?) ?? const [])
        .whereType<Map>()
        .map((f) => AdvanceFineLeg(
              id: f['id']?.toString() ?? '',
              amount: (f['amount'] as num?)?.toDouble() ?? 0.0,
            ))
        .where((f) => f.amount > 0)
        .toList();

    final loansTotal = loans.fold<double>(0, (s, l) => s + l.amount);
    final finesTotal = fines.fold<double>(0, (s, f) => s + f.amount);
    final total = month.isEmpty
        ? 0.0
        : (advance['total'] as num?)?.toDouble() ??
            (savings + fee + loansTotal + finesTotal);

    return AdvanceOffer(
      month: month,
      savings: savings,
      administrativeFee: fee,
      loans: loans,
      fines: fines,
      total: total,
    );
  }
}

/// One loan's instalment for the month being paid. Carries the UUID because
/// settlement matches `loans.id`; targeting by the human-readable reference
/// would silently fall back to another loan.
class AdvanceLoanLeg {
  const AdvanceLoanLeg({required this.loanId, required this.amount});
  final String loanId;
  final double amount;
}

/// One outstanding fine folded into the offer. Fines are owed now whatever
/// month is being paid for, so they are settled by id in the same payment.
class AdvanceFineLeg {
  const AdvanceFineLeg({required this.id, required this.amount});
  final String id;
  final double amount;
}

/// '2026-09' → 'September 2026', falling back to the raw key when the value is
/// not a month so a malformed figure never renders as blank.
String formatMonthKey(String yyyyMm) {
  final parts = yyyyMm.split('-');
  if (parts.length != 2) return yyyyMm;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return yyyyMm;
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${names[month - 1]} $year';
}
