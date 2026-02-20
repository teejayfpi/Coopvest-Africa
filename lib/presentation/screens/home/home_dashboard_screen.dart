import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/wallet_models.dart';
import '../../../data/models/loan_models.dart';
import '../../../data/models/announcement_models.dart';
import '../../../data/models/guarantor_models.dart';
import '../../../data/models/document_models.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/providers/insights_provider.dart';
import '../../../presentation/providers/notifications_provider.dart';
import '../../../presentation/providers/announcements_provider.dart';
import '../../../presentation/providers/guarantor_provider.dart';
import '../../../presentation/providers/document_provider.dart';
import '../../../presentation/screens/wallet/deposit_screen.dart';
import '../../../presentation/screens/loan/loan_dashboard_screen.dart';
import '../../../presentation/screens/wallet/wallet_dashboard_screen.dart';
import '../../../presentation/screens/referral/referral_dashboard_screen.dart';
import '../../../presentation/screens/contributions/monthly_contributions_screen.dart';
import '../../../presentation/screens/transactions/transactions_history_screen.dart';
import '../../../presentation/screens/announcements/announcements_screen.dart';
import '../../../presentation/screens/guarantor/guarantor_dashboard_screen.dart';
import '../../../presentation/screens/documents/document_upload_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  late Future<void> _refreshFuture;
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshFuture = _loadData();
    _setupPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        ref.read(walletProvider.notifier).loadWallet(),
        ref.read(loanProvider.notifier).getLoans(),
      ]);
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading dashboard data: $e');
      }
    }
  }

  void _setupPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadData();
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
              _buildHeader(context, userName, membershipId, user?.name ?? 'User'),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stat Cards - Overlapping
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Wallet Balance',
                              '₦${walletBalance.formatNumber()}',
                              Icons.account_balance_wallet_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? ''))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Contributions',
                              '₦${totalContributions.formatNumber()}',
                              Icons.savings_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MonthlyContributionsScreen())),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Loans',
                              '₦${activeLoans.formatNumber()}',
                              Icons.monetization_on_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
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
                          'Investment Pool',
                          Icons.trending_up_outlined,
                          () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Investment Pool coming soon'),
                              backgroundColor: CoopvestColors.primary,
                            ),
                          ),
                        ),
                        _buildActionButton(
                          context,
                          'Download Statements',
                          Icons.assignment_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionsHistoryScreen())),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Insights & Loan Status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildInsightsCard(context, walletState),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildLoanStatusCard(context, loansState),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Notifications Section
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNotificationItem(
                      context,
                      'Your loan has been approved',
                      '2h ago',
                      Icons.check_circle_outline,
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
                    
                    const SizedBox(height: 32),
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
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Membership ID: $membershipId',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSettingsScreen())),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                _getInitials(fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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

  Widget _buildCompactStatCard(BuildContext context, String title, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CoopvestColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: CoopvestColors.primary, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CoopvestColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: CoopvestColors.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Contributions',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
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
                          const titles = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                          if (value.toInt() < titles.length) {
                            return Text(titles[value.toInt()], style: TextStyle(fontSize: 9, color: context.textSecondary));
                          }
                          return const Text('');
                        },
                        reservedSize: 20,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 20),
                        FlSpot(1, 35),
                        FlSpot(2, 28),
                        FlSpot(3, 45),
                        FlSpot(4, 40),
                        FlSpot(5, 60),
                      ],
                      isCurved: true,
                      color: CoopvestColors.primary,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: CoopvestColors.primary.withOpacity(0.1),
                      ),
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
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
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pendingLoan ? 'Pending\nApproval' : 'No Active\nApplications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.access_time_outlined,
                color: CoopvestColors.primary.withOpacity(0.6),
                size: 28,
              ),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  if (time.isNotEmpty) ...[ 
                    const SizedBox(height: 3),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
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

import '../profile/profile_settings_screen.dart';
