import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_config.dart';
import '../../../config/theme_config.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/payment_proof_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';
import '../contributions/payment_proof_upload_screen.dart';

/// Account Activation Screen
///
/// Shown to a member who has completed registration and KYC verification but
/// has NOT yet paid the (non-refundable) ₦5,000 registration fee that unlocks
/// full member-dashboard access. Mirrors the server-side activation gate:
///
///   kyc_verified = TRUE AND registration_fee_paid = TRUE  → dashboard
///
/// This screen is purely informational + a pointer to the payment-proof
/// upload flow. The real enforcement lives on the backend; AuthGuard simply
/// routes here when the profile gate isn't satisfied.
class AccountActivationScreen extends ConsumerStatefulWidget {
  final String? paymentPendingNote;

  const AccountActivationScreen({super.key, this.paymentPendingNote});

  @override
  ConsumerState<AccountActivationScreen> createState() =>
      _AccountActivationScreenState();
}

class _AccountActivationScreenState
    extends ConsumerState<AccountActivationScreen> {
  bool _paying = false;

  /// Instant ₦5,000 activation via Paystack — on success the backend flips
  /// the registration-fee flag automatically, no proof upload needed.
  Future<void> _payWithPaystack() async {
    setState(() => _paying = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final resp = await apiClient.dio.post('/payments/initialize', data: {
        'amount': AppConfig.entranceFee,
        'payment_type': 'registration_fee',
      });
      final data = resp.data as Map<String, dynamic>;
      final url = data['authorization_url'] as String?;
      final reference = data['reference'] as String?;
      if (url == null || reference == null) {
        throw Exception('Could not start the online payment. Please try again.');
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('Could not open the payment page.');
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Complete Your Payment'),
          content: const Text(
            "A secure Paystack page has opened in your browser. "
            "Finish the ₦5,000 payment there, then come back and tap 'I have Paid'.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('I have Paid'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      String status = 'pending';
      for (var attempt = 0; attempt < 5 && status != 'success'; attempt++) {
        if (attempt > 0) await Future.delayed(const Duration(seconds: 2));
        try {
          final verify = await apiClient.dio.get('/payments/verify/\$reference');
          status =
              (verify.data as Map<String, dynamic>)['status'] as String? ?? 'pending';
        } catch (_) {/* keep polling */}
      }

      if (!mounted) return;
      if (status == 'success') {
        // Refresh the user so the activation gate flips, then head to the
        // dashboard (AuthGuard also lets them through on next launch).
        await ref.read(authProvider.notifier).refreshCurrentUser();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed — welcome to Coopvest Africa! 🎉'),
            backgroundColor: CoopvestColors.success,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Payment not confirmed yet. If you were debited, your membership will activate automatically within a few minutes.'),
            backgroundColor: CoopvestColors.warning,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final detail = e is DioException
          ? (e.response?.data?['error'] ?? e.message)
          : e;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Online payment failed: \$detail'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Activate Membership',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: CoopvestColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebration header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CoopvestColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.celebration,
                      size: 48,
                      color: CoopvestColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You're Almost There!",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CoopvestColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Coopvest Africa account has been successfully verified.\n\n'
                      'To activate your membership and gain access to your member dashboard, '
                      'please pay the ₦5,000 non-refundable registration fee.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: CoopvestColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Registration fee card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: CoopvestColors.lightGray),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Registration Fee',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₦${AppConfig.entranceFee.toStringAsFixed(0)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: CoopvestColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'One-time, non-refundable',
                        style: TextStyle(
                          fontSize: 12,
                          color: CoopvestColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account status breakdown
              Text(
                'Account Status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const _StatusRow(
                icon: Icons.verified,
                iconColor: CoopvestColors.success,
                label: 'KYC',
                value: '✅ Verified',
              ),
              const _StatusRow(
                icon: Icons.payment,
                iconColor: CoopvestColors.warning,
                label: 'Registration',
                value: '🟡 Payment Required',
                highlight: true,
              ),
              const _StatusRow(
                icon: Icons.lock_outline,
                iconColor: CoopvestColors.textSecondary,
                label: 'Membership',
                value: '🔒 Not Activated',
              ),
              const SizedBox(height: 24),

              // Primary action — instant online payment
              _paying
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: CoopvestColors.primary,
                        ),
                      ),
                    )
                  : PrimaryButton(
                      label: 'Pay ₦5,000 Instantly (Card / Transfer)',
                      icon: const Icon(Icons.bolt, color: Colors.white),
                      onPressed: _payWithPaystack,
                    ),
              const SizedBox(height: 8),
              Text(
                'Instant — your membership activates automatically once the payment confirms.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CoopvestColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CoopvestColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              // Manual path — bank transfer + proof upload (admin verifies
              // KYC and the payment together).
              PrimaryButton(
                label: 'Pay by Transfer & Upload Proof',
                icon: const Icon(Icons.upload_file, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentProofUploadScreen(
                        initialPaymentType: PaymentProofType.registrationFee,
                        prefillAmount: AppConfig.entranceFee,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Manual transfer: submit your proof of payment and an admin '
                'will verify it with your KYC — your dashboard then unlocks.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CoopvestColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single row in the account-status breakdown.
class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool highlight;

  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? CoopvestColors.warning.withOpacity(0.12)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? CoopvestColors.warning.withOpacity(0.4)
              : CoopvestColors.lightGray,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? CoopvestColors.warning : theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}