import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/loan_models.dart';
import '../../../data/models/rollover_models.dart';
import '../../../data/models/guarantor_models.dart';
import '../../../data/api/rollover_api_service.dart' show GuarantorInfo;
import '../../../data/api/guarantor_api_service.dart';
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
    // Real figures from the eligibility check, not a derived guess. The previous
    // version showed `loan.amount * 0.35` as the outstanding balance, which is
    // not the member's actual position.
    final eligibility = rolloverState.eligibility;
    final outstandingBalance = eligibility?.outstandingBalance ?? 0;
    final newTenureOptions = [4, 6, 8, 12];

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(title: Text('Request Rollover', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRolloverSummary(context, outstandingBalance, loan, rolloverState.eligibility),
            const SizedBox(height: 24),
            _buildAmountInput(context, ref, loan, rolloverState),
            const SizedBox(height: 24),
            _buildAmountAndBreakdown(context, ref, loan, rolloverState),
            const SizedBox(height: 24),
            _buildTenureSelection(
              context,
              newTenureOptions,
              rolloverState.newTenure,
              (value) => ref.read(rolloverProvider.notifier).setNewTenure(value),
            ),
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

  Widget _buildRolloverSummary(BuildContext context, double outstandingBalance, Loan loan, RolloverEligibility? eligibility) {
    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.info_outline, color: context.textSecondary), const SizedBox(width: 8), Text('Current Loan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary))]),
          const SizedBox(height: 16),
          _buildSummaryRow(context, 'Original amount', eligibility?.originalPrincipal ?? loan.amount),
          _buildSummaryRow(context, 'Principal repaid', eligibility?.principalRepaid ?? 0),
          _buildSummaryRow(context, 'Outstanding principal', eligibility?.outstandingPrincipal ?? 0),
          _buildSummaryRow(context, 'Repayment progress', '${(eligibility?.repaymentPercentage ?? 0).toStringAsFixed(1)}%'),
          _buildSummaryRow(context, 'Status', (eligibility?.isEligible ?? false) ? '✅ Eligible' : 'Not eligible'),
          const Divider(height: 16),
          Text('The outstanding balance is settled from the new loan, so you only receive the difference.', style: TextStyle(fontSize: 12, color: context.textSecondary)),
        ],
      ),
    );
  }

  /// Money row. `emphasise` marks the headline figure (the net disbursement).
  /// Numeric values are formatted as naira so the breakdown reads as amounts
  /// rather than bare numbers.
  Widget _buildSummaryRow(BuildContext context, String label, dynamic value, {bool emphasise = false}) {
    final String text;
    if (value is num) {
      final n = value.toDouble();
      final sign = n < 0 ? '-' : '';
      final abs = n.abs().toStringAsFixed(2);
      text = '$sign₦${abs.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    } else {
      text = value.toString();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: context.textSecondary)),
          Text(
            text,
            style: TextStyle(
              fontSize: emphasise ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: emphasise ? CoopvestColors.primary : context.textPrimary,
            ),
          ),
        ],
      ),
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
        SecondaryButton(
          label: '+ Add Guarantor',
          // Was an empty callback. Opens the same picker the loan application
          // uses to choose guarantors.
          onPressed: () => _showGuarantorPicker(context, ref),
        ),
      ],
    );
  }

  Widget _buildImportantNotes(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: CoopvestColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: CoopvestColors.primary.withValues(alpha: 0.3))),
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

  /// The new-loan amount and the settlement breakdown:
  ///   new loan - existing balance settled = net amount to the member.
  ///
  /// The member must see this before accepting, so they understand they are not
  /// receiving the full new loan while still owing the old balance.
  Widget _buildAmountAndBreakdown(BuildContext context, WidgetRef ref, Loan loan, RolloverState state) {
    final terms = state.rolloverTerms;

    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Loan Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
          const SizedBox(height: 12),
          if (terms == null)
            Text('Enter an amount to see the calculation.', style: TextStyle(fontSize: 13, color: context.textSecondary))
          else ...[
            _buildSummaryRow(context, 'Maximum eligible', terms.maximumEligible),
            _buildSummaryRow(context, 'Requested amount', terms.requestedAmount),
            const Divider(height: 20),
            _buildSummaryRow(context, 'New loan', terms.requestedAmount),
            _buildSummaryRow(context, 'Existing balance', -terms.settlementAmount),
            const Divider(height: 12),
            _buildSummaryRow(context, 'Net amount to you', terms.netAmountToMember, emphasise: true),
            const SizedBox(height: 16),
            _buildSummaryRow(context, 'Interest rate', '${terms.interestRate}%'),
            _buildSummaryRow(context, 'New repayment period', '${terms.newTenureMonths} months'),
            _buildSummaryRow(context, 'Monthly repayment', terms.monthlyRepayment),
            _buildSummaryRow(context, 'Total repayment', terms.totalRepayment),
            if (terms.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...terms.errors.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $e', style: const TextStyle(fontSize: 12, color: CoopvestColors.error)),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolloverProvider);
    final terms = state.rolloverTerms;
    final canSubmit = state.selectedGuarantors.length >= 3 &&
        terms != null &&
        terms.valid &&
        state.newTenure != null;

    return PrimaryButton(
      label: 'Submit Rollover Request',
      isLoading: state.isLoading,
      isEnabled: canSubmit,
      width: double.infinity,
      // Was an empty callback: the button did nothing. Now submits the request
      // the provider already knows how to send.
      onPressed: () async {
        if (state.newTenure == null) return;
        // The provider takes GuarantorInfo, while the form holds
        // RolloverGuarantor records; convert at the boundary.
        final guarantors = state.selectedGuarantors
            .map((g) => GuarantorInfo(
                  guarantorId: g.guarantorId,
                  guarantorName: g.guarantorName,
                  guarantorPhone: g.guarantorPhone,
                ))
            .toList();

        final ok = await ref.read(rolloverProvider.notifier).createRolloverRequest(
              loanId: loan.id,
              newTenure: state.newTenure!,
              guarantors: guarantors,
            );
        if (!context.mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rollover request submitted for approval.')),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error ?? 'Could not submit the request.')),
          );
        }
      },
    );
  }

  /// Choose a guarantor. Kept local to the screen so the request flow can add
  /// guarantors without navigating away mid-form.
  Future<void> _showGuarantorPicker(BuildContext context, WidgetRef ref) async {
    final member = await showDialog<EligibleGuarantor>(
      context: context,
      builder: (dialogContext) => const _EligibleGuarantorPicker(),
    );
    if (member == null || !context.mounted) return;
    ref.read(rolloverProvider.notifier).addGuarantor(
          GuarantorInfo(
            guarantorId: member.id,
            guarantorName: member.name,
            guarantorPhone: '',
          ),
        );
  }

  /// Amount the member wants to borrow. Changing it recomputes the terms, which
  /// is what fills in the settlement breakdown below.
  Widget _buildAmountInput(BuildContext context, WidgetRef ref, Loan loan, RolloverState state) {
    final terms = state.rolloverTerms;
    final controller = TextEditingController(
      text: (state.rolloverAmount ?? terms?.maximumEligible ?? 0).toStringAsFixed(0),
    );

    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How much do you want to borrow?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
          const SizedBox(height: 4),
          if (terms != null)
            Text(
              'Maximum eligible: ₦${terms.maximumEligible.toStringAsFixed(0)} '
              '(${terms.loanMultiplier.toStringAsFixed(0)}x your savings)',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₦ ',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final amount = double.tryParse(value.replaceAll(',', '').trim());
              if (amount != null && amount > 0) {
                ref.read(rolloverProvider.notifier).loadRolloverTerms(
                      loanId: loan.id,
                      amount: amount,
                      tenureMonths: state.newTenure,
                    );
              }
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final amount = double.tryParse(controller.text.replaceAll(',', '').trim());
                if (amount != null && amount > 0) {
                  ref.read(rolloverProvider.notifier).loadRolloverTerms(
                        loanId: loan.id,
                        amount: amount,
                        tenureMonths: state.newTenure,
                      );
                }
              },
              child: const Text('Calculate'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks a guarantor from the members the backend says are eligible for this
/// borrower. The backend applies the contribution-channel rule (same
/// organisation for salary deduction, direct deposit for direct deposit), so an
/// ineligible member is never offered.
class _EligibleGuarantorPicker extends StatefulWidget {
  const _EligibleGuarantorPicker();

  @override
  State<_EligibleGuarantorPicker> createState() =>
      _EligibleGuarantorPickerState();
}

class _EligibleGuarantorPickerState extends State<_EligibleGuarantorPicker> {
  final _searchController = TextEditingController();
  final _service = GuarantorApiService();
  List<EligibleGuarantor> _members = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getEligibleMembers(
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() { _members = result.members; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a guarantor'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Only members who are eligible to guarantee your loan are shown.',
              style: TextStyle(fontSize: 13, color: CoopvestColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: 'Search by name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _load,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: CoopvestColors.error)),
              )
            else if (_members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No eligible members found.'),
              )
            else
              SizedBox(
                height: 220,
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return ListTile(
                      title: Text(member.name),
                      onTap: () => Navigator.pop(context, member),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

