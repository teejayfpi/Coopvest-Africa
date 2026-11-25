import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_config.dart';
import '../../config/theme_extension.dart';
import '../../core/extensions/number_extensions.dart';
import '../providers/wallet_provider.dart';
import '../screens/wallet/deposit_screen.dart';
import 'common/cards.dart';
import 'common/buttons.dart';

/// "Pay a month ahead" — the wallet's entry point to paying a future month.
///
/// The offer is priced by the backend (`obligations.advance`) so the
/// contribution, fee, loan instalment and any outstanding fines cannot drift
/// apart between client and server. This widget only renders what it is given
/// and forwards the month, which settlement needs: without it the backend would
/// credit the current month and the member would pay twice for one month.
///
/// Lives apart from `ObligationsCard` because that card returns an "all caught
/// up" state when nothing is due, which is exactly when a member is most likely
/// to pay ahead. Sharing the code would hide this offer from them.
class AdvancePaymentCard extends ConsumerWidget {
  const AdvancePaymentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligationsAsync = ref.watch(obligationsProvider);

    return obligationsAsync.when(
      data: (data) {
        final advance = (data['advance'] as Map?) ?? const {};
        final month = advance['month']?.toString() ?? '';
        final savings = (advance['savings'] as num?)?.toDouble() ?? 0.0;
        final fee = (advance['administrative_fee'] as num?)?.toDouble() ?? 0.0;

        final loans = ((advance['loans'] as List?) ?? const [])
            .whereType<Map>()
            .map((l) => {
                  'loan_id': l['loan_id']?.toString() ?? '',
                  'amount': (l['amount'] as num?)?.toDouble() ?? 0.0,
                })
            .where((l) => (l['amount'] as double) > 0)
            .toList();
        final fines = ((advance['fines'] as List?) ?? const [])
            .whereType<Map>()
            .map((f) => {
                  'id': f['id']?.toString() ?? '',
                  'amount': (f['amount'] as num?)?.toDouble() ?? 0.0,
                })
            .where((f) => (f['amount'] as double) > 0)
            .toList();

        final loansTotal =
            loans.fold<double>(0, (s, l) => s + (l['amount'] as double));
        final finesTotal =
            fines.fold<double>(0, (s, f) => s + (f['amount'] as double));
        final total = month.isEmpty
            ? 0.0
            : (advance['total'] as num?)?.toDouble() ??
                (savings + fee + loansTotal + finesTotal);

        // Nothing to offer: the month is unknown, or a fully exempt member with
        // no contribution and no outstanding loan has nothing to pre-pay.
        if (total <= 0) return const SizedBox.shrink();

        return AppCard(
          backgroundColor: context.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: CoopvestShape.iconChip(
                      CoopvestColors.iconTintGreen,
                      circular: true,
                    ),
                    child: const Icon(
                      Icons.event_repeat,
                      color: CoopvestColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: CoopvestShape.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay ahead',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CoopvestShape.gapXs),
                        Text(
                          'Settle ${_monthLabel(month)} now instead of waiting '
                          'for it to fall due.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CoopvestShape.gapMd),
              PrimaryButton(
                label:
                    'Pay ${_monthLabel(month)} in advance (\u20a6${total.formatNumber()})',
                icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                width: double.infinity,
                onPressed: () {
                  final allocations = <Map<String, dynamic>>[
                    {'type': 'savings', 'amount': savings},
                    if (fee > 0) {'type': 'fee', 'amount': fee},
                    for (final l in loans)
                      {
                        'type': 'loan_repayment',
                        'amount': l['amount'],
                        'loan_id': l['loan_id'],
                      },
                    for (final f in fines)
                      {
                        'type': 'fine',
                        'amount': f['amount'],
                        'fee_id': f['id'],
                      },
                  ];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DepositScreen(
                        initialAmount: total,
                        initialAllocations: allocations,
                        initialAllocationType: 'mixed',
                        initialTargetMonth: month,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: CoopvestShape.gapSm),
              Text(
                _caption(
                  savings: savings,
                  fee: fee,
                  loansTotal: loansTotal,
                  finesTotal: finesTotal,
                  monthLabel: _monthLabel(month),
                ),
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// '2026-09' → 'September 2026'. Falls back to the raw key so a malformed
  /// month never renders as blank.
  static String _monthLabel(String yyyyMm) {
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

  /// What the offer covers, spelled out so the total is never a mystery. An
  /// exempt member has no fee line at all, so naming a ₦0 fee would mislead.
  static String _caption({
    required double savings,
    required double fee,
    required double loansTotal,
    required double finesTotal,
    required String monthLabel,
  }) {
    final parts = <String>[
      '\u20a6${savings.formatNumber()} contribution',
      if (fee > 0) '\u20a6${fee.formatNumber()} administrative fee',
      if (loansTotal > 0) '\u20a6${loansTotal.formatNumber()} loan repayment',
      if (finesTotal > 0) '\u20a6${finesTotal.formatNumber()} in outstanding fines',
    ];
    final covered = parts.length == 1
        ? parts.single
        : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    final feeNote = fee > 0
        ? ''
        : ' Your administrative fee is deducted from salary, so it is not included.';
    return 'Covers your $covered for $monthLabel.$feeNote';
  }
}
