import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
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
import '../savings/savings_goals_screen.dart';
import '../rollover/rollover_eligibility_screen.dart';
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
      appBar: AppBar(
        elevation: 0,
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
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: iconColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileSettingsScreen(),
                ),
              );
            },
          ),
        ],
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
                _buildTimeBasedGreeting(userName),
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
                }),
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
                  }),
                  const SizedBox(height: 16),
                  ...savingsGoals.take(2).map((goal) => _buildGoalProgressCard(context, goal)),
                  const SizedBox(height: 32),
                ],
                _buildSectionHeader('Recent Activity', () {}),
                const SizedBox(height: 16),
                if (recentTransactions.isEmpty)
                  _buildEmptyActivityCard()
                else
                  ...recentTransactions.map((txn) => _buildActivityItem(context, txn)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            style: CoopvestTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: CoopvestTypography.bodySmall.copyWith(
              color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
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
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildQuickActionItem(
              context,
              'Deposit',
              Icons.add_circle_outline,
              Colors.green,
              () => Navigator.of(context).pushNamed('/deposit'),
            ),
            _buildQuickActionItem(
              context,
              'Withdraw',
              Icons.remove_circle_outline,
              Colors.red,
              () => Navigator.of(context).pushNamed('/withdrawal'),
            ),
            _buildQuickActionItem(
              context,
              'Loans',
              Icons.account_balance_wallet_outlined,
              Colors.blue,
              () => Navigator.of(context).pushNamed('/loan-dashboard', arguments: {
                'userId': userId,
                'userName': userName,
              }),
            ),
            _buildQuickActionItem(
              context,
              'Support',
              Icons.help_outline,
              Colors.orange,
              () => Navigator.of(context).pushNamed('/support'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: CoopvestTypography.bodySmall.copyWith(
              color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: const Text('See All'),
        ),
      ],
    );
  }

  Widget _buildEmptyTicketsCard(BuildContext context) {
    return AppCard(
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.confirmation_number_outlined, size: 48, color: CoopvestColors.mediumGray),
            const SizedBox(height: 12),
            const Text(
              'No active tickets',
              style: TextStyle(color: CoopvestColors.mediumGray),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/create-ticket'),
              child: const Text('Create Ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketItem(BuildContext context, models.Ticket ticket) {
    final statusColor = _getTicketStatusColor(ticket.status);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TicketDetailScreen(ticketId: ticket.id),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.confirmation_number_outlined, color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.subject,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    ticket.category,
                    style: TextStyle(
                      color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ticket.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d').format(ticket.createdAt),
                  style: TextStyle(
                    color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTicketStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildRolloverSection(BuildContext context) {
    return AppCard(
      backgroundColor: CoopvestColors.primary,
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loan Rollover',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Extend your loan repayment period easily.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RolloverEligibilityScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: CoopvestColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressCard(BuildContext context, SavingsGoal goal) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  goal.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: goal.progressPercentage / 100,
              backgroundColor: isDarkMode ? Colors.white10 : CoopvestColors.veryLightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\u20a6${goal.currentAmount.formatNumber()} of \u20a6${goal.targetAmount.formatNumber()}',
                  style: TextStyle(
                    color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${goal.monthsRemaining} months left',
                  style: TextStyle(
                    color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, Transaction txn) {
    IconData icon;
    Color color;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    switch (txn.type) {
      case 'contribution':
        icon = Icons.add_circle_outline;
        color = CoopvestColors.success;
        break;
      case 'withdrawal':
        icon = Icons.remove_circle_outline;
        color = CoopvestColors.error;
        break;
      case 'loan_repayment':
        icon = Icons.payment;
        color = CoopvestColors.primary;
        break;
      default:
        icon = Icons.swap_horiz;
        color = CoopvestColors.mediumGray;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description ?? txn.type.capitalize(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(txn.createdAt),
                  style: TextStyle(
                    color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${txn.type == 'withdrawal' ? '-' : '+'}\u20a6${txn.amount.formatNumber()}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: txn.type == 'withdrawal' ? CoopvestColors.error : CoopvestColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityCard() {
    return AppCard(
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.history, size: 48, color: CoopvestColors.mediumGray),
            const SizedBox(height: 12),
            const Text(
              'No recent activity',
              style: TextStyle(color: CoopvestColors.mediumGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBasedGreeting(String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;
    
    if (hour < 12) {
      greeting = 'Good morning';
      icon = Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      greeting = 'Good afternoon';
      icon = Icons.wb_sunny;
    } else {
      greeting = 'Good evening';
      icon = Icons.nights_stay_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CoopvestColors.primary, CoopvestColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}
