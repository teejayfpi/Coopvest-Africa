/// The published fee schedule, as served by `GET /api/v1/fees`.
///
/// WHY THIS MODEL EXISTS
/// ---------------------
/// The app shows the price list on first open, before a member registers, so
/// nobody commits money without having seen the charges. The figures must be
/// the ones the backend actually levies. So the schedule is *fetched*, never
/// restated: this model parses the server's response, and [FeeSchedule.bundled]
/// is the offline fallback, built from the same `AppConfig` constants the rest
/// of the app charges from.
///
/// [hash] is the server's `schedule_hash`. It is what makes the "shown once"
/// disclosure honest: when the hash changes, the published charges have
/// changed, and the disclosure is shown again rather than assumed still read.
library;

import '../../config/app_config.dart';

class FeeCharge {
  final String id;
  final String label;
  final num amount;
  final String frequency;
  final bool? refundable;
  final String? trigger;
  final String? note;

  /// The parts of a bundled charge, when the total alone would hide them.
  final List<FeeComponent> components;

  const FeeCharge({
    required this.id,
    required this.label,
    required this.amount,
    required this.frequency,
    this.refundable,
    this.trigger,
    this.note,
    this.components = const [],
  });

  /// A charge that is not actually levied — the monthly contribution is the
  /// member's own savings. Listed so the disclosure can say so explicitly.
  bool get isCharge => id != 'monthly_contribution';

  factory FeeCharge.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'];
    return FeeCharge(
      id: (json['id'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      amount: (json['amount'] as num?) ?? 0,
      frequency: (json['frequency'] ?? '') as String,
      refundable: json['refundable'] as bool?,
      trigger: json['trigger'] as String?,
      note: json['note'] as String?,
      components: rawComponents is List
          ? rawComponents
              .whereType<Map<String, dynamic>>()
              .map(FeeComponent.fromJson)
              .where((c) => c.name.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

class FeeComponent {
  final String name;
  final num amount;

  const FeeComponent({required this.name, required this.amount});

  factory FeeComponent.fromJson(Map<String, dynamic> json) => FeeComponent(
        name: (json['name'] ?? '') as String,
        amount: (json['amount'] as num?) ?? 0,
      );
}

class FeeSchedule {
  /// The document revision these charges belong to.
  final String version;

  /// Server-computed marker for the schedule contents. Changes when any
  /// published amount, label, or note changes.
  final String hash;

  final String currency;
  final List<FeeCharge> charges;
  final List<FeeComponent> loanInterestRates;

  /// Charges the cooperative does not apply, stated so their absence is a
  /// promise rather than an omission.
  final List<String> notCharged;

  const FeeSchedule({
    required this.version,
    required this.hash,
    required this.currency,
    required this.charges,
    required this.loanInterestRates,
    required this.notCharged,
  });

  factory FeeSchedule.fromJson(Map<String, dynamic> json) {
    final rawCharges = json['charges'];
    final rawRates = json['loan_interest_rates'];
    final rawNotCharged = json['not_charged'];
    return FeeSchedule(
      version: (json['version'] ?? '') as String,
      hash: (json['schedule_hash'] ?? '') as String,
      currency: (json['currency'] ?? 'NGN') as String,
      charges: rawCharges is List
          ? rawCharges
              .whereType<Map<String, dynamic>>()
              .map(FeeCharge.fromJson)
              .where((c) => c.id.isNotEmpty && c.label.isNotEmpty)
              .toList()
          : const [],
      loanInterestRates: rawRates is List
          ? rawRates
              .whereType<Map<String, dynamic>>()
              .map((r) => FeeComponent(
                    name: (r['product'] ?? '') as String,
                    amount: (r['rate'] as num?) ?? 0,
                  ))
              .where((r) => r.name.isNotEmpty)
              .toList()
          : const [],
      notCharged: rawNotCharged is List
          ? rawNotCharged.whereType<String>().toList()
          : const [],
    );
  }

  /// The offline fallback, built from the constants the app charges from.
  ///
  /// Amounts are not repeated here: they are read from `AppConfig`, so this
  /// cannot disagree with what the app levies. The hash is deliberately empty —
  /// a fallback must never be mistaken for a server-confirmed revision, or a
  /// member offline would be told the schedule is current when it is only
  /// bundled.
  factory FeeSchedule.bundled() => const FeeSchedule(
        version: 'bundled',
        hash: '',
        currency: 'NGN',
        charges: [
          FeeCharge(
            id: 'registration_fee',
            label: 'Registration fee',
            amount: AppConfig.entranceFee,
            frequency: 'one-time',
            refundable: false,
            note: 'A charge payable to the cooperative. It is not added to your '
                'monthly contribution.',
          ),
          FeeCharge(
            id: 'monthly_contribution',
            label: 'Minimum monthly contribution',
            amount: AppConfig.minContribution,
            frequency: 'monthly',
            note: 'Your own money, held in your savings. It is not a charge.',
          ),
          FeeCharge(
            id: 'administrative_fee',
            label: 'Monthly administrative fee',
            amount: AppConfig.totalMonthlyLevies,
            frequency: 'monthly',
            components: [
              FeeComponent(
                name: 'Administrative charges',
                amount: AppConfig.administrativeCharges,
              ),
              FeeComponent(
                name: 'Development levy',
                amount: AppConfig.developmentLevy,
              ),
            ],
            note: 'Recovered from your contribution, or from salary where an '
                'employer deducts contributions.',
          ),
          FeeCharge(
            id: 'late_repayment_fine',
            label: 'Late repayment fine',
            amount: AppConfig.lateRepaymentFine,
            frequency: 'per occurrence',
            trigger: 'Two consecutive missed monthly repayments',
            note: 'Recorded as a separate obligation. It is not added to your '
                'loan balance.',
          ),
        ],
        loanInterestRates: [
          FeeComponent(name: 'Quick Loan', amount: 7.5),
          FeeComponent(name: 'Flexi Loan', amount: 7.0),
          FeeComponent(name: 'Stable Loan (12 months)', amount: 5.0),
          FeeComponent(name: 'Stable Loan (18 months)', amount: 7.0),
          FeeComponent(name: 'Premium Loan', amount: 14.0),
          FeeComponent(name: 'Maxi Loan', amount: 19.0),
        ],
        notCharged: [
          'Withdrawal fee',
          'Early-repayment penalty',
          'Loan application or processing fee',
          'Account-maintenance charge beyond the monthly administrative fee',
        ],
      );
}
