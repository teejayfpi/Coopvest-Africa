import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Registration Step 1 - Basic Account Creation
class RegisterStep1Screen extends ConsumerStatefulWidget {
  const RegisterStep1Screen({Key? key}) : super(key: key);

  @override
  ConsumerState<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends ConsumerState<RegisterStep1Screen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  double _passwordStrength = 0;
  bool _isLoadingGoogle = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0;

    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;

    setState(() {
      _passwordStrength = strength;
    });
  }

  String _getPasswordStrengthText() {
    if (_passwordStrength < 0.25) return 'Weak';
    if (_passwordStrength < 0.5) return 'Fair';
    if (_passwordStrength < 0.75) return 'Good';
    return 'Strong';
  }

  Color _getPasswordStrengthColor() {
    if (_passwordStrength < 0.25) return CoopvestColors.error;
    if (_passwordStrength < 0.5) return CoopvestColors.warning;
    if (_passwordStrength < 0.75) return Colors.orange;
    return CoopvestColors.success;
  }

  void _validateAndContinue() {
    setState(() {
      _nameError = Validators.validateName(_nameController.text);
      _phoneError = Validators.validatePhone(_phoneController.text);
      _emailError = Validators.validateEmail(_emailController.text);
      _passwordError = Validators.validatePassword(_passwordController.text);
      _confirmPasswordError = _passwordController.text != _confirmPasswordController.text
          ? 'Passwords do not match'
          : null;
    });

    if (_nameError == null &&
        _phoneError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _agreeToTerms) {
      // Navigate to step 2
      Navigator.of(context).pushNamed(
        '/register-step2',
        arguments: {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        },
      );
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms & Privacy Policy'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignup(BuildContext context) async {
    try {
      setState(() {
        _isLoadingGoogle = true;
      });

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoadingGoogle = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        // Sign up with Google token
        await ref.read(authProvider.notifier).googleSignIn(idToken);

        if (mounted) {
          // Navigate to home after successful signup
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-Up failed: ${e.toString()}'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Create Account',
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
              // Progress Indicator
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CoopvestColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: CoopvestColors.lightGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CoopvestColors.lightGray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        '2',
                        style: TextStyle(
                          color: CoopvestColors.mediumGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Subtitle
              Text(
                'Basic Account Information',
                style: CoopvestTypography.headlineMedium.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your basic information to get started',
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
              const SizedBox(height: 24),

              // Full Name
              AppTextField(
                label: 'Full Name',
                hint: 'As per your official ID',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                errorText: _nameError,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.person_outline, color: CoopvestColors.primary),
                ),
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() {
                      _nameError = Validators.validateName(_nameController.text);
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Phone Number
              AppTextField(
                label: 'Phone Number',
                hint: '+234 801 234 5678',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                errorText: _phoneError,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.phone_outlined, color: CoopvestColors.primary),
                ),
                onChanged: (_) {
                  if (_phoneError != null) {
                    setState(() {
                      _phoneError = Validators.validatePhone(_phoneController.text);
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Email
              AppTextField(
                label: 'Email Address',
                hint: 'your.email@example.com',
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

              // Password
              AppTextField(
                label: 'Password',
                hint: 'Create a strong password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
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
              ),
              const SizedBox(height: 12),

              // Password Strength Indicator
              if (_passwordController.text.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Password Strength',
                          style: CoopvestTypography.bodySmall.copyWith(
                            color: CoopvestColors.mediumGray,
                          ),
                        ),
                        Text(
                          _getPasswordStrengthText(),
                          style: CoopvestTypography.labelSmall.copyWith(
                            color: _getPasswordStrengthColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _passwordStrength,
                        minHeight: 4,
                        backgroundColor: CoopvestColors.lightGray,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getPasswordStrengthColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use uppercase, numbers, and special characters',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: CoopvestColors.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Confirm Password
              AppTextField(
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                errorText: _confirmPasswordError,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.lock_outline, color: CoopvestColors.primary),
                ),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  child: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: CoopvestColors.mediumGray,
                  ),
                ),
                onChanged: (_) {
                  if (_confirmPasswordError != null) {
                    setState(() {
                      _confirmPasswordError = _passwordController.text != _confirmPasswordController.text
                          ? 'Passwords do not match'
                          : null;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Terms & Privacy
              GestureDetector(
                onTap: () {
                  setState(() {
                    _agreeToTerms = !_agreeToTerms;
                  });
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                      activeColor: CoopvestColors.primary,
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: 'I agree to the ',
                          style: CoopvestTypography.bodySmall.copyWith(
                            color: CoopvestColors.mediumGray,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: CoopvestTypography.bodySmall.copyWith(
                                color: CoopvestColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' and ',
                              style: CoopvestTypography.bodySmall.copyWith(
                                color: CoopvestColors.mediumGray,
                              ),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: CoopvestTypography.bodySmall.copyWith(
                                color: CoopvestColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Google Sign-In Button
              SecondaryButton(
                label: _isLoadingGoogle ? 'Creating account...' : 'Sign up with Google',
                onPressed: _isLoadingGoogle ? null : () => _handleGoogleSignup(context),
                isLoading: _isLoadingGoogle,
                isEnabled: !_isLoadingGoogle,
                width: double.infinity,
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.login),
                ),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              // Continue Button
              PrimaryButton(
                label: 'Continue',
                onPressed: _validateAndContinue,
                width: double.infinity,
              ),
              const SizedBox(height: 16),

              // Login Link
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'Already have an account? ',
                    style: CoopvestTypography.bodyMedium.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                    children: [
                      TextSpan(
                        text: 'Log In',
                        style: CoopvestTypography.bodyMedium.copyWith(
                          color: CoopvestColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).pushNamed('/login');
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