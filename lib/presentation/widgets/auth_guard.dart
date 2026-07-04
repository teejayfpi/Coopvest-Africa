import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/main_container.dart';
import '../screens/auth/registration_onboarding_screen.dart';
import '../screens/auth/contribution_type_selection_screen.dart';
import '../screens/auth/salary_deduction_consent_screen.dart';
import '../screens/auth/account_activation_screen.dart';
import '../screens/kyc/kyc_employment_details_screen.dart';

/// AuthGuard determines where to send the user based on their auth state:
/// - Not authenticated → Welcome/Login screen (child widget)
/// - Authenticated but registration not complete → Continue registration
/// - Authenticated but KYC not complete → Continue KYC
/// - Authenticated and fully registered → Dashboard (child widget)
class AuthGuard extends ConsumerWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // If not authenticated, show the child (WelcomeScreen)
    if (!authState.isAuthenticated) {
      return child;
    }

    // Check if registration is complete
    if (user != null && !user.registrationCompleted) {
      // Continue registration from the next incomplete step
      return _buildRegistrationFlow(user);
    }

    // Check if KYC is approved
    if (user != null && user.kycStatus != 'approved') {
      // User needs to complete KYC
      return const KYCEmploymentDetailsScreen();
    }

    // All complete - show the dashboard
    return child;
  }

  Widget _buildRegistrationFlow(user) {
    // For now, redirect to registration onboarding
    // In a more advanced implementation, we could track the exact step
    // and redirect to the specific screen
    return const RegistrationOnboardingScreen(registrationData: {});
  }
}