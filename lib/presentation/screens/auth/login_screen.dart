import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';
import '../../../data/models/auth_models.dart';

/// Login Screen - Firebase Authentication
/// 
/// Handles user login via:
/// 1. Email + Password (Firebase Auth)
/// 2. Google Sign-In (Firebase Auth with Google provider)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateAndLogin() {
    setState(() {
      _emailError = Validators.validateEmail(_emailController.text);
      _passwordError = Validators.validatePassword(_passwordController.text);
    });
    if (_emailError == null && _passwordError == null) _performLogin();
  }

  Future<void> _performLogin() async {
    try {
      await ref.read(authProvider.notifier).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('AuthException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: CoopvestColors.error),
        );
      }
    }
  }

  Future<void> _performGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authProvider.notifier).googleSignIn();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('AuthException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: CoopvestColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to your Coopvest account',
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 32),

              // Email field
              AppTextField(
                label: 'Email Address',
                hint: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              const SizedBox(height: 20),

              // Password field
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: context.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/forgot-password'),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: CoopvestColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Login button
              PrimaryButton(
                label: 'Log In',
                onPressed: _validateAndLogin,
                isLoading: isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 24),

              // Divider with "or"
              Row(
                children: [
                  Expanded(child: Divider(color: context.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with',
                      style: TextStyle(color: context.textSecondary, fontSize: 14),
                    ),
                  ),
                  Expanded(child: Divider(color: context.dividerColor)),
                ],
              ),
              const SizedBox(height: 24),

              // Google Sign-In button
              OutlinedButton(
                onPressed: _isGoogleLoading ? null : _performGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: context.dividerColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isGoogleLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.textSecondary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://www.google.com/favicon.ico',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.g_mobiledata,
                              size: 24,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: context.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/register'),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: CoopvestColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
