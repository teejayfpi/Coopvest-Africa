import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/referral_models.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/referral_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import 'referral_sharing_screen.dart';

/// Referral Dashboard Screen
class ReferralDashboardScreen extends ConsumerWidget {
  const ReferralDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralState = ref.watch(referralProvider);
    final referralNotifier = ref.read(referralProvider.notifier);
    final user = ref.watch(currentUserProvider);
    final userName = user?.name ?? 'User';

    if (referralState.status == ReferralStatus.initial) {
      Future.microtask(() {
        referralNotifier.loadReferralSummary();
        referralNotifier.loadReferralCode();
        referralNotifier.loadReferrals();
      });
    }

    final summary = referralState.summary;
    final tierProgress = referralNotifier.getTierProgress();
    final referralCode = referralState.referralCode ?? 'LOADING...';

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        title: Text('My Referrals', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: CoopvestColors.primary),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => ReferralSharingScreen(referralCode: referralCode, userName: userName))),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReferralCodeCard(context, referralCode, ref),
              const SizedBox(height: 24),
              _buildTierProgressCard(context, tierProgress),
              const SizedBox(height: 24),
              _buildStatsRow(context, summary),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Share My Referral Code', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => ReferralSharingScreen(referralCode: referralCode, userName: userName))), width: double.infinity, icon: const Icon(Icons.share)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(BuildContext context, String referralCode, WidgetRef ref) {
    return AppCard(
      backgroundColor: CoopvestColors.primary.withOpacity(0.1),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.card_giftcard, color: CoopvestColors.primary, size: 28), const SizedBox(width: 8), Text('Your Referral Code', style: TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: CoopvestColors.primary.withOpacity(0.3))),
            child: Text(referralCode, style: const TextStyle(color: CoopvestColors.primary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SecondaryButton(label: 'Copy', onPressed: () {}, icon: const Icon(Icons.copy)),
              const SizedBox(width: 12),
              SecondaryButton(label: 'Share QR', onPressed: () {}, icon: const Icon(Icons.qr_code)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierProgressCard(BuildContext context, TierProgress tierProgress) {
    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Tier', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: CoopvestColors.primary, borderRadius: BorderRadius.circular(20)),
                child: Text(tierProgress.tierName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: tierProgress.progress, minHeight: 12, backgroundColor: context.dividerColor, valueColor: const AlwaysStoppedAnimation<Color>(CoopvestColors.primary))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${tierProgress.currentTier.toStringAsFixed(0)}% discount', style: TextStyle(color: context.textSecondary, fontSize: 12)),
              if (!tierProgress.isMaxTier) Text('${tierProgress.referralsToNext} more to ${tierProgress.nextTier!.toStringAsFixed(0)}%', style: const TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, ReferralSummary? summary) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(context, 'Confirmed', '${summary?.confirmedReferrals ?? 0}', Icons.check_circle, CoopvestColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(context, 'Pending', '${summary?.pendingReferrals ?? 0}', Icons.hourglass_empty, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(context, 'Total', '${summary?.totalReferrals ?? 0}', Icons.people, CoopvestColors.primary)),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return AppCard(
      backgroundColor: color.withOpacity(0.1),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
          Text(title, style: TextStyle(fontSize: 10, color: context.textSecondary)),
        ],
      ),
    );
  }
}
