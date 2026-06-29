import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';

/// Registration Step 2 — Email Verification (Supabase)
///
/// Waits for the user to verify the email sent by Supabase during sign-up.
/// Uses Supabase's OTP/resend APIs to manage the verification flow.
class RegisterStep2Screen extends ConsumerStatefulWidget {
  final String email;
  final Map<String, String> registrationData;

  const RegisterStep2Screen({
    Key? key,
    required this.email,
    required this.registrationData,
  }) : super(key: key);

  @override
  ConsumerState<RegisterStep2Screen> createState() =>
      _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends ConsumerState<RegisterStep2Screen> {
  int _remainingSeconds = 60;
  bool _canResend = false;
  bool _isResending = false;
  bool _isChecking = false;

  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    setState(() {
      _remainingSeconds = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);
    _startTimer();

    try {
      await sb.Supabase.instance.client.auth.resend(
        type: sb.OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verification email sent successfully'),
          backgroundColor: CoopvestColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Failed to send verification email: ${e.toString()}'),
          backgroundColor: CoopvestColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);

    final supabase = sb.Supabase.instance.client;

    // If no session, user needs to log back in
    if (supabase.auth.currentSession == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session expired. Please sign in again.'),
          backgroundColor: CoopvestColors.error,
        ));
        Navigator.of(context).pushReplacementNamed('/login');
      }
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    try {
      // Refresh the session to get the latest user state from Supabase
      final response = await supabase.auth.refreshSession();
      final sbUser = response.user;

      if (sbUser != null && sbUser.emailConfirmedAt != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: CoopvestColors.success,
          ));
          // Navigate to contribution type selection before KYC registration
          Navigator.of(context).pushNamed(
            '/contribution-type-selection',
            arguments: widget.registrationData,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Email not yet verified. Please check your inbox and click the verification link.'),
            backgroundColor: CoopvestColors.warning,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Failed to check verification status: ${e.toString()}'),
          backgroundColor: CoopvestColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _openEmailInstructions() {
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
          style:
              TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                        color: CoopvestColors.primary, shape: BoxShape.circle),
                    child: const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 18)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Container(height: 2, color: CoopvestColors.primary)),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                        color: CoopvestColors.primary, shape: BoxShape.circle),
                    child: const Center(
                      child: Text('2',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CoopvestColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 40, color: CoopvestColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Verify Your Email Address',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('We sent a verification link to:',
                    style: TextStyle(color: context.textSecondary),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.email,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
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
                        const Icon(Icons.info_outline,
                            color: CoopvestColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('How to verify',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary)),
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
              PrimaryButton(
                label: "I've Verified My Email",
                onPressed: _checkVerificationStatus,
                isLoading: _isChecking,
                width: double.infinity,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _openEmailInstructions,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: CoopvestColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View Instructions',
                    style: TextStyle(color: CoopvestColors.primary)),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text("Didn't receive the email?",
                        style: TextStyle(color: context.textSecondary)),
                    const SizedBox(height: 8),
                    if (!_canResend)
                      Text('Resend in ${_remainingSeconds}s',
                          style: TextStyle(color: context.textSecondary))
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _resendVerificationEmail,
                        child: Text(
                          _isResending
                              ? 'Sending...'
                              : 'Resend Verification Email',
                          style: const TextStyle(
                              color: CoopvestColors.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () async {
                    // Sign out and go back to registration step 1
                    await sb.Supabase.instance.client.auth.signOut();
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
              child: Text(number,
                  style: const TextStyle(
                      color: CoopvestColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: context.textSecondary)),
        ],
      ),
    );
  }
}
