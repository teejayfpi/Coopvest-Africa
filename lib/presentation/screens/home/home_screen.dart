import 'package:flutter/material.dart';
import 'package:coopvest_mobile/config/theme_config.dart';
import 'package:coopvest_mobile/config/theme_extension.dart';
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
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: SafeArea(child: _isLoading ? _buildShimmerLoading() : _buildHomeContent()),
      floatingActionButton: GradientFloatingActionButton(onPressed: () {}, icon: Icons.add, gradientColors: CoopvestColorsEnhanced.accentGradient),
    );
  }

  Widget _buildShimmerLoading() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.white10 : CoopvestColorsEnhanced.shimmerBase;
    final highlightColor = isDarkMode ? Colors.white24 : CoopvestColorsEnhanced.shimmerHighlight;
    return Shimmer.fromColors(
      baseColor: baseColor, highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CoopvestSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShimmerHeader(), const SizedBox(height: 24),
            _buildShimmerBalanceCard(), const SizedBox(height: 24),
            _buildShimmerQuickActions(), const SizedBox(height: 24),
            _buildShimmerSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerHeader() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(width: 200, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))), Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))]);
  Widget _buildShimmerBalanceCard() => Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(CoopvestRadius.large)));
  Widget _buildShimmerQuickActions() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(4, (index) => Container(width: 70, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(CoopvestRadius.medium)))));
  Widget _buildShimmerSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 12), Container(height: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(CoopvestRadius.medium)))]);

  Widget _buildHomeContent() {
    return AppAnimations.fadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CoopvestSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(), const SizedBox(height: 24),
            AppAnimations.slideInUp(offset: 30, child: _buildBalanceCard()), const SizedBox(height: 24),
            AppAnimations.slideInUp(offset: 40, duration: 400.ms, child: _buildQuickActions()), const SizedBox(height: 24),
            AppAnimations.slideInUp(offset: 50, duration: 500.ms, child: _buildSavingsGoals()), const SizedBox(height: 24),
            AppAnimations.slideInUp(offset: 60, duration: 600.ms, child: _buildRecentActivity()), const SizedBox(height: 80),
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
            Text('Welcome back,', style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 4),
            ShaderMask(shaderCallback: (bounds) => CoopvestGradients.textGradient.createShader(bounds), child: Text('Ayanlowo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(gradient: CoopvestGradients.primaryButton, borderRadius: BorderRadius.circular(28), boxShadow: CoopvestShadows.coloredPrimary), child: const CircleAvatar(radius: 24, backgroundColor: Colors.transparent, child: Icon(Icons.person, color: Colors.white, size: 28))),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return EnhancedCard(
      useGradient: true, gradientColors: CoopvestColorsEnhanced.primaryGradient, padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Balance', style: TextStyle(color: Colors.white.withOpacity(0.9))), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.visibility, color: Colors.white, size: 14), SizedBox(width: 4), Text('Hidden', style: TextStyle(color: Colors.white, fontSize: 12))]))]),
          const SizedBox(height: 12),
          ShaderMask(shaderCallback: (bounds) => LinearGradient(colors: [Colors.white, Colors.white.withOpacity(0.8)]).createShader(bounds), child: Text('N\$125,450.00', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
          const SizedBox(height: 8),
          Row(children: [Icon(Icons.trending_up, color: Colors.white.withOpacity(0.9), size: 16), const SizedBox(width: 4), Text('+12.5%', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)), const SizedBox(width: 4), Text('this month', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12))]),
          const SizedBox(height: 20),
          Row(children: [Expanded(child: EnhancedButton(onPressed: () {}, text: 'Deposit', isEnabled: true, height: 44, textStyle: const TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 12), Expanded(child: SecondaryButton(onPressed: () {}, text: 'Withdraw', height: 44))]),
        ],
      ),
    );
  }

  Widget _buildQuickActions() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [QuickActionButton(onPressed: () {}, icon: Icons.send, label: 'Send'), QuickActionButton(onPressed: () {}, icon: Icons.payments, label: 'Pay'), QuickActionButton(onPressed: () {}, icon: Icons.account_balance_wallet, label: 'Wallet'), QuickActionButton(onPressed: () {}, icon: Icons.more_horiz, label: 'More')]);
  Widget _buildSavingsGoals() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionHeader(title: 'Savings Goals', onActionPressed: () {}), const SizedBox(height: 12), EnhancedCard(child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('New House', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)), Text('75%', style: TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold))]), const SizedBox(height: 8), LinearProgressIndicator(value: 0.75, backgroundColor: context.dividerColor, valueColor: const AlwaysStoppedAnimation(CoopvestColors.primary))]))]);
  Widget _buildRecentActivity() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionHeader(title: 'Recent Activity', onActionPressed: () {}), const SizedBox(height: 12), EnhancedCard(child: Column(children: [ActivityTile(icon: Icons.arrow_downward, title: 'Deposit', subtitle: 'Feb 12, 2024', amount: '+N\$5,000.00', color: CoopvestColors.success), Divider(color: context.dividerColor), ActivityTile(icon: Icons.arrow_upward, title: 'Withdrawal', subtitle: 'Feb 10, 2024', amount: '-N\$2,000.00', color: CoopvestColors.error)]))]);
}

class ActivityTile extends StatelessWidget {
  final IconData icon; final String title, subtitle, amount; final Color color;
  const ActivityTile({Key? key, required this.icon, required this.title, required this.subtitle, required this.amount, required this.color}) : super(key: key);
  @override
  Widget build(BuildContext context) => Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)), Text(subtitle, style: TextStyle(color: context.textSecondary, fontSize: 12))])), Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: color))]);
}
