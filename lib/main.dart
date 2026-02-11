import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_config.dart';
import 'config/theme_config.dart';
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
import 'presentation/screens/savings/savings_goals_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    // Watch theme mode provider (will implement later)
    // final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: CoopvestTheme.lightTheme,
      darkTheme: CoopvestTheme.darkTheme,
      themeMode: ThemeMode.system, // Will be dynamic later
      home: const SplashScreen(),
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
        '/home': (context) => const HomeDashboardScreen(),
        
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

/// Splash Screen - Entry point of the app
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize feature service first (connects to admin backend)
    final featureService = FeatureService();
    await featureService.init();
    
    // Simulate initialization delay
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      // Navigate directly to home - NO login/registration required
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoopvestTheme.lightTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).toInt()),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // App Name
            const Text(
              'Coopvest Africa',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Tagline
            const Text(
              'Save. Borrow. Invest. Together.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}