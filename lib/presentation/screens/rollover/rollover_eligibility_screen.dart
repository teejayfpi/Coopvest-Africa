import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../data/models/loan_models.dart' hide LoanStatus;
import '../../../data/models/rollover_models.dart';
import '../../providers/rollover_provider.dart';
import '../../providers/loan_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/rollover/rollover_common_widgets.dart';

/// Rollover Eligibility Check Screen
/// Shows if a member is eligible for loan rollover based on business rules
class RolloverEligibilityScreen extends ConsumerWidget {
  final Loan? loan;

  const RolloverEligibilityScreen({super.key, this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanProvider);
    final activeLoan = loan ?? loanState.loans.firstWhere(
      (l) => l.status == 'active' || l.status == 'repaying',
      orElse: () => _getDemoLoan(),
    );
    
    final rolloverState = ref.watch(rolloverProvider);
    final rolloverNotifier = ref.read(rolloverProvider.notifier);

    // Check eligibility on screen load
    ref.listen<RolloverState>(rolloverProvider, (previous, current) {
      if (previous?.eligibility == null && current.eligibility != null) {
        // Eligibility has been loaded
      }
    });

    return Scaffold(
      backgroundColor: CoopvestColors.veryLightGray,
      appBar: AppBar(
        title: const Text('Rollover Eligibility'),
        backgroundColor: CoopvestColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLoanSummaryCard(activeLoan),
            const SizedBox(height: 24),
            _buildEligibilitySection(context, ref, rolloverNotifier, activeLoan),
            const SizedBox(height: 24),
            if (rolloverState.eligibility != null)
              _buildActionButtons(context, ref, rolloverNotifier, activeLoan),
          ],
        ),
      ),
    );
  }

  Loan _getDemoLoan() {
    final now = DateTime.now();
    return Loan(
      id: 'LOAN-DEMO',
      userId: 'user-id',
      amount: 100000,
      tenure: 6,
      interestRate: 7.0,
      monthlyRepayment: 18333,
      totalRepayment: 65000,
      status: 'active',
      guarantorsAccepted: 3,
      guarantorsRequired: 3,
      createdAt: now.subtract(const Duration(days: 90)),
      updatedAt: now.subtract(const Duration(days: 60)),
      approvedAt: now.subtract(const Duration(days: 85)),
      disbursedAt: now.subtract(const Duration(days: 84)),
    );
  }

  Widget _buildLoanSummaryCard(Loan loan) {
    final outstandingBalance = loan.amount - (loan.totalRepayment * 0.65);
    final repaymentPercentage = ((loan.totalRepayment / loan.amount * 100).clamp(0, 100)).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: CoopvestColors.primary),
                const SizedBox(width: 8),
                Text(
                  loan.id,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CoopvestColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Loan Amount', loan.amount),
            _buildSummaryRow('Outstanding Balance', outstandingBalance),
            _buildSummaryRow('Interest Rate', '${loan.interestRate}%'),
            _buildSummaryRow('Monthly Repayment', loan.monthlyRepayment),
            _buildSummaryRow('Status', loan.status.toUpperCase()),
            const Divider(height: 16),
            _buildRepaymentProgress(repaymentPercentage),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic value) {
    final formattedValue = value is double
        ? value.toString()
        : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: CoopvestColors.textSecondary,
            ),
          ),
          Text(
            formattedValue,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentProgress(double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Repayment Progress',
              style: TextStyle(fontSize: 13, color: CoopvestColors.textSecondary),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CoopvestColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: CoopvestColors.lightGray,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage >= 50 ? CoopvestColors.success : CoopvestColors.warning,
            ),
          ),
        ),
        if (percentage < 50)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Need ${(50 - percentage).toStringAsFixed(1)}% more to be eligible',
              style: const TextStyle(
                fontSize: 11,
                color: CoopvestColors.warning,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEligibilitySection(
    BuildContext context,
    WidgetRef ref,
    RolloverNotifier rolloverNotifier,
    Loan loan,
  ) {
    final eligibility = ref.watch(rolloverProvider).eligibility;
    final isLoading = ref.watch(rolloverProvider).isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (eligibility == null) {
      return Center(
        child: Column(
          children: [
            const Text('Tap to check your rollover eligibility'),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Check Eligibility',
              onPressed: () => rolloverNotifier.checkEligibility(loanId: loan.id),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  eligibility.isEligible ? Icons.check_circle : Icons.info,
                  color: eligibility.isEligible ? CoopvestColors.success : CoopvestColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  eligibility.isEligible ? 'Eligible for Rollover' : 'Not Eligible',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Rule 1: 50% Repayment
            EligibilityCheckItem(
              isMet: eligibility.hasMinimum50PercentRepayment,
              title: '50% Principal Repaid',
              subtitle: eligibility.hasMinimum50PercentRepayment
                  ? '${eligibility.repaymentPercentage.toStringAsFixed(1)}% repaid'
                  : 'Need at least 50% repayment',
            ),

            // Rule 2: Consistent Savings
            EligibilityCheckItem(
              isMet: eligibility.hasConsistentSavings,
              title: 'Consistent Monthly Savings',
              subtitle: eligibility.hasConsistentSavings
                  ? '${eligibility.consecutiveSavingsMonths} consecutive months'
                  : 'Need consistent savings history',
            ),

            // Show errors if any
            if (eligibility.eligibilityErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CoopvestColors.error.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.error, color: CoopvestColors.error, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Issues Found',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: CoopvestColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...eligibility.eligibilityErrors.map(
                      (e) => Text('• $e', style: const TextStyle(color: CoopvestColors.error)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    RolloverNotifier rolloverNotifier,
    Loan loan,
  ) {
    final eligibility = ref.watch(rolloverProvider).eligibility;

    if (eligibility == null) {
      return const SizedBox.shrink();
    }

    if (!eligibility.isEligible) {
      return Center(
        child: Text(
          'Please meet all eligibility requirements to request a rollover.',
          style: const TextStyle(fontSize: 13, color: CoopvestColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        PrimaryButton(
          label: 'Request Rollover',
          onPressed: () {
            // Navigate to rollover request screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RolloverRequestPlaceholder(loan: loan),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => rolloverNotifier.checkEligibility(loanId: loan.id),
          child: const Text('Refresh Eligibility'),
        ),
      ],
    );
  }
}

/// Placeholder for RolloverRequestScreen (will be implemented next)
class RolloverRequestPlaceholder extends ConsumerWidget {
  final Loan loan;

  const RolloverRequestPlaceholder({super.key, required this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Rollover')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
      ),
    );
  }
}
