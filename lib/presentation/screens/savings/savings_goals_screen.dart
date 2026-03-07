import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
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
    setState(() => _isCreating = true);
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
        const SnackBar(content: Text('Savings goal created successfully!'), backgroundColor: CoopvestColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create goal: $e')));
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _showCreateGoalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.scaffoldBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Create Savings Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
                      IconButton(icon: Icon(Icons.close, color: context.iconPrimary), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppTextField(label: 'Goal Name', hint: 'e.g., New Phone, Vacation', controller: _nameController),
                  const SizedBox(height: 16),
                  AppTextField(label: 'Target Amount', hint: 'Enter target amount', controller: _targetController, keyboardType: TextInputType.number, prefixText: '₦ '),
                  const SizedBox(height: 16),
                  AppTextField(label: 'Monthly Contribution', hint: 'How much can you save monthly?', controller: _monthlyController, keyboardType: TextInputType.number, prefixText: '₦ '),
                  const SizedBox(height: 16),
                  Text('Target Date', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _targetDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.cardBackground,
                        border: Border.all(color: context.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: CoopvestColors.primary),
                          const SizedBox(width: 12),
                          Text('${_getMonthName(_targetDate.month)} ${_targetDate.day}, ${_targetDate.year}', style: TextStyle(fontSize: 16, color: context.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _isCreating
                      ? const Center(child: CircularProgressIndicator(color: CoopvestColors.primary))
                      : PrimaryButton(label: 'Create Goal', onPressed: _createGoal, width: double.infinity),
                ],
              ),
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
    final activeGoals = walletState.savingsGoals.where((g) => g.status == 'active').toList();

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Savings Goals', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: activeGoals.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.savings_outlined, color: context.textSecondary, size: 64),
                    const SizedBox(height: 16),
                    Text('No savings goals yet', style: TextStyle(color: context.textSecondary, fontSize: 16)),
                    const SizedBox(height: 24),
                    PrimaryButton(label: '+ Create Your First Goal', onPressed: _showCreateGoalDialog, width: 250),
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
                      child: SecondaryButton(label: '+ Create New Goal', onPressed: _showCreateGoalDialog),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoal goal) {
    final progress = goal.currentAmount / goal.targetAmount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(goal.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress, backgroundColor: context.dividerColor, valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    Text('₦${goal.currentAmount.formatNumber()}', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Target', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    Text('₦${goal.targetAmount.formatNumber()}', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
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
