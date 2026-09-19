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
import 'rollover_request_screen.dart';

/// Rollover Eligibility Check Screen
///
/// Stateful so the screen can fetch loans on entry: reached from the loan
/// dashboard the list is usually warm, but a cold start or a deep link can
/// arrive before any loan has been loaded, which previously showed
/// "No Active Loan" to a member who plainly has one.
class RolloverEligibilityScreen extends ConsumerStatefulWidget {
  final Loan? loan;
  const RolloverEligibilityScreen({super.key, this.loan});

  @override
  ConsumerState<RolloverEligibilityScreen> createState() =>
      _RolloverEligibilityScreenState();
}

class _RolloverEligibilityScreenState
    extends ConsumerState<RolloverEligibilityScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure loans are fresh so we can detect an active/repaying loan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loanState = ref.read(loanProvider);
      if (loanState.loans.isEmpty && !loanState.isLoading) {
        ref.read(loanProvider.notifier).getLoans();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loanState = ref.watch(loanProvider);
    final rolloverState = ref.watch(rolloverProvider);
    final rolloverNotifier = ref.read(rolloverProvider.notifier);

    // Find active loan - show message if none exists
    final activeLoans = loanState.loans.where((l) => l.status == 'active' || l.status == 'repaying').toList();
    final activeLoan = widget.loan ?? (activeLoans.isNotEmpty ? activeLoans.first : null);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(title: Text('Rollover Eligibility', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)), elevation: 0),
      body: activeLoan == null
          // Distinguish "still loading" from "genuinely no loan" so a member is
          // never told they have no active loan while the list is in flight.
          ? (loanState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildNoActiveLoanMessage(context))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLoanSummaryCard(context, activeLoan, rolloverState.eligibility),
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

  Widget _buildNoActiveLoanMessage(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: context.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No Active Loan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'You need an active loan to check rollover eligibility. Apply for a loan first, then come back here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Go Back', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanSummaryCard(BuildContext context, Loan loan, RolloverEligibility? eligibility) {
    // Prefer the backend's real principal position. Before it loads, show the
    // loan amount and no derived numbers rather than inventing a balance.
    final original = eligibility?.originalPrincipal ?? loan.amount;
    final repaid = eligibility?.principalRepaid ?? 0;
    final outstanding = eligibility?.outstandingPrincipal ?? (original - repaid);
    final repaymentPercentage = eligibility?.repaymentPercentage ?? 0;
    final threshold = eligibility?.minPrincipalPercentage ?? 70;

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
            // Principal figures, not a derived guess. The previous version
            // computed "outstanding" as amount - totalRepayment x 0.65, which is
            // not a real balance.
            _buildSummaryRow(context, 'Original loan', loan.amount),
            _buildSummaryRow(context, 'Principal repaid', repaid),
            _buildSummaryRow(context, 'Outstanding principal', outstanding),
            _buildSummaryRow(context, 'Interest Rate', '${loan.interestRate}%'),
            _buildSummaryRow(context, 'Monthly Repayment', loan.monthlyRepayment),
            const Divider(height: 16),
            _buildRepaymentProgress(context, repaymentPercentage, threshold),
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

  Widget _buildRepaymentProgress(BuildContext context, double percentage, double threshold) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Repayment Progress', style: TextStyle(fontSize: 13, color: context.textSecondary)), Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CoopvestColors.primary))]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (percentage / 100).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: context.dividerColor, valueColor: AlwaysStoppedAnimation<Color>(percentage >= threshold ? CoopvestColors.success : CoopvestColors.warning))),
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
            Row(children: [
              Icon(
                eligibility.isEligible ? Icons.sync : Icons.lock_outline,
                color: eligibility.isEligible ? CoopvestColors.success : CoopvestColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eligibility.isEligible ? '🔄 Loan Rollover Available' : '🔒 Loan Rollover',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              eligibility.isEligible
                  ? 'You have repaid ${eligibility.repaymentPercentage.toStringAsFixed(0)}% of your current loan. You can now request a rollover.'
                  : 'You become eligible after repaying ${eligibility.minPrincipalPercentage.toStringAsFixed(0)}% of your current loan.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // The five agreed rules, each reported separately so the member can
            // see exactly what is missing rather than a bare "not eligible".
            EligibilityCheckItem(
              isMet: eligibility.hasMinimumPrincipalRepaid,
              title: '${eligibility.minPrincipalPercentage.toStringAsFixed(0)}% of principal repaid',
              subtitle: '${eligibility.repaymentPercentage.toStringAsFixed(1)}% repaid'
                  '${eligibility.hasMinimumPrincipalRepaid ? '' : ' — ₦${eligibility.principalStillRequired.toStringAsFixed(0)} still to repay'}',
            ),
            EligibilityCheckItem(
              isMet: eligibility.hasNoSeriousDefault,
              title: 'No serious default',
              subtitle: eligibility.hasNoSeriousDefault
                  ? 'No defaulted or in-recovery loans'
                  : 'A defaulted or in-recovery loan must be resolved first',
            ),
            EligibilityCheckItem(
              isMet: eligibility.accountInGoodStanding,
              title: 'Account in good standing',
              subtitle: eligibility.accountInGoodStanding
                  ? 'No outstanding obligations'
                  : 'Outstanding fines or fees must be settled',
            ),
            EligibilityCheckItem(
              isMet: eligibility.withinRolloverLimit,
              title: 'Within the rollover limit',
              subtitle: '${eligibility.rolloverCount} of ${eligibility.maxConsecutiveRollovers} consecutive rollovers used',
            ),
            if (eligibility.blockers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CoopvestColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: eligibility.blockers
                      .map((b) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• $b', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, RolloverNotifier rolloverNotifier, Loan loan) {
    final eligibility = ref.watch(rolloverProvider).eligibility;
    if (eligibility == null) return const SizedBox.shrink();
    if (!eligibility.isEligible) {
      return Center(
        child: Text(
          'Meet all the requirements above to request a rollover.',
          style: TextStyle(fontSize: 13, color: context.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        PrimaryButton(
          label: 'Request Rollover',
          width: double.infinity,
          // This was an empty callback, so the button did nothing at all.
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RolloverRequestScreen(loan: loan)),
          ),
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
