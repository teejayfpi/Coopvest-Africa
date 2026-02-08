import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Login Screen with Biometric Authentication
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _emailError;
  String? _passwordError;
  bool _isAuthenticating = false;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

    if (_emailError == null && _passwordError == null) {
      _performLogin();
    }
  }

  Future<void> _performLogin() async {
    try {
      await ref.read(authProvider.notifier).login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        await ref.read(authProvider.notifier).googleSignIn(idToken);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: ${e.toString()}'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      setState(() {
        _isAuthenticating = true;
      });

      // Check if user has registered/logged in before by checking for a stored token
      final authState = ref.read(authProvider);
      if (authState.accessToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in with your email and password first to enable biometric login'),
              backgroundColor: CoopvestColors.warning,
            ),
          );
        }
        return;
      }

      // Check if biometric authentication is available
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      
      if (!canAuthenticateWithBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication is not available on this device'),
              backgroundColor: CoopvestColors.warning,
            ),
          );
        }
        return;
      }

      // Authenticate using biometrics
      final bool didAuthenticate = await _localAuth.authenticate(
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
        localizedReason: 'Authenticate to log in to Coopvest',
      );

      if (didAuthenticate && mounted) {
        // Biometric authentication successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication successful'),
            backgroundColor: CoopvestColors.success,
          ),
        );
        // Navigate to home after successful biometric auth
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.message}'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Welcome Back',
                style: CoopvestTypography.displaySmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to your Coopvest account',
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
              const SizedBox(height: 32),

              // Email/Phone Field
              AppTextField(
                label: 'Email or Phone Number',
                hint: 'Enter your email or phone',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                errorText: _emailError,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.mail_outline, color: CoopvestColors.primary),
                ),
                onChanged: (_) {
                  if (_emailError != null) {
                    setState(() {
                      _emailError = Validators.validateEmail(_emailController.text);
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Password Field
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                errorText: _passwordError,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.lock_outline, color: CoopvestColors.primary),
                ),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  child: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: CoopvestColors.mediumGray,
                  ),
                ),
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() {
                      _passwordError = Validators.validatePassword(_passwordController.text);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Remember Me & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Remember Me
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _rememberMe = !_rememberMe;
                      });
                    },
                    child: Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: CoopvestColors.primary,
                        ),
                        Text(
                          'Remember me',
                          style: CoopvestTypography.bodySmall.copyWith(
                            color: CoopvestColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Forgot Password
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/forgot-password');
                    },
                    child: Text(
                      'Forgot Password?',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: CoopvestColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Login Button
              PrimaryButton(
                label: 'Log In',
                onPressed: _validateAndLogin,
                isLoading: isLoading,
                isEnabled: !isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 20),

              // Biometric Login - Implemented with local_auth package
              SecondaryButton(
                label: _isAuthenticating ? 'Authenticating...' : 'Use Biometric',
                onPressed: _authenticateWithBiometrics,
                isLoading: _isAuthenticating,
                isEnabled: !_isAuthenticating,
                width: double.infinity,
                icon: const Icon(Icons.fingerprint),
              ),
              const SizedBox(height: 16),

              // Google Sign-In Button
              SecondaryButton(
                label: 'Sign in with Google',
                onPressed: _handleGoogleSignIn,
                isLoading: isLoading,
                isEnabled: !isLoading,
                width: double.infinity,
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.login),
                ),
              ),
              const SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: CoopvestColors.lightGray,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: CoopvestColors.mediumGray,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: CoopvestColors.lightGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Sign Up Link
              Center(
                child: RichText(
                  text: TextSpan(
                    text: "Don't have an account? ",
                    style: CoopvestTypography.bodyMedium.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                    children: [
                      TextSpan(
                        text: 'Create Account',
                        style: CoopvestTypography.bodyMedium.copyWith(
                          color: CoopvestColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).pushNamed('/register');
                          },
                      ),
                    ],
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
