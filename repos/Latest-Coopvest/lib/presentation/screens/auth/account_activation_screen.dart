import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../widgets/common/buttons.dart';

/// Account Activation Confirmation Screen
class AccountActivationScreen extends StatefulWidget {
  const AccountActivationScreen({Key? key}) : super(key: key);

  @override
  State<AccountActivationScreen> createState() => _AccountActivationScreenState();
}

class _AccountActivationScreenState extends State<AccountActivationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(color: CoopvestColors.success.withOpacity(0.1), shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.check_circle, size: 80, color: CoopvestColors.success)),
              ).animate().scale(duration: 600.ms).fadeIn(),
              const SizedBox(height: 32),
              Text('Account Created Successfully!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 16),
              Text('Your Coopvest account is ready to use', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.dividerColor)),
                child: Column(
                  children: [
                    _buildConfirmationItem(context, Icons.check_circle_outline, 'Account Created', 'Your account has been successfully created'),
                    const SizedBox(height: 16),
                    Divider(color: context.dividerColor),
                    const SizedBox(height: 16),
                    _buildConfirmationItem(context, Icons.verified_user_outlined, 'Salary Deduction Consent', 'Your consent has been recorded and logged'),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Go to Login', onPressed: () => Navigator.of(context).pushReplacementNamed('/login'), width: double.infinity),
              const SizedBox(height: 16),
              Text('Redirecting to login in 3 seconds...', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationItem(BuildContext context, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: CoopvestColors.success, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: context.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
