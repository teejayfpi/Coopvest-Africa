import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/buttons.dart';

/// Bank Accounts Screen
class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  final List<Map<String, dynamic>> _bankAccounts = [
    {
      'bankName': 'First Bank of Nigeria',
      'accountNumber': '****4567',
      'accountName': 'Ayanlowo Coop Account',
      'isPrimary': true,
    },
    {
      'bankName': 'Access Bank',
      'accountNumber': '****8901',
      'accountName': 'Ayanlowo Savings',
      'isPrimary': false,
    },
  ];

  void _addBankAccount() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.scaffoldBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.dividerColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Add Bank Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual bank addition coming soon')));
                },
                icon: const Icon(Icons.account_balance),
                label: const Text('Enter Bank Details Manually'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank verification coming soon')));
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Bank Card'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _removeBankAccount(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Text('Remove Bank Account', style: TextStyle(color: context.textPrimary)),
        content: Text('Are you sure you want to remove ${_bankAccounts[index]['bankName']}?', style: TextStyle(color: context.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _bankAccounts.removeAt(index));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank account removed')));
            },
            child: const Text('Remove', style: TextStyle(color: CoopvestColors.error)),
          ),
        ],
      ),
    );
  }

  void _setPrimaryAccount(int index) {
    setState(() {
      for (int i = 0; i < _bankAccounts.length; i++) {
        _bankAccounts[i]['isPrimary'] = (i == index);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primary account updated')));
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
            onPressed: _addBankAccount,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add'),
          ),
        ],
      ),
      body: _bankAccounts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: context.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No bank accounts linked', style: TextStyle(fontSize: 16, color: context.textSecondary)),
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Add Bank Account', onPressed: _addBankAccount, width: 200),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Manage your linked bank accounts for deposits and withdrawals', style: TextStyle(color: context.textSecondary)),
                const SizedBox(height: 16),
                ..._bankAccounts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final account = entry.value;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.account_balance, color: CoopvestColors.primary),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(account['bankName'], style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              ),
                              if (account['isPrimary']) ...[
                                const SizedBox(width: 8),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Text('Primary', style: TextStyle(fontSize: 10, color: CoopvestColors.primary, fontWeight: FontWeight.w600))),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(account['accountName']),
                              Text(account['accountNumber'], style: TextStyle(color: context.textSecondary.withOpacity(0.7))),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'primary') _setPrimaryAccount(index);
                              if (value == 'remove') _removeBankAccount(index);
                            },
                            itemBuilder: (context) => [
                              if (!account['isPrimary']) const PopupMenuItem(value: 'primary', child: Text('Set as Primary')),
                              const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: CoopvestColors.error))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}