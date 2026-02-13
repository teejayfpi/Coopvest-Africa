import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/wallet_models.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../savings/savings_goals_screen.dart';
import '../transactions/transactions_history_screen.dart';
import 'deposit_screen.dart';
import 'withdrawal_screen.dart';

/// Wallet Dashboard Screen
class WalletDashboardScreen extends ConsumerWidget {
  final String userId;
  final String userName;

  const WalletDashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final savingsGoals = walletState.savingsGoals;
    final recentTransactions = walletState.transactions.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'My Wallet',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: CoopvestColors.primary),
            onPressed: () {
              // Show QR code for receiving funds
              _showReceiveQRDialog(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              _buildBalanceCard(context, wallet),
              
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(context),
              
              const SizedBox(height: 24),

              // Savings Goals Section
              _buildSavingsGoalsSection(context, ref, savingsGoals),
              
              const SizedBox(height: 24),

              // Recent Transactions
              _buildRecentTransactions(context, ref, recentTransactions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, Wallet? wallet) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CoopvestColors.primary, Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: CoopvestTypography.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₦${(wallet?.balance ?? 0).toStringAsFixed(2)}',
                    style: CoopvestTypography.displaySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.visibility_off, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Hide',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${(wallet?.availableForWithdrawal ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${(wallet?.pendingContributions ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: CoopvestTypography.titleMedium.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.add,
                label: 'Deposit',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DepositScreen(userId: userId),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.remove,
                label: 'Withdraw',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WithdrawalScreen(userId: userId),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.savings,
                label: 'Save',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SavingsGoalsScreen(userId: userId),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: CoopvestColors.lightGray.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: CoopvestColors.primary, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: CoopvestTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: CoopvestColors.darkGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsGoalsSection(
    BuildContext context,
    WidgetRef ref,
    List<SavingsGoal> goals,
  ) {
    final activeGoals = goals.where((g) => g.status == 'active').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Savings Goals',
              style: CoopvestTypography.titleMedium.copyWith(
                color: CoopvestColors.darkGray,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SavingsGoalsScreen(userId: userId),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (activeGoals.isEmpty)
          _buildEmptyGoalsCard(context)
        else
          ...activeGoals.take(2).map((goal) => _buildSavingsGoalCard(context, goal)),
        
        const SizedBox(height: 16),
        
        SizedBox(
          width: double.infinity,
          child: SecondaryButton(
            label: '+ Create New Goal',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SavingsGoalsScreen(userId: userId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyGoalsCard(BuildContext context) {
    return AppCard(
      backgroundColor: CoopvestColors.veryLightGray,
      child: Center(
        child: Column(
          children: [
            Icon(Icons.savings_outlined, color: CoopvestColors.mediumGray, size: 48),
            const SizedBox(height: 12),
            Text(
              'No savings goals yet',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.mediumGray,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start saving towards your dreams',
              style: TextStyle(color: CoopvestColors.mediumGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsGoalCard(BuildContext context, SavingsGoal goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  goal.name,
                  style: CoopvestTypography.titleMedium.copyWith(
                    color: CoopvestColors.darkGray,
                  ),
                ),
                Text(
                  '${goal.progressPercentage.toStringAsFixed(0)}%',
                  style: CoopvestTypography.bodyMedium.copyWith(
                    color: CoopvestColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: goal.progressPercentage / 100,
              backgroundColor: CoopvestColors.veryLightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₦${goal.currentAmount.toStringAsFixed(0)} of ₦${goal.targetAmount.toStringAsFixed(0)}',
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
                Text(
                  '${goal.monthsRemaining} months left',
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    List<Transaction> transactions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: CoopvestTypography.titleMedium.copyWith(
                color: CoopvestColors.darkGray,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TransactionsHistoryScreen(userId: userId),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (transactions.isEmpty)
          _buildEmptyTransactionsCard()
        else
          ...transactions.map((txn) => _buildTransactionItem(context, txn)),
      ],
    );
  }

  Widget _buildEmptyTransactionsCard() {
    return AppCard(
      backgroundColor: CoopvestColors.veryLightGray,
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long, color: CoopvestColors.mediumGray, size: 48),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction txn) {
    final isCredit = txn.type == 'contribution' || txn.type == 'loan_disbursement' || txn.type == 'refund';
    
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit 
                  ? CoopvestColors.success.withAlpha((255 * 0.1).toInt())
                  : CoopvestColors.error.withAlpha((255 * 0.1).toInt()),
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
                  style: CoopvestTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDate(txn.createdAt),
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}₦${txn.amount.toStringAsFixed(2)}',
            style: CoopvestTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isCredit ? CoopvestColors.success : CoopvestColors.error,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showReceiveQRDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CoopvestColors.primary.withAlpha((255 * 0.1).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: 'COOP-RECEIVE-$userId',
                version: QrVersions.auto,
                size: 180.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this QR code to receive funds',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
