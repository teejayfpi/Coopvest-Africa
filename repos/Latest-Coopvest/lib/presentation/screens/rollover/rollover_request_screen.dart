import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/loan_models.dart';
import '../../../data/models/rollover_models.dart';
import '../../providers/rollover_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/cards.dart';
import '../../widgets/rollover/rollover_common_widgets.dart';

/// Rollover Request Screen
class RolloverRequestScreen extends ConsumerWidget {
  final Loan loan;
  const RolloverRequestScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolloverState = ref.watch(rolloverProvider);
    final outstandingBalance = loan.amount * 0.35;
    final newTenureOptions = [4, 6, 8, 12];

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(title: Text('Request Rollover', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRolloverSummary(context, outstandingBalance, loan),
            const SizedBox(height: 24),
            _buildTenureSelection(context, newTenureOptions, rolloverState.newTenure, (value) {}),
            const SizedBox(height: 24),
            _buildGuarantorSection(context, ref, rolloverState),
            const SizedBox(height: 24),
            _buildImportantNotes(context),
            const SizedBox(height: 24),
            _buildSubmitButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildRolloverSummary(BuildContext context, double outstandingBalance, Loan loan) {
    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.info_outline, color: context.textSecondary), const SizedBox(width: 8), Text('Rollover Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary))]),
          const SizedBox(height: 16),
          _buildSummaryRow(context, 'Original Loan Amount', loan.amount),
          _buildSummaryRow(context, 'Outstanding Balance', outstandingBalance),
          _buildSummaryRow(context, 'Current Interest Rate', '${loan.interestRate}%'),
          _buildSummaryRow(context, 'Original Tenure', '${loan.tenure} months'),
          const Divider(height: 16),
          Text('Note: The new loan will have the same interest rate but a new repayment tenor.', style: TextStyle(fontSize: 12, color: context.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 13, color: context.textSecondary)), Text(value.toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary))]),
    );
  }

  Widget _buildTenureSelection(BuildContext context, List<int> options, int? selectedTenure, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select New Tenor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: 8),
        Text('Choose how long you need to repay the outstanding balance', style: TextStyle(fontSize: 13, color: context.textSecondary)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: options.map((tenure) {
          final isSelected = selectedTenure == tenure;
          return ChoiceChip(label: Text('$tenure months'), selected: isSelected, onSelected: (selected) => onChanged(tenure), selectedColor: CoopvestColors.primary, labelStyle: TextStyle(color: isSelected ? Colors.white : context.textPrimary));
        }).toList()),
      ],
    );
  }

  Widget _buildGuarantorSection(BuildContext context, WidgetRef ref, RolloverState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text('Select 3 Guarantors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary))), Text('${state.selectedGuarantors.length}/3', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: state.selectedGuarantors.length >= 3 ? CoopvestColors.success : Colors.orange))]),
        const SizedBox(height: 8),
        Text('All 3 guarantors must provide fresh consent for this rollover.', style: TextStyle(fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 16),
        ...state.selectedGuarantors.map((guarantor) => GuarantorSelectionCard(guarantor: guarantor, onRemove: () => ref.read(rolloverProvider.notifier).removeGuarantor(guarantor.id))),
        const SizedBox(height: 12),
        SecondaryButton(label: '+ Add Guarantor', onPressed: () {}),
      ],
    );
  }

  Widget _buildImportantNotes(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: CoopvestColors.primary.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Important Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CoopvestColors.primary)),
          const SizedBox(height: 8),
          Text('• This is NOT a loan increase\n• All 3 guarantors must give FRESH consent\n• Your original loan will be closed and a new loan created\n• Admin approval is required\n• No interest escalation - same rate applies', style: TextStyle(fontSize: 12, color: context.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolloverProvider);
    return PrimaryButton(label: 'Submit Rollover Request', isLoading: state.isLoading, onPressed: () {}, isEnabled: state.selectedGuarantors.length >= 3, width: double.infinity);
  }
}
