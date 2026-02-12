import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/wallet_models.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// Savings Goals Screen
class SavingsGoalsScreen extends ConsumerStatefulWidget {
  final String userId;

  const SavingsGoalsScreen({super.key, required this.userId});

  @override
  ConsumerState<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends ConsumerState<SavingsGoalsScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final targetAmount = double.parse(_targetController.text.replaceAll(',', ''));

      await ref.read(walletProvider.notifier).createSavingsGoal(
        goalName: _nameController.text,
        targetAmount: targetAmount,
        targetDate: _targetDate,
      );

      _nameController.clear();
      _targetController.clear();
      _monthlyController.clear();
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Savings goal created successfully!'),
          backgroundColor: CoopvestColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create goal: $e')),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _showCreateGoalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create Savings Goal',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                AppTextField(
                  label: 'Goal Name',
                  hint: 'e.g., New Phone, Vacation',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                AppTextField(
                  label: 'Target Amount',
                  hint: 'Enter target amount',
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  prefixText: '₦ ',
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v.replaceAll(',', '')) == null) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                AppTextField(
                  label: 'Monthly Contribution',
                  hint: 'How much can you save monthly?',
                  controller: _monthlyController,
                  keyboardType: TextInputType.number,
                  prefixText: '₦ ',
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v.replaceAll(',', '')) == null) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                const Text('Target Date', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _targetDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() => _targetDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: CoopvestColors.lightGray),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: CoopvestColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          '${_getMonthName(_targetDate.month)} ${_targetDate.day}, ${_targetDate.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                _isCreating
                    ? const Center(child: CircularProgressIndicator(color: CoopvestColors.primary))
                    : PrimaryButton(
                        label: 'Create Goal',
                        onPressed: _createGoal,
                        width: double.infinity,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final goals = walletState.savingsGoals;
    final activeGoals = goals.where((g) => g.status == 'active').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CoopvestColors.darkGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Savings Goals',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
      ),
      body: SafeArea(
        child: activeGoals.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.savings_outlined, color: CoopvestColors.mediumGray, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'No savings goals yet',
                      style: CoopvestTypography.titleMedium.copyWith(
                        color: CoopvestColors.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                        label: '+ Create Your First Goal',
                      onPressed: _showCreateGoalDialog,
                      width: 250,
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ...activeGoals.map((goal) => _buildGoalCard(context, goal)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton(
                        label: '+ Create New Goal',
                        onPressed: _showCreateGoalDialog,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoal goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        onTap: () {
          // Navigate to goal details or show deposit options
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Viewing details for: ${goal.name}')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: CoopvestTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${goal.progressPercentage.toStringAsFixed(0)}%',
                  style: CoopvestTypography.titleMedium.copyWith(
                    color: CoopvestColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progressPercentage / 100,
                minHeight: 10,
                backgroundColor: CoopvestColors.veryLightGray,
                valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₦${goal.currentAmount.formatNumber()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'of ₦${goal.targetAmount.formatNumber()}',
                      style: TextStyle(color: CoopvestColors.mediumGray),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₦${goal.monthlyContribution.formatNumber()}/mo',
                      style: CoopvestTypography.bodyMedium.copyWith(
                        color: CoopvestColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${goal.monthsRemaining} months left',
                      style: TextStyle(color: CoopvestColors.mediumGray),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
