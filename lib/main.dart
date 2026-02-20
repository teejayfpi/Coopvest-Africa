import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_config.dart';
import 'config/theme_config.dart';
import 'config/theme_enhanced.dart';
import 'core/services/feature_service.dart';
import 'presentation/screens/auth/welcome_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_step1_screen.dart';
import 'presentation/screens/auth/register_step2_screen.dart';
import 'presentation/screens/auth/google_complete_screen.dart';
import 'presentation/screens/auth/salary_deduction_consent_screen.dart';
import 'presentation/screens/auth/account_activation_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/auth/email_verification_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'presentation/screens/support/support_home_screen.dart';
import 'presentation/screens/support/ticket_creation_screen.dart';
import 'presentation/screens/support/ticket_list_screen.dart';
import 'presentation/screens/support/ticket_detail_screen.dart';
import 'presentation/screens/home/home_dashboard_screen.dart';
import 'presentation/screens/main_container.dart';
import 'presentation/screens/kyc/kyc_employment_details_screen.dart';
import 'presentation/screens/kyc/kyc_id_upload_screen.dart';
import 'presentation/screens/kyc/kyc_selfie_screen.dart';
import 'presentation/screens/kyc/kyc_success_screen.dart';
import 'presentation/screens/kyc/kyc_bank_info_screen.dart';
import 'presentation/screens/loan/loan_dashboard_screen.dart';
import 'presentation/screens/loan/loan_application_screen.dart';
import 'presentation/screens/loan/guarantor_verification_screen.dart';
import 'presentation/screens/loan/loan_details_screen.dart';
import 'presentation/screens/profile/profile_settings_screen.dart';
import 'presentation/screens/security/security_settings_screen.dart';
import 'presentation/screens/savings/savings_goals_screen.dart';
import 'presentation/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize feature service first (connects to admin backend)
  final featureService = FeatureService();
  try {
    await featureService.init().timeout(const Duration(seconds: 5));
  } catch (e) {
    // If timeout or error, continue anyway
    debugPrint('Feature service initialization failed: $e');
  }
  
  // Initialize Firebase, analytics, etc.
  // await Firebase.initializeApp();
  
  runApp(
    const ProviderScope(
      child: CoopvestApp(),
    ),
  );
}

class CoopvestApp extends ConsumerWidget {
  const CoopvestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: CoopvestTheme.lightTheme,
      darkTheme: CoopvestTheme.darkTheme,
      themeMode: themeMode,
      home: const MainContainer(),
      routes: {
        // Auth Routes
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterStep1Screen(),
        '/register-step2': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
          return RegisterStep2Screen(
            email: args?['email'] ?? '',
            registrationData: args ?? {},
          );
        },
        '/register-step3': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
          return SalaryDeductionConsentScreen(
            registrationData: args ?? {},
          );
        },
        '/account-activation': (context) => const AccountActivationScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/verify-email': (context) => const EmailVerificationScreen(),
        '/google-complete': (context) {
          final googleUser = ModalRoute.of(context)?.settings.arguments as GoogleSignInAccount?;
          return CompleteRegistrationScreen(googleUser: googleUser!);
        },
        
        // Support/Ticket Routes
        '/support': (context) => const SupportHomeScreen(),
        '/create-ticket': (context) => const TicketCreationScreen(),
        '/tickets': (context) => const TicketListScreen(),
        '/tickets/:id': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return TicketDetailScreen(
            ticketId: args?['ticketId'] ?? '',
          );
        },
        
        // KYC Routes
        '/kyc-employment-details': (context) => const KYCEmploymentDetailsScreen(),
        '/kyc-id-upload': (context) => const KYCIDUploadScreen(),
        '/kyc-selfie': (context) => const KYCSelfieScreen(),
        '/kyc-bank-info': (context) => const KYCBankInfoScreen(),
        '/kyc-success': (context) => const KYCSuccessScreen(),
        '/kyc-complete': (context) => const KYCSuccessScreen(),
        
        // Home & Dashboard Routes
        '/home': (context) => const MainContainer(),
        
        // Loan Routes
        '/loan-dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LoanDashboardScreen(
            userId: args?['userId'] ?? '',
            userName: args?['userName'] ?? '',
            userPhone: args?['userPhone'] ?? '',
          );
        },
        '/loan-application': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LoanApplicationScreen(
            userId: args?['userId'] ?? '',
            userName: args?['userName'] ?? 'User',
            userPhone: args?['userPhone'] ?? '',
          );
        },
        '/loan-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LoanDetailsScreen(
            loanId: args?['loanId'] ?? '',
          );
        },
        '/guarantor-verification': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return GuarantorVerificationScreen(
            loanId: args?['loanId'] ?? '',
            guarantorId: args?['guarantorId'] ?? '',
            borrowerName: args?['borrowerName'] ?? '',
            guarantorName: args?['guarantorName'] ?? '',
            loanAmount: args?['loanAmount']?.toDouble() ?? 0.0,
            loanType: args?['loanType'] ?? 'Quick Loan',
            loanTenor: args?['loanTenor'] ?? 4,
          );
        },
        
        // Profile Routes
        '/profile': (context) => const ProfileSettingsScreen(),
        '/security': (context) => const SecuritySettingsScreen(),
        
        // Savings Routes
        '/savings-goal': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return SavingsGoalsScreen(
            userId: args?['userId'] ?? '',
          );
        },
      },
    );
  }
}
