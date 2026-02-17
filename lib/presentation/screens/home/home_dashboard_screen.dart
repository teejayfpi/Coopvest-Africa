import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../data/models/wallet_models.dart';
import '../../../data/models/ticket_models.dart' as models;
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/providers/ticket_provider.dart';
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../loan/loan_dashboard_screen.dart';
import '../wallet/wallet_dashboard_screen.dart';
import '../wallet/deposit_screen.dart';
import '../wallet/withdrawal_screen.dart';
import '../savings/savings_goals_screen.dart';
import '../rollover/rollover_eligibility_screen.dart';
import '../support/support_home_screen.dart';
import '../support/ticket_list_screen.dart';
import '../support/ticket_detail_screen.dart';
import '../profile/profile_settings_screen.dart';
import 'notifications_screen.dart';

/// Main Home Dashboard Screen
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load data when dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ticketProvider.notifier).loadTickets();
      ref.read(walletProvider.notifier).loadWallet();
      ref.read(loanProvider.notifier).getLoans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final savingsGoals = walletState.savingsGoals.where((g) => g.status == 'active').toList();
    final recentTransactions = walletState.transactions.take(3).toList();
    
    final user = ref.watch(currentUserProvider);
    final userName = user?.name ?? 'User';
    final userId = user?.id ?? '';

    final ticketState = ref.watch(ticketProvider);
    final recentTickets = ticketState.tickets.take(2).toList();
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.white : CoopvestColors.darkGray;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Coopvest'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.notifications_none, color: iconColor),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(walletProvider.notifier).loadWallet();
            await ref.read(ticketProvider.notifier).loadTickets();
            await ref.read(loanProvider.notifier).getLoans();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeBasedGreeting(userName, context),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Savings',
                        '\u20a6${(wallet?.balance ?? 0).formatNumber()}',
                        Icons.savings,
                        CoopvestColors.success,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => WalletDashboardScreen(userId: userId, userName: userName),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Active Loans',
                        '${ref.watch(loanProvider).loans.where((l) => l.status == 'active' || l.status == 'repaying').length}',
                        Icons.account_balance,
                        CoopvestColors.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => LoanDashboardScreen(userId: userId, userName: userName, userPhone: ''),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Savings Goals',
                        '${savingsGoals.length}',
                        Icons.flag,
                        Colors.orange,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SavingsGoalsScreen(userId: userId),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Pending',
                        '\u20a6${(wallet?.pendingContributions ?? 0).formatNumber()}',
                        Icons.pending,
                        Colors.blue,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => WalletDashboardScreen(userId: userId, userName: userName),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildQuickActionsGrid(context, userId, userName),
                const SizedBox(height: 32),
                _buildRolloverSection(context),
                const SizedBox(height: 32),
                
                // Support Tickets Section
                _buildSectionHeader('Support Tickets', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TicketListScreen(),
                    ),
                  );
                }, context),
                const SizedBox(height: 16),
                if (ticketState.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (recentTickets.isEmpty)
                  _buildEmptyTicketsCard(context)
                else
                  ...recentTickets.map((ticket) => _buildTicketItem(context, ticket)),
                
                const SizedBox(height: 32),
                if (savingsGoals.isNotEmpty) ...[
                  _buildSectionHeader('Savings Goals', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SavingsGoalsScreen(userId: userId),
                      ),
                    );
                  }, context),
                  const SizedBox(height: 16),
                  ...savingsGoals.take(2).map((goal) => _buildGoalProgressCard(context, goal)),
                  const SizedBox(height: 32),
                ],
                _buildSectionHeader('Recent Activity', () {}, context),
                const SizedBox(height: 16),
                if (recentTransactions.isEmpty)
                  _buildEmptyActivityCard(context)
                else
                  ...recentTransactions.map((txn) => _buildActivityItem(context, txn)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBasedGreeting(String userName, BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
          ),
        ),
        Text(
          userName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return AppCard(
      onTap: onTap,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, String userId, String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 8,
          children: [
            _buildQuickActionItem(
              context,
              'Deposit',
              Icons.add_circle_outline,
              CoopvestColors.primary,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => DepositScreen(userId: userId)),
              ),
            ),
            _buildQuickActionItem(
              context,
              'Withdraw',
              Icons.remove_circle_outline,
              CoopvestColors.error,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => WithdrawalScreen(userId: userId)),
              ),
            ),
            _buildQuickActionItem(
              context,
              'Loan',
              Icons.account_balance_wallet_outlined,
              CoopvestColors.info,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: userId, userName: userName, userPhone: '')),
              ),
            ),
            _buildQuickActionItem(
              context,
              'Support',
              Icons.help_outline,
              Colors.purple,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SupportHomeScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('See All'),
        ),
      ],
    );
  }

  Widget _buildRolloverSection(BuildContext context) {
    return AppCard(
      backgroundColor: CoopvestColors.primary.withOpacity(0.1),
      border: Border.all(color: CoopvestColors.primary.withOpacity(0.2)),
      child: Row(
        children: [
          const Icon(Icons.autorenew, color: CoopvestColors.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loan Rollover',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  'Extend your loan repayment period easily.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: CoopvestColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RolloverEligibilityScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTicketItem(BuildContext context, models.Ticket ticket) {
    final statusColor = _getTicketStatusColor(ticket.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(ticketId: ticket.id),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.confirmation_number_outlined, color: statusColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.subject,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    'ID: ${ticket.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ticket.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgressCard(BuildContext context, SavingsGoal goal) {
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  '${goal.progressPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CoopvestColors.primary,
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
            const SizedBox(height: 8),
            Text(
              '\u20a6${goal.currentAmount.formatNumber()} of \u20a6${goal.targetAmount.formatNumber()}',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, Transaction txn) {
    final isCredit = txn.type == 'credit' || txn.type == 'deposit';
    final color = isCredit ? CoopvestColors.success : CoopvestColors.error;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(txn.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'}\u20a6${txn.amount.formatNumber()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTicketsCard(BuildContext context) {
    return AppCard(
      child: Center(
        child: Column(
          children: [
            Icon(Icons.confirmation_number_outlined, color: context.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'No active tickets',
              style: TextStyle(color: context.textSecondary),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/create-ticket');
              },
              child: const Text('Create a Ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivityCard(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No recent activity',
            style: TextStyle(color: context.textSecondary),
          ),
        ),
      ),
    );
  }

  Color _getTicketStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return CoopvestColors.info;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return CoopvestColors.success;
      case 'closed':
        return CoopvestColors.mediumGray;
      default:
        return CoopvestColors.mediumGray;
    }
  }
}