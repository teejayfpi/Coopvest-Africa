import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
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
    {
      'value': 'bank_transfer',
      'label': 'Bank Transfer',
      'icon': Icons.account_balance,
    },
    {
      'value': 'card',
      'label': 'Debit Card',
      'icon': Icons.credit_card,
    },
    {
      'value': 'ussd',
      'label': 'USSD',
      'icon': Icons.phone_android,
    },
  ];

  Future<void> _processDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));

      await ref.read(walletProvider.notifier).makeContribution(
        amount: amount,
        description: 'Wallet deposit via ${_selectedPaymentMethod.replaceAll('_', ' ')}',
      );

      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deposit failed: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: CoopvestColors.success),
            SizedBox(width: 8),
            Text('Deposit Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your deposit of ₦${_amountController.text} has been processed successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.info.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Funds have been added to your wallet balance.',
                style: CoopvestTypography.bodySmall.copyWith(
                  color: CoopvestColors.info,
                ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CoopvestColors.darkGray),
          onPressed: _goBack,
        ),
        title: Text(
          'Deposit Funds',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
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
                // Amount Input
                AppTextField(
                  label: 'Amount',
                  hint: 'Enter deposit amount',
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  prefixText: '₦ ',
                  onChanged: (value) {
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final amount = double.tryParse(value.replaceAll(',', ''));
                    if (amount == null || amount < 100) {
                      return 'Minimum deposit is ₦100';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Quick Amount Buttons
                const Text('Quick Select:', style: TextStyle(fontWeight: FontWeight.w500)),
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
                          color: CoopvestColors.veryLightGray,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CoopvestColors.lightGray),
                        ),
                        child: Text('₦${amount.formatNumber()}'),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Payment Method Selection
                const Text(
                  'Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                
                Column(
                  children: _paymentMethods.map((method) {
                    final isSelected = _selectedPaymentMethod == method['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPaymentMethod = method['value'] as String;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? CoopvestColors.primary.withAlpha((255 * 0.1).toInt())
                              : CoopvestColors.veryLightGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? CoopvestColors.primary : CoopvestColors.lightGray,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (method['icon'] as IconData?) ?? Icons.payment,
                              color: isSelected ? CoopvestColors.primary : CoopvestColors.mediumGray,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                method['label'] as String,
                                style: CoopvestTypography.bodyMedium.copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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

                // Info Card
                AppCard(
                  backgroundColor: CoopvestColors.info.withAlpha((255 * 0.1).toInt()),
                  border: Border.all(color: CoopvestColors.info.withAlpha((255 * 0.3).toInt())),
                  child: Row(
                    children: const [
                      Icon(Icons.info, color: CoopvestColors.info),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Deposits are processed instantly. Bank transfers may take 1-2 minutes to reflect.',
                          style: TextStyle(color: CoopvestColors.darkGray),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button
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
