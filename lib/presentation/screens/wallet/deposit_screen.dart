import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// Deposit Screen
class DepositScreen extends ConsumerStatefulWidget {
  final String userId;

  const DepositScreen({super.key, required this.userId});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedPaymentMethod = 'bank_transfer';
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'bank_transfer', 'label': 'Bank Transfer', 'icon': Icons.account_balance},
    {'value': 'card', 'label': 'Debit Card', 'icon': Icons.credit_card},
    {'value': 'ussd', 'label': 'USSD', 'icon': Icons.phone_android},
  ];

  Future<void> _processDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      await ref.read(walletProvider.notifier).makeContribution(
        amount: amount,
        description: 'Wallet deposit via ${_selectedPaymentMethod.replaceAll('_', ' ')}',
      );
      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deposit failed: $e'), backgroundColor: CoopvestColors.error),
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
            Text('Deposit Successful', style: TextStyle(color: context.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your deposit of ₦${_amountController.text} has been processed successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Funds have been added to your wallet balance.',
                style: TextStyle(color: CoopvestColors.info, fontSize: 12),
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
          'Deposit Funds',
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
                AppTextField(
                  label: 'Amount',
                  hint: 'Enter deposit amount',
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  prefixText: '₦ ',
                  onChanged: (value) => setState(() {}),
                ),

                const SizedBox(height: 24),

                Text('Quick Select:', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [1000, 5000, 10000, 25000, 50000, 100000].map((amount) {
                    return GestureDetector(
                      onTap: () {
                        _amountController.text = amount.toString();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.dividerColor),
                        ),
                        child: Text('₦${amount.formatNumber()}', style: TextStyle(color: context.textPrimary)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                const SizedBox(height: 12),
                
                Column(
                  children: _paymentMethods.map((method) {
                    final isSelected = _selectedPaymentMethod == method['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPaymentMethod = method['value'] as String),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? CoopvestColors.primary.withOpacity(0.1) : context.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? CoopvestColors.primary : context.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (method['icon'] as IconData?) ?? Icons.payment,
                              color: isSelected ? CoopvestColors.primary : context.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                method['label'] as String,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: CoopvestColors.primary),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                AppCard(
                  backgroundColor: CoopvestColors.info.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: CoopvestColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Deposits are processed instantly. Bank transfers may take 1-2 minutes to reflect.',
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
                        label: 'Deposit ₦${_amountController.text.isEmpty ? '0' : _amountController.text}',
                        onPressed: _processDeposit,
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
