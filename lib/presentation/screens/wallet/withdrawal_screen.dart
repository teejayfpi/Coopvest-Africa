import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// Withdrawal Screen
class WithdrawalScreen extends ConsumerStatefulWidget {
  final String userId;

  const WithdrawalScreen({super.key, required this.userId});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  double _availableBalance = 120000.0;

  Future<void> _processWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    try {
      await Future.delayed(const Duration(seconds: 2));
      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Withdrawal failed: $e'), backgroundColor: CoopvestColors.error),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: CoopvestColors.success),
            const SizedBox(width: 8),
            Text('Withdrawal Successful', style: TextStyle(color: context.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your withdrawal of ₦${_amountController.text} has been processed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Funds will be transferred to your bank account within 24 hours.',
                style: TextStyle(color: CoopvestColors.warning, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: _goBack,
        ),
        title: Text(
          'Withdraw Funds',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  backgroundColor: CoopvestColors.info.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available for Withdrawal', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '₦${_availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(color: CoopvestColors.info, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ],
                      ),
                      const Icon(Icons.account_balance_wallet, color: CoopvestColors.info, size: 32),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                AppTextField(
                  label: 'Amount',
                  hint: 'Enter withdrawal amount',
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  prefixText: '₦ ',
                  onChanged: (value) => setState(() {}),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [5000, 10000, 25000, 50000, 100000].map((amount) {
                    final isSelected = _amountController.text.replaceAll(',', '') == amount.toString();
                    return GestureDetector(
                      onTap: () {
                        if (amount <= _availableBalance) {
                          _amountController.text = amount.toString();
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: amount <= _availableBalance
                              ? (isSelected ? CoopvestColors.primary : context.cardBackground)
                              : context.cardBackground.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: amount <= _availableBalance
                                ? (isSelected ? CoopvestColors.primary : context.dividerColor)
                                : context.dividerColor,
                          ),
                        ),
                        child: Text(
                          '₦${amount.formatNumber()}',
                          style: TextStyle(
                            color: amount <= _availableBalance
                                ? (isSelected ? Colors.white : context.textPrimary)
                                : context.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                AppCard(
                  backgroundColor: context.cardBackground,
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, color: CoopvestColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Withdrawal to:', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                            Text('Access Bank ****1234', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      TextButton(onPressed: () {}, child: const Text('Change')),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                AppCard(
                  backgroundColor: CoopvestColors.warning.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: CoopvestColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Withdrawals are processed within 24 hours. A ₦10 fee applies to withdrawals under ₦5,000.',
                          style: TextStyle(color: context.textPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                _isProcessing
                    ? const Center(child: CircularProgressIndicator(color: CoopvestColors.primary))
                    : PrimaryButton(
                        label: 'Withdraw ₦${_amountController.text.isEmpty ? '0' : _amountController.text}',
                        onPressed: _processWithdrawal,
                        width: double.infinity,
                      ),

                const SizedBox(height: 16),
                SecondaryButton(
                  label: 'Go Back',
                  onPressed: _goBack,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
