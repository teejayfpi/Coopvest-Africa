import 'package:flutter/material.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/fee_schedule.dart';

/// The price list, shown once before the member commits any money.
///
/// This is a *disclosure*, not a consent: it does not gate the app and records
/// no acceptance. Binding acceptance happens at registration, where the member
/// is identifiable and the accepted version can be stamped. What this screen
/// adds is that nobody reaches the sign-up button without having seen the
/// charges — and, because the schedule is keyed by hash, sees them again if a
/// charge ever changes.
///
/// It is presented as a dismissible sheet rather than a wall. A price list the
/// member cannot get past is a price list they will resent, and the charges are
/// also reachable afterwards from the Fees & Charges section.
class FeeDisclosureSheet extends StatelessWidget {
  final FeeSchedule schedule;

  /// Called once the sheet is dismissed, so the caller can record the revision
  /// that was shown. Fired for both the primary and the "later" path — the
  /// member has seen the schedule either way.
  final VoidCallback onDismissed;

  const FeeDisclosureSheet({
    super.key,
    required this.schedule,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'What you pay',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Every charge Coopvest Africa applies, with the amount. '
              'Nothing else is charged.',
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final charge in schedule.charges)
                      _ChargeRow(charge: charge),
                    if (schedule.notCharged.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'We do not charge',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in schedule.notCharged)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check, size: 16, color: CoopvestColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismissed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoopvestColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  final FeeCharge charge;

  const _ChargeRow({required this.charge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      charge.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _frequencyLabel(charge),
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Formatters.formatCurrency(charge.amount.toDouble()),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  // A figure the member is not charged is shown in the muted
                  // tone, so the eye does not read their own savings as a cost.
                  color: charge.isCharge ? context.textPrimary : context.textSecondary,
                ),
              ),
            ],
          ),
          if (charge.components.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                charge.components
                    .map((c) => '${c.name} ${Formatters.formatCurrency(c.amount.toDouble())}')
                    .join(' · '),
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ),
          if (charge.note != null && charge.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                charge.note!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: context.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "one-time", "monthly", "per occurrence" — and for the contribution,
  /// make plain that it is not a charge at all.
  String _frequencyLabel(FeeCharge charge) {
    if (!charge.isCharge) return 'not a charge';
    if (charge.trigger != null && charge.trigger!.isNotEmpty) {
      return '${charge.frequency} · ${charge.trigger}';
    }
    return charge.frequency;
  }
}
