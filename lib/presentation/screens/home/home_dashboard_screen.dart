import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
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

/// Main Home Dashboard Screen - Enhanced Version
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
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
    final recentTransactions = walletState.transactions.take(4).toList();
    
    final user = ref.watch(currentUserProvider);
    final userName = user?.name ?? 'User';
    final userId = user?.id ?? '';
    final userInitials = _getInitials(userName);

    final ticketState = ref.watch(ticketProvider);
    final recentTickets = ticketState.tickets.take(2).toList();
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.scaffoldBackground,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CoopvestColors.primary,
                    CoopvestColors.primaryLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CoopvestColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'C',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coopvest',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: context.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeBasedGreeting(userName, context),
                const SizedBox(height: 24),
                
                // Main Balance Card
                _buildBalanceCard(wallet, context),
                const SizedBox(height: 24),
                
                // Stats Row
                _buildStatsRow(wallet, context, userId, userName),
                const SizedBox(height: 28),
                
                // Quick Actions
                _buildQuickActionsGrid(context, userId, userName),
                const SizedBox(height: 28),
                
                // Rollover Banner
                _buildRolloverSection(context),
                const SizedBox(height: 28),
                
                // Support Tickets Section
                _buildSectionHeader('Support Tickets', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TicketListScreen(),
                    ),
                  );
                }, context),
                const SizedBox(height: 12),
                if (ticketState.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (recentTickets.isEmpty)
                  _buildEmptyTicketsCard(context)
                else
                  ...recentTickets.map((ticket) => _buildTicketItem(context, ticket)),
                
                const SizedBox(height: 24),
                
                // Savings Goals
                if (savingsGoals.isNotEmpty) ...[
                  _buildSectionHeader('Savings Goals', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SavingsGoalsScreen(userId: userId),
                      ),
                    );
                  }, context),
                  const SizedBox(height: 12),
                  ...savingsGoals.take(2).map((goal) => _buildGoalProgressCard(context, goal)),
                  const SizedBox(height: 24),
                ],
                
                // Recent Activity
                _buildSectionHeader('Recent Activity', () {}, context),
                const SizedBox(height: 12),
                if (recentTransactions.isEmpty)
                  _buildEmptyActivityCard(context)
                else
                  ...recentTransactions.map((txn) => _buildActivityItem(context, txn)),
                  
                const SizedBox(height: 80), // Space for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              userName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(Wallet? wallet, BuildContext context) {
    final balance = wallet?.balance ?? 0.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
            ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
            : [CoopvestColors.primary, CoopvestColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₦${balance.formatNumber()}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, color: Colors.white.withOpacity(0.9), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Hide',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildBalanceAction(Icons.add, 'Deposit', () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => DepositScreen(userId: wallet?.userId ?? '')),
                );
              }),
              const SizedBox(width: 12),
              _buildBalanceAction(Icons.remove, 'Withdraw', () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => WithdrawalScreen(userId: wallet?.userId ?? '')),
                );
              }),
              const SizedBox(width: 12),
              _buildBalanceAction(Icons.swap_horiz, 'Transfer', () {
                // Navigate to transfer
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(Wallet? wallet, BuildContext context, String userId, String userName) {
    final activeLoans = ref.watch(loanProvider).loans.where((l) => l.status == 'active' || l.status == 'repaying').length;
    final savingsGoals = ref.watch(walletProvider).savingsGoals.where((g) => g.status == 'active').length;
    final pending = wallet?.pendingContributions ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Active Loans',
            '$activeLoans',
            Icons.account_balance_wallet,
            const Color(0xFF1565C0),
            context,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LoanDashboardScreen(userId: userId, userName: userName, userPhone: ''),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Savings Goals',
            '$savingsGoals',
            Icons.flag,
            const Color(0xFFF57C00),
            context,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SavingsGoalsScreen(userId: userId),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            '₦${pending.formatNumber()}',
            Icons.pending,
            const Color(0xFF7B1FA2),
            context,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, BuildContext context, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, String userId, String userName) {
    final quickActions = [
      {'label': 'Deposit', 'icon': Icons.add_circle, 'color': CoopvestColors.success, 'route': () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => DepositScreen(userId: userId)))},
      {'label': 'Withdraw', 'icon': Icons.remove_circle, 'color': CoopvestColors.error, 'route': () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => WithdrawalScreen(userId: userId)))},
      {'label': 'Loans', 'icon': Icons.payments, 'color': const Color(0xFF1565C0), 'route': () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: userId, userName: userName, userPhone: '')))},
      {'label': 'Support', 'icon': Icons.headset_mic, 'color': const Color(0xFF7B1FA2), 'route': () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SupportHomeScreen()))},
      {'label': 'Savings', 'icon': Icons.savings, 'color': const Color(0xFFF57C00), 'route': () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => SavingsGoalsScreen(userId: userId)))},
      {'label': 'History', 'icon': Icons.history, 'color': const Color(0xFF00838F), 'route': () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: userId, userName: userName)))},
      {'label': 'Referral', 'icon': Icons.share, 'color': const Color(0xFF5D4037), 'route': () => {}},
      {'label': 'Profile', 'icon': Icons.person, 'color': const Color(0xFF455A64), 'route': () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()))},
    ];

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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: quickActions.length,
          itemBuilder: (context, index) {
            final action = quickActions[index];
            return GestureDetector(
              onTap: action['route'] as VoidCallback,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (action['color'] as Color).withOpacity(0.2)),
                    ),
                    child: Icon(
                      action['icon'] as IconData,
                      color: action['color'] as Color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    action['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
          child: Text(
            'See All',
            style: TextStyle(
              color: CoopvestColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRolloverSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withOpacity(0.08),
            const Color(0xFF2E7D32).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CoopvestColors.primary.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CoopvestColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.autorenew, color: CoopvestColors.primary, size: 28),
          ),
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
                const SizedBox(height: 4),
                Text(
                  'Extend your loan repayment period easily',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: CoopvestColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const RolloverEligibilityScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketItem(BuildContext context, models.Ticket ticket) {
    final statusColor = _getTicketStatusColor(ticket.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TicketDetailScreen(ticketId: ticket.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.confirmation_number_outlined, color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.subject,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ticket.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalProgressCard(BuildContext context, SavingsGoal goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flag, color: Colors.orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      goal.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${goal.progressPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CoopvestColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.progressPercentage / 100,
                backgroundColor: CoopvestColors.veryLightGray,
                valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₦${goal.currentAmount.formatNumber()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  '₦${goal.targetAmount.formatNumber()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
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
    final isCredit = txn.type == 'credit' || txn.type == 'deposit';
    final color = isCredit ? CoopvestColors.success : CoopvestColors.error;
    final icon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.description ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                  '${isCredit ? '+' : '-'}₦${txn.amount.formatNumber()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTicketsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.confirmation_number_outlined, color: context.textSecondary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'No active tickets',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Need help? Create a support ticket',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: CoopvestColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/create-ticket');
              },
              child: const Text(
                'Create a Ticket',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.history, color: context.textSecondary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transactions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
        ],
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
