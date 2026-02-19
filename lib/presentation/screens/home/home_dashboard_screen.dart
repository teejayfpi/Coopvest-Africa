import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/wallet_models.dart';
import '../../../data/models/loan_models.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/providers/insights_provider.dart';
import '../../../presentation/providers/notifications_provider.dart';
import '../../../presentation/screens/wallet/deposit_screen.dart';
import '../../../presentation/screens/loan/loan_dashboard_screen.dart';
import '../../../presentation/screens/wallet/wallet_dashboard_screen.dart';
import '../../../presentation/screens/referral/referral_dashboard_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  late Future<void> _refreshFuture;

  @override
  void initState() {
    super.initState();
    _refreshFuture = _loadData();
    // Set up periodic refresh for real-time updates every 30 seconds
    _setupPeriodicRefresh();
  }

  Future<void> _loadData() async {
    await Future.wait([
      ref.read(walletProvider.notifier).loadWallet(),
      ref.read(loanProvider.notifier).getLoans(),
    ]);
  }

  void _setupPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadData();
        _setupPeriodicRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final loansState = ref.watch(loanProvider);
    
    final userName = user?.name.split(' ').first ?? 'User';
    final membershipId = user?.id.substring(0, 6) ?? 'N/A';
    
    final walletBalance = wallet?.balance ?? 0.0;
    final totalContributions = wallet?.totalContributions ?? 0.0;
    final activeLoans = loansState.loans
        .where((l) => l.status == 'active' || l.status == 'repaying')
        .fold(0.0, (sum, l) => sum + l.amount);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: CoopvestColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Dark Header Section
              _buildHeader(context, userName, membershipId, user?.name ?? 'User'),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overlapping Stats Cards
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Wallet Balance',
                                  '\u20a6${walletBalance.formatNumber()}',
                                  Icons.account_balance_wallet_outlined,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? ''))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Contributions',
                                  '\u20a6${totalContributions.formatNumber()}',
                                  Icons.savings_outlined,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? ''))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Loans',
                                  '\u20a6${activeLoans.formatNumber()}',
                                  Icons.monetization_on_outlined,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Quick Actions Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.75,
                      children: [
                        _buildActionButton(
                          context,
                          'Make Contribution',
                          Icons.payments_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(userId: user?.id ?? ''))),
                        ),
                        _buildActionButton(
                          context,
                          'Apply for Loan',
                          Icons.description_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                        ),
                        _buildActionButton(
                          context,
                          'Referral',
                          Icons.share_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferralDashboardScreen())),
                        ),
                        _buildActionButton(
                          context,
                          'Download Statements',
                          Icons.assignment_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? ''))),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Insights & Loan Status Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Insights Chart
                        Expanded(
                          flex: 3,
                          child: _buildInsightsCard(context, walletState),
                        ),
                        const SizedBox(width: 12),
                        // Loan Status
                        Expanded(
                          flex: 2,
                          child: _buildLoanStatusCard(context, loansState),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Notifications Section
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNotificationItem(
                      context,
                      'Your loan has been approved',
                      '2h ago',
                      Icons.notifications_outlined,
                      CoopvestColors.primary,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                    ),
                    const SizedBox(height: 12),
                    _buildNotificationItem(
                      context,
                      '5 Tips for Better Financial Planning',
                      '',
                      Icons.lightbulb_outline,
                      CoopvestColors.primary,
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Financial tips feature coming soon'),
                          backgroundColor: CoopvestColors.primary,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String membershipId, String fullName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 50),
      decoration: BoxDecoration(
        color: CoopvestColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Member ID: $membershipId',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSettingsScreen())),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white24,
              child: Text(
                _getInitials(fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: CoopvestColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.dividerColor.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CoopvestColors.primary, size: 24),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(BuildContext context, WalletState walletState) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: ref.read(currentUserProvider)?.id ?? '', userName: ref.read(currentUserProvider)?.name ?? ''))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Contributions',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const titles = ['Jan', 'Mar', 'May', 'Jun'];
                          if (value.toInt() % 2 == 0 && value.toInt() < titles.length * 2) {
                             final index = value.toInt() ~/ 2;
                             if (index < titles.length) {
                               return Text(titles[index], style: TextStyle(fontSize: 10, color: context.textSecondary));
                             }
                          }
                          return const Text('');
                        },
                        reservedSize: 22,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 20),
                        FlSpot(1, 40),
                        FlSpot(2, 30),
                        FlSpot(3, 50),
                        FlSpot(4, 45),
                        FlSpot(5, 70),
                      ],
                      isCurved: true,
                      color: CoopvestColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanStatusCard(BuildContext context, LoansState loansState) {
    final pendingLoan = loansState.loans.any((l) => l.status == 'under_review' || l.status == 'pending_guarantors');
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: ref.read(currentUserProvider)?.id ?? '', userName: ref.read(currentUserProvider)?.name ?? '', userPhone: ref.read(currentUserProvider)?.phone ?? ''))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Status',
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pendingLoan ? 'Pending\nApproval' : 'No Active\nApplications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.access_time, color: CoopvestColors.primary, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, String title, String time, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Import ProfileSettingsScreen at the top
import '../profile/profile_settings_screen.dart';
