import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../core/network/api_client.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

class _BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final bool isDefault;

  const _BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.isDefault,
  });

  static _BankAccount? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return _BankAccount(
      id: id,
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      isDefault: json['is_primary'] == true,
    );
  }
}

/// Withdrawal Screen
///
/// Submits a bank-withdrawal request for an amount up to the member's
/// available balance. Finance actions the request, and the wallet is only
/// debited once the payout is confirmed — so this screen must never imply the
/// money has already left the account.
class WithdrawalScreen extends ConsumerStatefulWidget {
  final String userId;

  const WithdrawalScreen({super.key, required this.userId});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  List<_BankAccount> _accounts = const [];
  String? _selectedAccountId;
  bool _isLoadingAccounts = true;
  bool _isSubmitting = false;
  String? _accountsError;

  double get _available =>
      ref.read(walletProvider).wallet?.availableForWithdrawal ?? 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoadingAccounts = true;
      _accountsError = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get('/bank-accounts');
      final raw = (response is Map<String, dynamic>) ? response['accounts'] : null;
      final accounts = ((raw as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_BankAccount.fromJson)
          .whereType<_BankAccount>()
          .toList();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isLoadingAccounts = false;
        _selectedAccountId = accounts.isEmpty
            ? null
            : accounts
                .firstWhere((a) => a.isDefault, orElse: () => accounts.first)
                .id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAccounts = false;
        _accountsError = 'Could not load your bank accounts.';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final accountId = _selectedAccountId;
    if (accountId == null) {
      _showSnack('Add a bank account before withdrawing.', CoopvestColors.warning);
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim());

    setState(() => _isSubmitting = true);
    try {
      await ref.read(walletProvider.notifier).requestWithdrawal(
            amount: amount!,
            bankAccountId: accountId,
            description: 'Wallet withdrawal to bank',
          );
      if (!mounted) return;
      _showSuccessDialog(amount);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_errorMessage(e), CoopvestColors.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _errorMessage(Object e) {
    if (e is ApiException) return e.message;
    return 'Withdrawal request failed. Please try again.';
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: CoopvestColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Withdrawal Requested',
                style: TextStyle(color: context.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your request for ₦${amount.formatNumber()} has been submitted. '
              'Your bank account will be credited once finance approves it.',
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
                'Your wallet balance is only debited when the payout is confirmed.',
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

  @override
  Widget build(BuildContext context) {
    ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Withdraw Funds',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAccounts,
          color: CoopvestColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    backgroundColor: CoopvestColors.primary.withOpacity(0.08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available to withdraw',
                          style: TextStyle(fontSize: 12, color: context.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${_available.formatNumber()}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  AppTextField(
                    label: 'Amount',
                    hint: 'Enter amount to withdraw',
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    prefixText: '₦ ',
                    validator: (value) {
                      final amount =
                          double.tryParse((value ?? '').replaceAll(',', '').trim());
                      if (amount == null || amount <= 0) return 'Enter a valid amount';
                      if (amount > _available) {
                        return 'Maximum is ₦${_available.formatNumber()}';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Withdraw to',
                    style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _buildAccountSelector(context),

                  const SizedBox(height: 24),
                  AppCard(
                    backgroundColor: CoopvestColors.info.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: CoopvestColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Withdrawals are reviewed before payout. Your balance is debited '
                            'once the transfer to your bank account is confirmed.',
                            style: TextStyle(color: context.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: 'Request Withdrawal',
                    onPressed: _submit,
                    width: double.infinity,
                    isLoading: _isSubmitting,
                    isEnabled: _accounts.isNotEmpty,
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'Go Back',
                    onPressed: () => Navigator.of(context).pop(),
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSelector(BuildContext context) {
    if (_isLoadingAccounts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accountsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _accountsError!,
            style: const TextStyle(color: CoopvestColors.error, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadAccounts, child: const Text('Retry')),
        ],
      );
    }

    if (_accounts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CoopvestColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CoopvestColors.warning.withOpacity(0.4)),
        ),
        child: const Text(
          'No bank account on file. Add one from Profile → Bank Accounts, then come back to withdraw.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    return Column(
      children: _accounts.map((account) {
        final isSelected = account.id == _selectedAccountId;
        return GestureDetector(
          onTap: () => setState(() => _selectedAccountId = account.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? CoopvestColors.primary.withOpacity(0.1)
                  : context.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? CoopvestColors.primary : context.dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: isSelected ? CoopvestColors.primary : context.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account.bankName} • ${account.accountNumber}',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.accountName,
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: CoopvestColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}