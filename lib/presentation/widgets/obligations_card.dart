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
        // Once this month's contribution is paid it stops being "due" — the
        // standing amount moves to the next-month expectation instead, so a
        // member who has paid is not told they still owe this month's money.
        final paidThisMonth = data['month_paid_savings'] == true;
        // A member who joined this month has no obligation until their first
        // due date passes; showing ₦5,000 due would read as an instant arrears.
        final joinedThisMonth = data['joined_this_month'] == true;
        final currentMonth = data['current_month']?.toString() ?? '';
        final nextMonthSavings =
            (data['next_month_savings'] as num?)?.toDouble() ?? 0.0;
        final savingsDue =
            (paidThisMonth || joinedThisMonth) ? 0.0 : monthlyContribution;
        final nextMonthExpected =
            (nextMonthSavings > 0 ? nextMonthSavings : monthlyContribution) +
                monthlyLoanRepayment;

        // The monthly administrative fee, priced by the backend. It is part of
        // this month's obligation even before the billing worker has written a
        // `member_fees` row, so the card cannot derive it from the fee list.
        final adminFeeDue =
            (data['administrative_fee_due'] as num?)?.toDouble() ?? 0.0;

        // Recompute rather than trusting total_due: it must always equal the
        // rows rendered underneath it.
        final totalDue = savingsDue +
            monthlyLoanRepayment +
            finesTotal +
            feesTotal +
            adminFeeDue;

        final hasLoanObligation = loansData.isNotEmpty;

        // What "Pay Now" actually charges. Fines and fees are part of this
        // month's obligations and are listed in the rows above, so leaving them
        // out meant the card said "Total due ₦6,500" and then charged ₦5,000 —
        // the outstanding fee was silently dropped from the payment.
        //
        // Still deliberately excludes this month's savings once it is paid or
        // when the member is new (`savingsDue` is already 0 in those cases) and
        // excludes the running loan balance, which is not payable this month.
        final payableNow = savingsDue +
            monthlyLoanRepayment +
            finesTotal +
            feesTotal +
            adminFeeDue;

        // Paying a month ahead. `advance` is priced by the backend so the fee
        // and the contribution cannot drift apart between client and server.
        final advance = (data['advance'] as Map?) ?? const {};
        final advanceMonth = advance['month']?.toString() ?? '';
        final advanceSavings =
            (advance['savings'] as num?)?.toDouble() ?? 0.0;
        final advanceFee =
            (advance['administrative_fee'] as num?)?.toDouble() ?? 0.0;
        // Fines are owed now whatever month is being paid for, so the backend
        // folds them into the offer; the ids let each row settle exactly.
        final advanceFines =
            ((advance['fines'] as List?) ?? const [])
                .whereType<Map>()
                .map((f) => {
                      'id': f['id']?.toString() ?? '',
                      'label': f['label']?.toString() ?? 'Fine',
                      'amount': (f['amount'] as num?)?.toDouble() ?? 0.0,
                    })
                .where((f) => (f['amount'] as double) > 0)
                .toList();
        final advanceFinesTotal = advanceFines.fold<double>(
            0.0, (s, f) => s + (f['amount'] as double));
        // The loan instalment recurs monthly, so the backend prices it into the
        // advance offer. Each entry carries the loan UUID, which is what the
        // allocation must target - the human-readable reference would fall back
        // to whichever loan has the largest balance.
        final advanceLoans = ((advance['loans'] as List?) ?? const [])
            .whereType<Map>()
            .map((l) => {
                  'loan_id': l['loan_id']?.toString() ?? '',
                  'reference': l['reference']?.toString() ?? 'Loan',
                  'amount': (l['amount'] as num?)?.toDouble() ?? 0.0,
                })
            .where((l) => (l['amount'] as double) > 0)
            .toList();
        final advanceLoansTotal = advanceLoans.fold<double>(
            0.0, (s, l) => s + (l['amount'] as double));
        final advanceTotal = advanceMonth.isEmpty
            ? 0.0
            : (advance['total'] as num?)?.toDouble() ??
                (advanceSavings +
                    advanceFee +
                    advanceLoansTotal +
                    advanceFinesTotal);

        // Nothing due: show the "all caught up" state rather than a card of
        // ₦0 rows, which reads like a broken screen. The green check plus the
        // copy means the good news is not conveyed by colour alone.
        if (totalDue <= 0) {
          return AppCard(
            backgroundColor: context.cardBackground,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: CoopvestShape.iconChip(
                    CoopvestColors.successSurface,
                    circular: true,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: CoopvestColors.successText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: CoopvestShape.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paidThisMonth
                            ? "You've paid for ${_monthLabel(currentMonth)}"
                            : joinedThisMonth
                                ? 'Welcome to Coopvest'
                                : "You're all caught up",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CoopvestShape.gapXs),
                      Text(
                        paidThisMonth
                            ? 'Expected next month: \u20a6${nextMonthExpected.formatNumber()}'
                            : joinedThisMonth
                                ? 'Your first contribution will be due on your chosen day next month.'
                                : 'No contributions or repayments due.',
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
          );
        }

        return AppCard(
          backgroundColor: context.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your obligations this month',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: CoopvestColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CoopvestShape.gapMd),
              _obligationRow(
                context,
                paidThisMonth
                    ? 'Monthly Savings \u2192 paid for ${_monthLabel(currentMonth)}'
                    : 'Monthly Savings \u2192 Member\'s savings',
                '\u20a6${monthlyContribution.formatNumber()}',
                paidThisMonth ? CoopvestColors.successText : CoopvestColors.primary,
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
                        CoopvestColors.errorText,
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
                        CoopvestColors.pendingText,
                      ),
                    )),
              ],
              // The recurring monthly charge, shown even before it has been
              // billed as a row, so the total above is the sum of what is
              // listed here rather than a figure the member cannot reconcile.
              if (adminFeeDue > 0) ...[
                const SizedBox(height: 8),
                _obligationRow(
                  context,
                  'Monthly administrative fee',
                  '\u20a6${adminFeeDue.formatNumber()}',
                  CoopvestColors.pendingText,
                ),
              ],
              if (hasLoanObligation && loanRemaining > 0) ...[
                const SizedBox(height: 8),
                _obligationRow(
                  context,
                  'Loan balance remaining',
                  '\u20a6${loanRemaining.formatNumber()}',
                  CoopvestColors.pendingText,
                ),
              ],
              const Divider(height: 24),
              if (paidThisMonth && nextMonthExpected > 0) ...[
                _obligationRow(
                  context,
                  'Expected next month',
                  '\u20a6${nextMonthExpected.formatNumber()}',
                  CoopvestColors.pendingText,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    paidThisMonth ? 'Still due this month' : 'Total due this month',
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
                  onPressed: () {
                    // Build the allocation breakdown for every obligation the
                    // member is being asked to settle. A single obligation keeps
                    // its dedicated type; several open the split view, so the
                    // fee is actually applied to the fee record instead of the
                    // whole payment landing in savings.
                    final allocations = <Map<String, dynamic>>[
                      if (savingsDue > 0)
                        {'type': 'savings', 'amount': savingsDue},
                      if (monthlyLoanRepayment > 0)
                        {'type': 'loan_repayment', 'amount': monthlyLoanRepayment},
                      ...fines.map((f) => {
                            'type': 'fine',
                            'amount': _entryAmount(f),
                            if ((f as Map)['id'] != null) 'fee_id': f['id'],
                          }),
                      ...fees.map((f) => {
                            'type': 'fee',
                            'amount': _entryAmount(f),
                            if ((f as Map)['id'] != null) 'fee_id': f['id'],
                          }),
                      // The fee with no billed row yet has no id to point at;
                      // the backend settles it by month on the same payment.
                      if (adminFeeDue > 0)
                        {'type': 'fee', 'amount': adminFeeDue},
                    ];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DepositScreen(
                          initialAmount: payableNow,
                          initialAllocations: allocations,
                          initialAllocationType:
                              hasLoanObligation ? 'loan_repayment' : 'monthly_contribution',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Pays ₦${payableNow.formatNumber()} — your monthly savings, '
                  'loan repayment, fines and fees combined.',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
              if (advanceTotal > 0) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // Advance payment settles a *future* month, so the month is
                    // sent explicitly. Without it the backend would credit the
                    // current month and the member would pay twice for one
                    // month while still owing the next.
                    // An exempt member's employer withholds the fee, so the
                    // backend prices it at zero and no fee leg is sent.
                    final allocations = <Map<String, dynamic>>[
                      {'type': 'savings', 'amount': advanceSavings},
                      if (advanceFee > 0)
                        {'type': 'fee', 'amount': advanceFee},
                      for (final l in advanceLoans)
                        {
                          'type': 'loan_repayment',
                          'amount': l['amount'],
                          'loan_id': l['loan_id'],
                        },
                      for (final f in advanceFines)
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
                          initialAmount: advanceTotal,
                          initialAllocations: allocations,
                          initialAllocationType: 'mixed',
                          initialTargetMonth: advanceMonth,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: Text(
                    'Pay ${_monthLabel(advanceMonth)} in advance '
                    '(₦${advanceTotal.formatNumber()})',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _advanceCaption(
                    savings: advanceSavings,
                    fee: advanceFee,
                    loansTotal: advanceLoansTotal,
                    finesTotal: advanceFinesTotal,
                    monthLabel: _monthLabel(advanceMonth),
                  ),
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

  static String _entryLabel(Object? entry) {
    if (entry is Map) return entry['label']?.toString() ?? '';
    return '';
  }

  static double _entryAmount(Object? entry) {
    if (entry is Map) return (entry['amount'] as num?)?.toDouble() ?? 0;
    return 0;
  }
}

/// What the advance offer covers, spelled out so a member never has to infer it
/// from the total. An exempt member has no fee line at all — their employer
/// withholds it — so saying "₦0 administrative fee" would be misleading.
String _advanceCaption({
  required double savings,
  required double fee,
  required double loansTotal,
  required double finesTotal,
  required String monthLabel,
}) {
  final parts = <String>[
    '₦${savings.formatNumber()} contribution',
    if (fee > 0) '₦${fee.formatNumber()} administrative fee',
    if (loansTotal > 0) '₦${loansTotal.formatNumber()} loan repayment',
    if (finesTotal > 0) '₦${finesTotal.formatNumber()} in outstanding fines',
  ];
  final covered = parts.length == 1
      ? parts.single
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  final feeNote = fee > 0
      ? ''
      : ' Your administrative fee is deducted from salary, so it is not included.';
  return 'Covers your $covered for $monthLabel.$feeNote';
}
