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
import '../../../presentation/widgets/common/cards.dart';
import '../loan/loan_dashboard_screen.dart';
import '../wallet/wallet_dashboard_screen.dart';
import '../savings/savings_goals_screen.dart';
import '../rollover/rollover_eligibility_screen.dart';
import '../loan/qr_scanner_screen.dart';
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
    // Load tickets when dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ticketProvider.notifier).loadTickets();
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.notifications_none, color: CoopvestColors.darkGray),
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
            icon: const Icon(Icons.settings, color: CoopvestColors.darkGray),
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
                        '1',
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
    return AppCard(
      onTap: onTap,
      backgroundColor: color.withAlpha((255 * 0.1).toInt()),
      border: Border.all(color: color.withAlpha((255 * 0.2).toInt())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: CoopvestTypography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: CoopvestTypography.bodySmall.copyWith(
              color: CoopvestColors.mediumGray,
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
          style: CoopvestTypography.titleMedium.copyWith(
            color: CoopvestColors.darkGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.request_quote,
                label: 'Loans',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LoanDashboardScreen(
                        userId: userId, 
                        userName: userName, 
                        userPhone: '',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.account_balance_wallet,
                label: 'Wallet',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WalletDashboardScreen(userId: userId, userName: userName),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.qr_code_scanner,
                label: 'Scan QR',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => QRScannerScreen(
                        guarantorId: userId,
                        guarantorName: userName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.support_agent,
                label: 'Support',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SupportHomeScreen(),
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

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: CoopvestColors.veryLightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: CoopvestColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: CoopvestTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: CoopvestTypography.titleMedium.copyWith(
            color: CoopvestColors.darkGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildEmptyTicketsCard(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.support_agent, size: 48, color: CoopvestColors.mediumGray),
          const SizedBox(height: 12),
          Text(
            'No active support tickets',
            style: CoopvestTypography.bodyMedium.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SupportHomeScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CoopvestColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Get Help'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketItem(BuildContext context, models.Ticket ticket) {
    Color statusColor;
    switch (ticket.status) {
      case 'open':
        statusColor = Colors.blue;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        break;
      case 'resolved':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(ticketId: ticket.ticketId),
            ),
          );
        },
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((255 * 0.1).toInt()),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.confirmation_number, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      style: CoopvestTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: CoopvestColors.darkGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ID: ${ticket.ticketId}',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: CoopvestColors.mediumGray,
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
                      color: statusColor.withAlpha((255 * 0.1).toInt()),
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
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                  style: CoopvestTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
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
            const SizedBox(height: 12),
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
                  '\u20a6${goal.currentAmount.formatNumber()} of \u20a6${goal.targetAmount.formatNumber()}',
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

  Widget _buildActivityItem(BuildContext context, Transaction txn) {
    IconData icon;
    Color color;
    
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
              color: color.withAlpha((255 * 0.1).toInt()),
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
                  style: CoopvestTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(txn.createdAt),
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${txn.type == 'withdrawal' ? '-' : '+'}\u20a6${txn.amount.formatNumber()}',
            style: CoopvestTypography.bodyMedium.copyWith(
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
            Text(
              'No recent activity',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.mediumGray,
              ),
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
      icon = Icons.wb_twilight;
    } else {
      greeting = 'Good evening';
      icon = Icons.nights_stay;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: CoopvestColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              greeting,
              style: CoopvestTypography.headlineMedium.copyWith(
                color: CoopvestColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          userName,
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}