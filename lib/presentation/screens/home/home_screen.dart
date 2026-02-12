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
      backgroundColor: CoopvestColors.veryLightGray,
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
    return Shimmer.fromColors(
      baseColor: CoopvestColorsEnhanced.shimmerBase,
      highlightColor: CoopvestColorsEnhanced.shimmerHighlight,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.mediumGray,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
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
    final quickActions = [
      {'icon': Icons.savings, 'label': 'Save', 'color': CoopvestColorsEnhanced.primaryGradient},
      {'icon': Icons.account_balance_wallet, 'label': 'Invest', 'color': CoopvestColorsEnhanced.accentGradient},
      {'icon': Icons.swap_horiz, 'label': 'Transfer', 'color': CoopvestColorsEnhanced.purpleGradient},
      {'icon': Icons.receipt_long, 'label': 'History', 'color': CoopvestColorsEnhanced.tealGradient},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Quick Actions',
          titleGradient: CoopvestColorsEnhanced.primaryGradient,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: quickActions.asMap().entries.map((entry) {
            final action = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: entry.key == 0 ? 0 : 6,
                  right: entry.key == quickActions.length - 1 ? 0 : 6,
                ),
                child: QuickActionButton(
                  icon: action['icon'] as IconData,
                  label: action['label'] as String,
                  gradientColors: action['color'] as List<Color>,
                  onTap: () {},
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSavingsGoals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Savings Goals',
          onViewAll: () {},
          viewAllText: 'See All',
          titleGradient: CoopvestColorsEnhanced.primaryGradient,
        ),
        const SizedBox(height: 16),
        AppAnimations.staggeredList(
          children: [
            ProgressCard(
              title: 'Emergency Fund',
              progress: 0.65,
              currentAmount: 'N\$32,500',
              targetAmount: 'N\$50,000',
              subtitle: '12 weeks to go',
              gradientColors: CoopvestColorsEnhanced.successGradient,
              onTap: () {},
            ),
            ProgressCard(
              title: 'New Phone',
              progress: 0.40,
              currentAmount: 'N\$20,000',
              targetAmount: 'N\$50,000',
              subtitle: '8 weeks to go',
              gradientColors: CoopvestColorsEnhanced.accentGradient,
              onTap: () {},
            ),
          ],
          staggerDelay: const Duration(milliseconds: 150),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = [
      {
        'icon': Icons.savings,
        'title': 'Savings Deposit',
        'subtitle': 'Emergency Fund',
        'amount': '5,000',
        'isIncome': true,
        'date': 'Today',
      },
      {
        'icon': Icons.account_balance,
        'title': 'Bank Transfer',
        'subtitle': 'From GTBank',
        'amount': '10,000',
        'isIncome': true,
        'date': 'Yesterday',
      },
      {
        'icon': Icons.shopping_cart,
        'title': 'Purchase',
        'subtitle': 'Market Items',
        'amount': '2,500',
        'isIncome': false,
        'date': '2 days ago',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Activity',
          onViewAll: () {},
          viewAllText: 'See All',
          titleGradient: CoopvestColorsEnhanced.primaryGradient,
        ),
        const SizedBox(height: 16),
        EnhancedCard(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: activities.asMap().entries.map((entry) {
              final activity = entry.value;
              return Column(
                children: [
                  ActivityItem(
                    icon: activity['icon'] as IconData,
                    title: activity['title'] as String,
                    subtitle: activity['subtitle'] as String,
                    amount: activity['amount'] as String,
                    isIncome: activity['isIncome'] as bool,
                    date: activity['date'] as String,
                    onTap: () {},
                  ),
                  if (entry.key < activities.length - 1)
                    Divider(
                      color: CoopvestColors.lightGray.withOpacity(0.5),
                      height: 1,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
