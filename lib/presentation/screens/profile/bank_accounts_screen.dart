import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/utils.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/buttons.dart';
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

  factory _BankAccount.fromJson(Map<String, dynamic> json) {
    return _BankAccount(
      id: json['id']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      isDefault: json['is_default'] == true,
    );
  }
}

/// Bank Accounts Screen
class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  List<_BankAccount> _bankAccounts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/bank-accounts');
      if (response['success'] == true) {
        final List<dynamic> raw = response['accounts'] ?? [];
        setState(() {
          _bankAccounts = raw
              .map((e) => _BankAccount.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      } else {
        setState(() => _error = response['error']?.toString() ?? 'Failed to load accounts');
      }
    } catch (e) {
      logger.e('Load bank accounts error: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddAccountDialog() {
    final bankNameCtrl = TextEditingController();
    final accountNumberCtrl = TextEditingController();
    final accountNameCtrl = TextEditingController();
    final bankCodeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.scaffoldBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: context.dividerColor, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Text('Add Bank Account',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary)),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Bank Name',
                    hint: 'e.g. First Bank, Zenith Bank',
                    controller: bankNameCtrl,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Account Number',
                    hint: '10-digit NUBAN',
                    controller: accountNumberCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'Must be at least 6 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Account Name',
                    hint: 'Account holder name',
                    controller: accountNameCtrl,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Bank Code (optional)',
                    hint: 'e.g. 011',
                    controller: bankCodeCtrl,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: submitting
                        ? const Center(
                            child: CircularProgressIndicator(color: CoopvestColors.primary))
                        : PrimaryButton(
                            label: 'Add Account',
                            width: double.infinity,
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => submitting = true);
                              try {
                                final apiClient = ref.read(apiClientProvider);
                                await apiClient.post('/bank-accounts', data: {
                                  'bankName': bankNameCtrl.text.trim(),
                                  'accountNumber': accountNumberCtrl.text.trim(),
                                  'accountName': accountNameCtrl.text.trim(),
                                  if (bankCodeCtrl.text.isNotEmpty)
                                    'bankCode': bankCodeCtrl.text.trim(),
                                });
                                if (mounted) {
                                  Navigator.of(ctx).pop();
                                  await _loadAccounts();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bank account added'),
                                      backgroundColor: CoopvestColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                logger.e('Add bank account error: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to add account: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setSheetState(() => submitting = false);
                              }
                            },
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeBankAccount(_BankAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Text('Remove Bank Account', style: TextStyle(color: context.textPrimary)),
        content: Text(
          'Are you sure you want to remove ${account.bankName}?',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: CoopvestColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/bank-accounts/${account.id}');
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bank account removed')));
      }
    } catch (e) {
      logger.e('Remove bank account error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to remove account: $e')));
      }
    }
  }

  Future<void> _setDefaultAccount(_BankAccount account) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch('/bank-accounts/${account.id}/default');
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Primary account updated')));
      }
    } catch (e) {
      logger.e('Set default account error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update primary account: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Bank Accounts'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showAddAccountDialog,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CoopvestColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: context.textSecondary),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: context.textSecondary)),
                      const SizedBox(height: 16),
                      PrimaryButton(label: 'Retry', onPressed: _loadAccounts, width: 150),
                    ],
                  ),
                )
              : _bankAccounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 64, color: context.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('No bank accounts linked',
                              style: TextStyle(fontSize: 16, color: context.textSecondary)),
                          const SizedBox(height: 24),
                          PrimaryButton(
                              label: 'Add Bank Account',
                              onPressed: _showAddAccountDialog,
                              width: 200),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Manage your linked bank accounts for deposits and withdrawals',
                          style: TextStyle(color: context.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ..._bankAccounts.map((account) => AppCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: CoopvestColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.account_balance,
                                      color: CoopvestColors.primary),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        account.bankName,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (account.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: CoopvestColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Primary',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: CoopvestColors.primary,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(account.accountName),
                                    Text(
                                      account.accountNumber,
                                      style: TextStyle(
                                          color: context.textSecondary.withOpacity(0.7)),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'primary') _setDefaultAccount(account);
                                    if (value == 'remove') _removeBankAccount(account);
                                  },
                                  itemBuilder: (context) => [
                                    if (!account.isDefault)
                                      const PopupMenuItem(
                                          value: 'primary', child: Text('Set as Primary')),
                                    const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove',
                                            style: TextStyle(color: CoopvestColors.error))),
                                  ],
                                ),
                              ),
                            )),
                      ],
                    ),
    );
  }
}
