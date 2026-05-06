import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/providers/referral_provider.dart';

/// Referral Sharing Screen
class ReferralSharingScreen extends ConsumerWidget {
  final String referralCode;
  final String userName;
  const ReferralSharingScreen({super.key, required this.referralCode, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralState = ref.watch(referralProvider);
    final shareLink = referralState.shareLink?.shareLink ?? 'https://coopvest.app/register?ref=$referralCode';

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close, color: context.iconPrimary), onPressed: () => Navigator.of(context).pop()),
        title: Text('Share Your Code', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildQRCodeSection(context, shareLink),
              const SizedBox(height: 24),
              _buildReferralCodeDisplay(context),
              const SizedBox(height: 32),
              _buildShareLinkSection(context, shareLink),
              const SizedBox(height: 32),
              _buildMessageTemplate(context, referralCode, userName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeSection(BuildContext context, String shareLink) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: CoopvestColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        children: [
          QrImageView(data: shareLink, version: QrVersions.auto, size: 200, backgroundColor: Colors.white, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B5E20)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1B5E20))),
          const SizedBox(height: 16),
          const Text('Scan to join Coopvest Africa', style: TextStyle(color: CoopvestColors.mediumGray, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildReferralCodeDisplay(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Code: ', style: TextStyle(color: context.textSecondary)),
          Text(referralCode, style: const TextStyle(color: CoopvestColors.primary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: referralCode)),
            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: CoopvestColors.primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.copy, color: Colors.white, size: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildShareLinkSection(BuildContext context, String shareLink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Share Link', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.dividerColor)),
          child: Row(
            children: [
              Expanded(child: Text(shareLink, style: TextStyle(color: context.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
              TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: shareLink)), child: const Text('Copy')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageTemplate(BuildContext context, String code, String name) {
    final message = "Hey! Join Coopvest Africa using my referral code $code and get exclusive benefits. https://coopvest.app/register?ref=$code";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Message Template', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)), TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: message)), child: const Text('Copy'))]),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: context.scaffoldBackground, borderRadius: BorderRadius.circular(8)), child: Text(message, style: TextStyle(color: context.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }
}
