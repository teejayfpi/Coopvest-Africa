import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/loan_models.dart' hide LoanStatus;
import '../../../data/models/rollover_models.dart';
import '../../providers/rollover_provider.dart';
import '../../providers/loan_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/rollover/rollover_common_widgets.dart';

/// Rollover Eligibility Check Screen
class RolloverEligibilityScreen extends ConsumerWidget {
  final Loan? loan;
  const RolloverEligibilityScreen({super.key, this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanProvider);
    final activeLoan = loan ?? loanState.loans.firstWhere((l) => l.status == 'active' || l.status == 'repaying', orElse: () => _getDemoLoan());
    final rolloverState = ref.watch(rolloverProvider);
    final rolloverNotifier = ref.read(rolloverProvider.notifier);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(title: Text('Rollover Eligibility', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLoanSummaryCard(context, activeLoan),
            const SizedBox(height: 24),
            _buildEligibilitySection(context, ref, rolloverNotifier, activeLoan),
            const SizedBox(height: 24),
            if (rolloverState.eligibility != null) _buildActionButtons(context, ref, rolloverNotifier, activeLoan),
          ],
        ),
      ),
    );
  }

  Loan _getDemoLoan() {
    final now = DateTime.now();
    return Loan(id: 'LOAN-DEMO', userId: 'user-id', amount: 100000, tenure: 6, interestRate: 7.0, monthlyRepayment: 18333, totalRepayment: 65000, status: 'active', guarantorsAccepted: 3, guarantorsRequired: 3, createdAt: now.subtract(const Duration(days: 90)), updatedAt: now.subtract(const Duration(days: 60)), approvedAt: now.subtract(const Duration(days: 85)), disbursedAt: now.subtract(const Duration(days: 84)));
  }

  Widget _buildLoanSummaryCard(BuildContext context, Loan loan) {
    final outstandingBalance = loan.amount - (loan.totalRepayment * 0.65);
    final repaymentPercentage = ((loan.totalRepayment / loan.amount * 100).clamp(0, 100)).toDouble();

    return Card(
      color: context.cardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [const Icon(Icons.account_balance, color: CoopvestColors.primary), const SizedBox(width: 8), Text(loan.id, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CoopvestColors.primary))]),
            const SizedBox(height: 16),
            _buildSummaryRow(context, 'Loan Amount', loan.amount),
            _buildSummaryRow(context, 'Outstanding Balance', outstandingBalance),
            _buildSummaryRow(context, 'Interest Rate', '${loan.interestRate}%'),
            _buildSummaryRow(context, 'Monthly Repayment', loan.monthlyRepayment),
            _buildSummaryRow(context, 'Status', loan.status.toUpperCase()),
            const Divider(height: 16),
            _buildRepaymentProgress(context, repaymentPercentage),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 13, color: context.textSecondary)), Text(value.toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary))]),
    );
  }

  Widget _buildRepaymentProgress(BuildContext context, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Repayment Progress', style: TextStyle(fontSize: 13, color: context.textSecondary)), Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CoopvestColors.primary))]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percentage / 100, minHeight: 8, backgroundColor: context.dividerColor, valueColor: AlwaysStoppedAnimation<Color>(percentage >= 50 ? CoopvestColors.success : CoopvestColors.warning))),
      ],
    );
  }

  Widget _buildEligibilitySection(BuildContext context, WidgetRef ref, RolloverNotifier rolloverNotifier, Loan loan) {
    final eligibility = ref.watch(rolloverProvider).eligibility;
    final isLoading = ref.watch(rolloverProvider).isLoading;

    if (isLoading) return const Center(child: CircularProgressIndicator(color: CoopvestColors.primary));
    if (eligibility == null) return Center(child: Column(children: [Text('Tap to check your rollover eligibility', style: TextStyle(color: context.textSecondary)), const SizedBox(height: 16), PrimaryButton(label: 'Check Eligibility', onPressed: () => rolloverNotifier.checkEligibility(loanId: loan.id))]));

    return Card(
      color: context.cardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(eligibility.isEligible ? Icons.check_circle : Icons.info, color: eligibility.isEligible ? CoopvestColors.success : CoopvestColors.warning), const SizedBox(width: 8), Text(eligibility.isEligible ? 'Eligible for Rollover' : 'Not Eligible', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary))]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            EligibilityCheckItem(isMet: eligibility.hasMinimum50PercentRepayment, title: '50% Principal Repaid', subtitle: eligibility.hasMinimum50PercentRepayment ? '${eligibility.repaymentPercentage.toStringAsFixed(1)}% repaid' : 'Need at least 50% repayment'),
            EligibilityCheckItem(isMet: eligibility.hasConsistentSavings, title: 'Consistent Monthly Savings', subtitle: eligibility.hasConsistentSavings ? '${eligibility.consecutiveSavingsMonths} consecutive months' : 'Need consistent savings history'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, RolloverNotifier rolloverNotifier, Loan loan) {
    final eligibility = ref.watch(rolloverProvider).eligibility;
    if (eligibility == null) return const SizedBox.shrink();
    if (!eligibility.isEligible) return Center(child: Text('Please meet all eligibility requirements to request a rollover.', style: TextStyle(fontSize: 13, color: context.textSecondary), textAlign: TextAlign.center));

    return Column(
      children: [
        PrimaryButton(label: 'Request Rollover', onPressed: () {}, width: double.infinity),
        const SizedBox(height: 12),
        TextButton(onPressed: () => rolloverNotifier.checkEligibility(loanId: loan.id), child: const Text('Refresh Eligibility')),
      ],
    );
  }
}
