import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme_config.dart';
import '../../config/theme_extension.dart';
import '../../core/extensions/number_extensions.dart';
import '../../presentation/providers/wallet_provider.dart';
import '../screens/wallet/deposit_screen.dart';
import 'common/cards.dart';
import 'common/buttons.dart';

/// "Your obligations this month" — the member's savings contribution, loan
/// repayment, fines and fees for the current month, with a one-tap way to pay.
///
/// Shared by the home dashboard (directly below Quick Actions) and the loan
/// dashboard so both surfaces always show the same figures. The monthly savings
/// amount comes from the member's live contribution plan, so an update to the
/// contribution is reflected here without any further change.
class ObligationsCard extends ConsumerWidget {
  const ObligationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligationsAsync = ref.watch(obligationsProvider);

    return obligationsAsync.when(
      data: (data) {
        final monthlyContribution = (data['monthly_savings'] as num?)?.toDouble() ?? 0.0;
        final loansData = (data['loans'] as List?) ?? const [];
        final fines = (data['fines'] as List?) ?? const [];
        final fees = (data['fees'] as List?) ?? const [];

        final monthlyLoanRepayment = loansData.fold<double>(
          0,
          (sum, l) => sum + (((l as Map)['monthly_repayment'] as num?)?.toDouble() ?? 0),
        );
        final loanRemaining = loansData.fold<double>(
          0,
          (sum, l) => sum + (((l as Map)['remaining_balance'] as num?)?.toDouble() ?? 0),
        );
        final finesTotal = fines.fold<double>(
          0,
          (sum, f) => sum + (((f as Map)['amount'] as num?)?.toDouble() ?? 0),
        );
        final feesTotal = fees.fold<double>(
          0,
          (sum, f) => sum + (((f as Map)['amount'] as num?)?.toDouble() ?? 0),
        );
        // Recompute rather than trusting total_due: it must always equal the
        // rows rendered underneath it.
        final totalDue = monthlyContribution +
            monthlyLoanRepayment +
            finesTotal +
            feesTotal;

        final hasLoanObligation = loansData.isNotEmpty;
        final payableNow =
            hasLoanObligation ? monthlyLoanRepayment : monthlyContribution;

        return AppCard(
          backgroundColor: context.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your obligations this month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _obligationRow(
                context,
                'Monthly Savings \u2192 Member\'s savings',
                '\u20a6${monthlyContribution.formatNumber()}',
                CoopvestColors.primary,
              ),
              if (hasLoanObligation) ...[
                const SizedBox(height: 8),
                _obligationRow(
                  context,
                  'Loan Repayment \u2192 Loan balance',
                  '\u20a6${monthlyLoanRepayment.formatNumber()}',
                  CoopvestColors.info,
                ),
              ],
              if (finesTotal > 0) ...[
                const SizedBox(height: 8),
                ...fines.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _obligationRow(
                        context,
                        'Fine: ${_entryLabel(f)} \u2192 Penalty account',
                        '\u20a6${_entryAmount(f).formatNumber()}',
                        CoopvestColors.error,
                      ),
                    )),
              ],
              if (feesTotal > 0) ...[
                const SizedBox(height: 8),
                ...fees.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _obligationRow(
                        context,
                        'Fee: ${_entryLabel(f)}',
                        '\u20a6${_entryAmount(f).formatNumber()}',
                        CoopvestColors.warning,
                      ),
                    )),
              ],
              if (hasLoanObligation && loanRemaining > 0) ...[
                const SizedBox(height: 8),
                _obligationRow(
                  context,
                  'Loan balance remaining',
                  '\u20a6${loanRemaining.formatNumber()}',
                  CoopvestColors.warning,
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total due this month',
                    style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  Text(
                    '\u20a6${totalDue.formatNumber()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              if (payableNow > 0) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Pay Now',
                  icon: const Icon(Icons.bolt, color: Colors.white, size: 18),
                  width: double.infinity,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DepositScreen(
                        initialAllocationType:
                            hasLoanObligation ? 'loan_repayment' : 'monthly_contribution',
                        initialAmount: payableNow,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasLoanObligation
                      ? 'Pays your loan repayment of \u20a6${payableNow.formatNumber()} instantly.'
                      : 'Pays your monthly savings of \u20a6${payableNow.formatNumber()} instantly.',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _obligationRow(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  static String _entryLabel(Object? entry) {
    if (entry is Map) return entry['label']?.toString() ?? '';
    return '';
  }

  static double _entryAmount(Object? entry) {
    if (entry is Map) return (entry['amount'] as num?)?.toDouble() ?? 0;
    return 0;
  }
}
