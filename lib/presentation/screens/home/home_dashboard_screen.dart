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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWallet();
      ref.read(loanProvider.notifier).getLoans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final loansState = ref.watch(loanProvider);
    
    final userName = user?.name.split(' ').first ?? 'User';
    final membershipId = user?.id.substring(0, 6) ?? '567890';
    
    final walletBalance = wallet?.balance ?? 0.0;
    final totalContributions = wallet?.totalContributions ?? 0.0;
    final activeLoans = loansState.loans
        .where((l) => l.status == 'active' || l.status == 'repaying')
        .fold(0.0, (sum, l) => sum + l.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Dark Header Section
              _buildHeader(context, userName, membershipId),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overlapping Stats Cards
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Wallet Balance',
                              '\u20a6${walletBalance.formatNumber()}',
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Contributions',
                              '\u20a6${totalContributions.formatNumber()}',
                              Icons.savings_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Loans',
                              '\u20a6${activeLoans.formatNumber()}',
                              Icons.monetization_on_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Quick Actions Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                      children: [
                        _buildActionButton(
                          'Make Contribution',
                          Icons.payments_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(userId: user?.id ?? ''))),
                        ),
                        _buildActionButton(
                          'Apply for Loan',
                          Icons.description_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: ''))),
                        ),
                        _buildActionButton(
                          'Referral',
                          Icons.share_outlined,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferralDashboardScreen())),
                        ),
                        _buildActionButton(
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
                          child: _buildInsightsCard(walletState),
                        ),
                        const SizedBox(width: 12),
                        // Loan Status
                        Expanded(
                          flex: 2,
                          child: _buildLoanStatusCard(loansState),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Notifications Section
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNotificationItem(
                      'Your loan has been approved',
                      '2h ago',
                      Icons.notifications_outlined,
                      CoopvestColors.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildNotificationItem(
                      '5 Tips for Better Financial Planning',
                      '',
                      Icons.lightbulb_outline,
                      CoopvestColors.primary,
                    ),
                    
                    const SizedBox(height: 80), // Space for bottom nav
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String membershipId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 50),
      decoration: const BoxDecoration(
        color: CoopvestColors.primary, // Coopvest Green
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
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
                'Membership ID: $membershipId',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=teejay'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
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
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CoopvestColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(WalletState walletState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text(
            'Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Contributions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
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
                        const titles = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (value.toInt() < titles.length) {
                          return Text(titles[value.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey));
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
    );
  }

  Widget _buildLoanStatusCard(LoansState loansState) {
    final pendingLoan = loansState.loans.any((l) => l.status == 'under_review' || l.status == 'pending_guarantors');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text(
            'Loan Status',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pendingLoan ? 'Pending\nApproval' : 'No Active\nApplications',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(Icons.access_time, color: CoopvestColors.primary, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: CoopvestColors.primary,
        unselectedItemColor: Colors.black45,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Loans'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined), label: 'Investments'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
