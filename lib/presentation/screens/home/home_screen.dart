import 'package:flutter/material.dart';
import 'package:coopvest_mobile/config/theme_config.dart';
import 'package:coopvest_mobile/config/theme_enhanced.dart';
import 'package:coopvest_mobile/presentation/widgets/common/enhanced_components.dart';
import 'package:coopvest_mobile/presentation/widgets/common/enhanced_buttons.dart';
import 'package:coopvest_mobile/config/animations.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _simulateLoading();
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading ? _buildShimmerLoading() : _buildHomeContent(),
      ),
      floatingActionButton: GradientFloatingActionButton(
        onPressed: () {
          // Quick add action
        },
        icon: Icons.add,
        gradientColors: CoopvestColorsEnhanced.accentGradient,
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.white10 : CoopvestColorsEnhanced.shimmerBase;
    final highlightColor = isDarkMode ? Colors.white24 : CoopvestColorsEnhanced.shimmerHighlight;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CoopvestSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShimmerHeader(),
            const SizedBox(height: 24),
            _buildShimmerBalanceCard(),
            const SizedBox(height: 24),
            _buildShimmerQuickActions(),
            const SizedBox(height: 24),
            _buildShimmerSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 200,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerBalanceCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CoopvestRadius.large),
      ),
    );
  }

  Widget _buildShimmerQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        4,
        (index) => Container(
          width: 70,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CoopvestRadius.medium),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CoopvestRadius.medium),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return AppAnimations.fadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CoopvestSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            AppAnimations.slideInUp(
              offset: 30,
              child: _buildBalanceCard(),
            ),
            const SizedBox(height: 24),
            AppAnimations.slideInUp(
              offset: 40,
              duration: const Duration(milliseconds: 400),
              child: _buildQuickActions(),
            ),
            const SizedBox(height: 24),
            AppAnimations.slideInUp(
              offset: 50,
              duration: const Duration(milliseconds: 500),
              child: _buildSavingsGoals(),
            ),
            const SizedBox(height: 24),
            AppAnimations.slideInUp(
              offset: 60,
              duration: const Duration(milliseconds: 600),
              child: _buildRecentActivity(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
              ),
            ),
            const SizedBox(height: 4),
            ShaderMask(
              shaderCallback: (bounds) => CoopvestGradients.textGradient.createShader(bounds),
              child: Text(
                'Ayanlowo',
                style: CoopvestTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: CoopvestGradients.primaryButton,
            borderRadius: BorderRadius.circular(28),
            boxShadow: CoopvestShadows.coloredPrimary,
          ),
          child: const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.transparent,
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return EnhancedCard(
      useGradient: true,
      gradientColors: CoopvestColorsEnhanced.primaryGradient,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Hidden',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, Colors.white.withOpacity(0.8)],
            ).createShader(bounds),
            child: Text(
              'N\$125,450.00',
              style: CoopvestTypography.displayLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.white.withOpacity(0.9), size: 16),
              const SizedBox(width: 4),
              Text(
                '+12.5%',
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'this month',
                style: CoopvestTypography.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: EnhancedButton(
                  onPressed: () {},
                  text: 'Deposit',
                  isEnabled: true,
                  height: 44,
                  textStyle: CoopvestTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  onPressed: () {},
                  text: 'Withdraw',
                  height: 44,
                  textStyle: CoopvestTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem('Deposit', Icons.add_circle_outline, CoopvestColorsEnhanced.tealGradient),
        _buildActionItem('Transfer', Icons.swap_horiz, CoopvestColorsEnhanced.purpleGradient),
        _buildActionItem('Loan', Icons.account_balance_wallet, CoopvestColorsEnhanced.accentGradient),
        _buildActionItem('Bill', Icons.receipt_long, CoopvestColorsEnhanced.secondaryGradient),
      ],
    );
  }

  Widget _buildActionItem(String label, IconData icon, List<Color> gradient) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(CoopvestRadius.medium),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: CoopvestTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsGoals() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Savings Goals',
              style: CoopvestTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
              ),
            ),
            Text(
              'View All',
              style: CoopvestTypography.bodySmall.copyWith(
                color: CoopvestColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildGoalCard('New House', 'N\$45,000 / N\$100,000', 0.45, CoopvestColorsEnhanced.primaryGradient),
              _buildGoalCard('Education', 'N\$12,000 / N\$20,000', 0.60, CoopvestColorsEnhanced.accentGradient),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(String title, String progress, double percent, List<Color> gradient) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      child: EnhancedCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: CoopvestTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              progress,
              style: CoopvestTypography.bodySmall.copyWith(color: CoopvestColors.mediumGray),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: CoopvestColors.veryLightGray,
                valueColor: AlwaysStoppedAnimation<Color>(gradient[0]),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: CoopvestTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
          ),
        ),
        const SizedBox(height: 16),
        _buildActivityItem('Electricity Bill', '24 Oct 2023', '-N\$4,500', Icons.bolt, Colors.orange),
        _buildActivityItem('Salary Deposit', '20 Oct 2023', '+N\$85,000', Icons.account_balance_wallet, Colors.green),
        _buildActivityItem('Loan Repayment', '15 Oct 2023', '-N\$12,000', Icons.payment, Colors.blue),
      ],
    );
  }

  Widget _buildActivityItem(String title, String date, String amount, IconData icon, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: EnhancedCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    style: CoopvestTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    date,
                    style: CoopvestTypography.bodySmall.copyWith(color: CoopvestColors.mediumGray),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: CoopvestTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: amount.startsWith('+') ? Colors.green : (isDarkMode ? Colors.white : CoopvestColors.darkGray),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
