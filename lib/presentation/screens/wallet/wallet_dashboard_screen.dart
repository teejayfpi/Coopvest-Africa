import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
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
class WalletDashboardScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const WalletDashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends ConsumerState<WalletDashboardScreen> {
  bool _isBalanceHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWallet();
      ref.read(walletProvider.notifier).loadTransactions();
      ref.read(walletProvider.notifier).loadSavingsGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final savingsGoals = walletState.savingsGoals;
    final recentTransactions = walletState.transactions.take(5).toList();

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.scaffoldBackground,
        title: Text(
          'My Wallet',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
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
        child: _buildBody(context, walletState, wallet, savingsGoals, recentTransactions),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WalletState walletState,
    Wallet? wallet,
    List<SavingsGoal> savingsGoals,
    List<Transaction> recentTransactions,
  ) {
    if (walletState.isLoading && wallet == null) {
      return const Center(
        child: CircularProgressIndicator(color: CoopvestColors.primary),
      );
    }

    if (walletState.status == WalletStatus.error && wallet == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: CoopvestColors.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load wallet data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                walletState.error ?? 'An unexpected error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Retry',
                onPressed: () {
                  ref.read(walletProvider.notifier).loadWallet();
                  ref.read(walletProvider.notifier).loadTransactions();
                },
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(walletProvider.notifier).loadWallet();
        await ref.read(walletProvider.notifier).loadTransactions();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
    );
  }

  Widget _buildBalanceCard(BuildContext context, Wallet? wallet) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final displayBalance = _isBalanceHidden ? '••••••' : '₦${(wallet?.balance ?? 0).toStringAsFixed(2)}';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
              ? [context.cardBackground, context.cardBackground.withOpacity(0.8)]
              : [CoopvestColors.primary, const Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : CoopvestColors.primary).withOpacity(0.3),
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
                      color: isDarkMode ? context.textSecondary : Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayBalance,
                    style: CoopvestTypography.displaySmall.copyWith(
                      color: isDarkMode ? context.textPrimary : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBalanceHidden = !_isBalanceHidden;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? CoopvestColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                        color: isDarkMode ? CoopvestColors.primary : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isBalanceHidden ? 'Show' : 'Hide',
                        style: TextStyle(
                          color: isDarkMode ? CoopvestColors.primary : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
                        color: isDarkMode ? context.textSecondary : Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isBalanceHidden ? '••••••' : '₦${(wallet?.availableForWithdrawal ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isDarkMode ? context.textPrimary : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: isDarkMode ? context.dividerColor : Colors.white.withOpacity(0.2)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: isDarkMode ? context.textSecondary : Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isBalanceHidden ? '••••••' : '₦${(wallet?.pendingContributions ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isDarkMode ? context.textPrimary : Colors.white,
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
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
                      builder: (context) => DepositScreen(userId: widget.userId),
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
                      builder: (context) => WithdrawalScreen(userId: widget.userId),
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
                      builder: (context) => SavingsGoalsScreen(userId: widget.userId),
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CoopvestColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: CoopvestColors.primary),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: context.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalsSection(BuildContext context, WidgetRef ref, List<SavingsGoal> goals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Savings Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SavingsGoalsScreen(userId: widget.userId),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (goals.isEmpty)
          AppCard(
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.savings_outlined, size: 48, color: CoopvestColors.mediumGray),
                  const SizedBox(height: 16),
                  Text(
                    'No active savings goals',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Navigate to create goal
                    },
                    child: const Text('Create a Goal'),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 16),
                  child: AppCard(
                    onTap: () {
                      // Navigate to goal details
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              goal.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary),
                            ),
                            Text(
                              '${goal.progressPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: CoopvestColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        LinearProgressIndicator(
                          value: goal.progressPercentage / 100,
                          backgroundColor: context.dividerColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₦${goal.currentAmount.toStringAsFixed(0)} of ₦${goal.targetAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref, List<Transaction> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TransactionsHistoryScreen(userId: widget.userId),
                  ),
                );
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No transactions yet',
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ),
          )
        else
          ...transactions.map((txn) => TransactionCard(
                title: txn.description ?? 'No description',
                subtitle: txn.type.toUpperCase(),
                amount: txn.amount,
                isIncome: txn.type == 'credit' || txn.type == 'deposit',
                date: DateFormat('MMM dd, yyyy').format(txn.createdAt),
                icon: _getTransactionIcon(txn.type),
              )),
      ],
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return Icons.add_circle_outline;
      case 'withdrawal':
        return Icons.remove_circle_outline;
      case 'loan_disbursement':
        return Icons.account_balance_wallet;
      case 'loan_repayment':
        return Icons.payment;
      default:
        return Icons.swap_horiz;
    }
  }

  void _showReceiveQRDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan this QR code to receive funds from another Coopvest user.'),
            const SizedBox(height: 24),
            QrImageView(
              data: widget.userId,
              version: QrVersions.auto,
              size: 200.0,
              foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
            const SizedBox(height: 16),
            Text(
              widget.userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'ID: ${widget.userId.length >= 8 ? widget.userId.substring(0, 8).toUpperCase() : widget.userId.toUpperCase()}',
              style: const TextStyle(color: CoopvestColors.mediumGray),
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