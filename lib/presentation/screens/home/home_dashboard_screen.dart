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

/// Main Home Dashboard Screen - Premium Enhanced Version
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      ref.read(ticketProvider.notifier).loadTickets();
      ref.read(walletProvider.notifier).loadWallet();
      ref.read(loanProvider.notifier).getLoans();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

    final ticketState = ref.watch(ticketProvider);
    final recentTickets = ticketState.tickets.take(2).toList();
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildPremiumAppBar(context, userName),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeBasedGreeting(userName, context),
                    const SizedBox(height: 20),
                    _buildBalanceCard(wallet, context),
                    const SizedBox(height: 20),
                    _buildStatsRow(wallet, context, userId, userName),
                    const SizedBox(height: 24),
                    _buildQuickActionsGrid(context, userId, userName),
                    const SizedBox(height: 24),
                    _buildRolloverBanner(context),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Support Tickets', () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const TicketListScreen()),
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
                    if (savingsGoals.isNotEmpty) ...[
                      _buildSectionHeader('Savings Goals', () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => SavingsGoalsScreen(userId: userId)),
                        );
                      }, context),
                      const SizedBox(height: 12),
                      ...savingsGoals.take(2).map((goal) => _buildGoalProgressCard(context, goal)),
                      const SizedBox(height: 24),
                    ],
                    _buildSectionHeader('Recent Activity', () {}, context),
                    const SizedBox(height: 12),
                    if (recentTransactions.isEmpty)
                      _buildEmptyActivityCard(context)
                    else
                      ...recentTransactions.map((txn) => _buildActivityItem(context, txn)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar(BuildContext context, String userName) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
            ? [const Color(0xFF1B5E20), const Color(0xFF0D3813)]
            : [CoopvestColors.primary, CoopvestColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.account_balance, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coopvest',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Your financial companion',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            _buildAppBarIcon(
              Icons.notifications_none,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            _buildAppBarIcon(
              Icons.person_outline,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onTap,
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
    IconData emoji;
    if (hour < 12) {
      greeting = 'Good Morning';
      emoji = Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      emoji = Icons.light_mode;
    } else {
      greeting = 'Good Evening';
      emoji = Icons.nights_stay_outlined;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: CoopvestColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(emoji, color: CoopvestColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
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
            const SizedBox(height: 2),
            Text(
              userName,
              style: TextStyle(
                fontSize: 20,
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
    final pending = wallet?.pendingContributions ?? 0;
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
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                  Row(
                    children: [
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '₦${balance.formatNumber()}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.visibility_outlined, color: Colors.white.withOpacity(0.9), size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildBalanceDetail('Available', '₦${balance.formatNumber()}'),
              const SizedBox(width: 24),
              _buildBalanceDetail('Pending', '₦${pending.formatNumber()}'),
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
              _buildBalanceAction(Icons.swap_horiz, 'Transfer', () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Wallet? wallet, BuildContext context, String userId, String userName) {
    final activeLoans = ref.watch(loanProvider).loans.where((l) => l.status == 'active' || l.status == 'repaying').length;
    final savingsGoals = ref.watch(walletProvider).savingsGoals.where((g) => g.status == 'active').length;
    final pending = wallet?.pendingContributions ?? 0;
    final walletBalance = wallet?.balance ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Savings',
                '₦${walletBalance.formatNumber()}',
                Icons.savings,
                CoopvestColors.primary,
                context,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: userId, userName: userName)),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Loans',
                '$activeLoans',
                Icons.account_balance_wallet,
                const Color(0xFF1565C0),
                context,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: userId, userName: userName, userPhone: '')),
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
                '$savingsGoals',
                Icons.flag,
                const Color(0xFFF57C00),
                context,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => SavingsGoalsScreen(userId: userId)),
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
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.08),
              color.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
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
                fontSize: 13,
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
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: quickActions.length,
          itemBuilder: (context, index) {
            final action = quickActions[index];
            return _buildQuickActionItem(
              action['label'] as String,
              action['icon'] as IconData,
              action['color'] as Color,
              action['route'] as VoidCallback,
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildRolloverBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CoopvestColors.primary.withOpacity(0.1),
            CoopvestColors.primary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CoopvestColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [CoopvestColors.primary, CoopvestColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CoopvestColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.autorenew, color: Colors.white, size: 26),
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
                    fontSize: 17,
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
              gradient: LinearGradient(
                colors: [CoopvestColors.primary, CoopvestColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => TicketDetailScreen(ticketId: ticket.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
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
                      const SizedBox(height: 5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flag, color: Color(0xFFF57C00), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      goal.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [CoopvestColors.primary.withOpacity(0.8), CoopvestColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${goal.progressPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: goal.progressPercentage / 100,
                backgroundColor: CoopvestColors.veryLightGray,
                valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₦${goal.currentAmount.formatNumber()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  '₦${goal.targetAmount.formatNumber()}',
                  style: TextStyle(
                    fontSize: 14,
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
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
                          fontSize: 15,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
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
                    fontSize: 16,
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.confirmation_number_outlined, color: context.textSecondary, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            'No active tickets',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
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
          const SizedBox(height: 18),
          GestureDetector(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [CoopvestColors.primary, CoopvestColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CoopvestColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.history, color: context.textSecondary, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            'No recent activity',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
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
