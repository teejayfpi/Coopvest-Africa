import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_config.dart';
import '../../config/theme_extension.dart';
import '../../core/extensions/number_extensions.dart';
import '../../core/utils/advance_offer.dart';
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
        final advance = AdvanceOffer.fromObligations(data);

        // Nothing to offer: the month is unknown, or a fully exempt member with
        // no contribution and no outstanding loan has nothing to pre-pay.
        if (!advance.isPayable) return const SizedBox.shrink();

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
                          'Settle ${advance.monthLabel} now instead of waiting '
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
                    'Pay ${advance.monthLabel} in advance (\u20a6${advance.total.formatNumber()})',
                icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                width: double.infinity,
                onPressed: () {
                  final allocations = advance.toAllocations();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DepositScreen(
                        initialAmount: advance.total,
                        initialAllocations: allocations,
                        initialAllocationType: 'mixed',
                        initialTargetMonth: advance.month,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: CoopvestShape.gapSm),
              Text(
                advance.caption,
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
}
