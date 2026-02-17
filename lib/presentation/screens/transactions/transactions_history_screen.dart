import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../data/models/wallet_models.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/widgets/common/cards.dart';

/// Transactions History Screen
class TransactionsHistoryScreen extends ConsumerWidget {
  final String userId;

  const TransactionsHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final transactions = walletState.transactions;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Transaction History',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: transactions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, color: context.textSecondary, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions yet',
                      style: TextStyle(color: context.textSecondary, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final txn = transactions[index];
                  return _buildTransactionItem(context, txn);
                },
              ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction txn) {
    final isCredit = txn.type == 'contribution' || txn.type == 'loan_disbursement' || txn.type == 'refund';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCredit 
                    ? CoopvestColors.success.withOpacity(0.1)
                    : CoopvestColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? CoopvestColors.success : CoopvestColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description ?? txn.type.replaceAll('_', ' ').capitalize(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getMonthName(txn.createdAt.month)} ${txn.createdAt.day}, ${txn.createdAt.year}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'}₦${txn.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCredit ? CoopvestColors.success : CoopvestColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
