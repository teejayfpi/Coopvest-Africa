import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Complete Registration Screen
/// Collects phone number after Google Sign-In
class CompleteRegistrationScreen extends ConsumerWidget {
  final GoogleSignInAccount googleUser;

  const CompleteRegistrationScreen({
    Key? key,
    required this.googleUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneController = TextEditingController();
    String? _phoneError;

    Future<void> _completeRegistration() async {
      final phone = phoneController.text.trim();
      final phoneError = Validators.validatePhone(phone);

      if (phoneError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(phoneError),
            backgroundColor: CoopvestColors.error,
          ),
        );
        return;
      }

      try {
        // Register user with Google info + phone
        await ref.read(authProvider.notifier).register(
          email: googleUser.email,
          password: '', // No password for Google users
          name: googleUser.displayName ?? 'User',
          phone: phone,
        );

        if (mounted) {
          // Navigate directly to Employment KYC (no OTP for Google users)
          Navigator.of(context).pushReplacementNamed('/kyc-employment-details');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${e.toString()}'),
              backgroundColor: CoopvestColors.error,
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CoopvestColors.darkGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Complete Registration',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Text(
                'Welcome, ${googleUser.displayName ?? 'User'}!',
                style: CoopvestTypography.headlineMedium.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Almost done! Please add your phone number to complete registration.',
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
              const SizedBox(height: 32),

              // Google account info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CoopvestColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: CoopvestColors.primary,
                      radius: 24,
                      backgroundImage: googleUser.photoUrl != null
                          ? NetworkImage(googleUser.photoUrl!)
                          : null,
                      child: googleUser.photoUrl == null
                          ? Text(
                              (googleUser.displayName?[0] ?? 'U').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            googleUser.displayName ?? 'User',
                            style: CoopvestTypography.bodyLarge.copyWith(
                              color: CoopvestColors.darkGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            googleUser.email,
                            style: CoopvestTypography.bodyMedium.copyWith(
                              color: CoopvestColors.mediumGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Phone number field
              AppTextField(
                label: 'Phone Number',
                hint: '+234 801 234 5678',
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                errorText: _phoneError,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.phone_outlined, color: CoopvestColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This phone number will be used for account recovery and notifications.',
                style: CoopvestTypography.bodySmall.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
              const SizedBox(height: 32),

              // Complete Registration Button
              PrimaryButton(
                label: 'Complete Registration',
                onPressed: _completeRegistration,
                width: double.infinity,
              ),
              const SizedBox(height: 16),

              // Skip for now (optional)
              Center(
                child: TextButton(
                  onPressed: () {
                    // Optionally skip and add phone later, go directly to KYC
                    Navigator.of(context).pushReplacementNamed('/kyc-employment-details');
                  },
                  child: Text(
                    'Add phone number later',
                    style: CoopvestTypography.bodyMedium.copyWith(
                      color: CoopvestColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}