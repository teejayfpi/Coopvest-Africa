import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';

/// Registration Step 2 - Email Verification (Firebase)
/// 
/// This screen handles email verification using Firebase's built-in
/// email verification system. The user's Firebase account was already
/// created in Step 1, and a verification email was automatically sent.
class RegisterStep2Screen extends ConsumerStatefulWidget {
  final String email;
  final Map<String, String> registrationData;

  const RegisterStep2Screen({
    Key? key,
    required this.email,
    required this.registrationData,
  }) : super(key: key);

  @override
  ConsumerState<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends ConsumerState<RegisterStep2Screen> {
  int _remainingSeconds = 60;
  bool _canResend = false;
  bool _isResending = false;
  bool _isChecking = false;

  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds == 0) {
            _canResend = true;
          } else {
            _startTimer();
          }
        });
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _remainingSeconds = 60;
      _canResend = false;
      _isResending = true;
    });
    _startTimer();
    
    try {
      // Use Firebase to resend verification email
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent successfully'),
              backgroundColor: CoopvestColors.success,
            ),
          );
        }
      } else {
        throw Exception('No user signed in');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: ${e.toString()}'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);
    
    try {
      // Reload the user to get the latest email verification status
      await _firebaseAuth.currentUser?.reload();
      final currentUser = _firebaseAuth.currentUser;
      
      if (currentUser != null && currentUser.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully!'),
              backgroundColor: CoopvestColors.success,
            ),
          );
          // Navigate to the next step (salary deduction consent or home)
          Navigator.of(context).pushNamed('/register-step3', arguments: widget.registrationData);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email not yet verified. Please check your inbox and click the verification link.'),
              backgroundColor: CoopvestColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check verification status: ${e.toString()}'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _openEmailApp() async {
    // Show a dialog with instructions
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check Your Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We sent a verification link to:\n${widget.email}'),
              const SizedBox(height: 16),
              const Text(
                'Please:\n'
                '1. Open your email app\n'
                '2. Find the email from Coopvest\n'
                '3. Click the verification link\n'
                '4. Return here and tap "I\'ve Verified"',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Verify Email',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: CoopvestColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 2, color: CoopvestColors.primary)),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: CoopvestColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '2',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Email icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CoopvestColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 40,
                    color: CoopvestColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Center(
                child: Text(
                  'Verify Your Email Address',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Center(
                child: Text(
                  'We sent a verification link to:',
                  style: TextStyle(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.email,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Instructions card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: CoopvestColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'How to verify',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1', 'Open your email app'),
                    _buildStep('2', 'Find the email from Coopvest'),
                    _buildStep('3', 'Click the verification link'),
                    _buildStep('4', 'Return here and tap the button below'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Check verification button
              PrimaryButton(
                label: "I've Verified My Email",
                onPressed: _checkVerificationStatus,
                isLoading: _isChecking,
                width: double.infinity,
              ),
              const SizedBox(height: 16),

              // Open email app button
              OutlinedButton(
                onPressed: _openEmailApp,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: CoopvestColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Instructions',
                  style: TextStyle(color: CoopvestColors.primary),
                ),
              ),
              const SizedBox(height: 24),

              // Resend section
              Center(
                child: Column(
                  children: [
                    Text(
                      "Didn't receive the email?",
                      style: TextStyle(color: context.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    if (!_canResend)
                      Text(
                        'Resend in ${_remainingSeconds}s',
                        style: TextStyle(color: context.textSecondary),
                      )
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _resendVerificationEmail,
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend Verification Email',
                          style: const TextStyle(
                            color: CoopvestColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Change email option
              Center(
                child: TextButton(
                  onPressed: () async {
                    // Sign out the partially created user and go back
                    try {
                      await _firebaseAuth.currentUser?.delete();
                    } catch (e) {
                      // User might already be deleted or not exist
                    }
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text(
                    'Use a Different Email Address',
                    style: TextStyle(color: CoopvestColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: CoopvestColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: CoopvestColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}
