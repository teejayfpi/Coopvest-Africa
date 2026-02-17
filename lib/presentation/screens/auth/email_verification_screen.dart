import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Email Verification Screen
class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String? email;
  const EmailVerificationScreen({Key? key, this.email}) : super(key: key);

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  late TextEditingController _emailController;
  late TextEditingController _otpController;
  bool _isResending = false;
  bool _isVerifying = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;
  String? _successMessage;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _otpController = TextEditingController();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    setState(() { _cooldownSeconds = seconds; _isResending = false; });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_cooldownSeconds > 0) { _cooldownSeconds--; } else { timer.cancel(); }
        });
      }
    });
  }

  Future<void> _checkVerificationStatus() async {
    if (_emailController.text.isEmpty) return;
    try {
      final response = await ApiClient().getDio().get('/api/v1/auth/check-email-verification', queryParameters: {'email': _emailController.text});
      if (response.data['success'] == true && mounted) {
        setState(() { _isVerified = response.data['isVerified'] ?? false; });
        if (_isVerified) Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) { debugPrint('Error checking verification status: $e'); }
  }

  Future<void> _resendVerificationEmail() async {
    if (_emailController.text.isEmpty) { setState(() => _errorMessage = 'Please enter your email address'); return; }
    setState(() { _isResending = true; _errorMessage = null; _successMessage = null; });
    try {
      final response = await ApiClient().getDio().post('/api/v1/auth/resend-verification-email', queryParameters: {'email': _emailController.text});
      if (mounted) {
        final data = response.data;
        if (data['success'] == true) {
          setState(() { _successMessage = 'Verification email sent!'; _errorMessage = null; });
          if (data['cooldownSeconds'] != null) _startCooldown(data['cooldownSeconds']);
        } else {
          setState(() => _errorMessage = data['error'] ?? 'Failed to send verification email');
          if (data['remainingSeconds'] != null) _startCooldown(data['remainingSeconds']);
        }
      }
    } catch (e) { if (mounted) setState(() => _errorMessage = 'Failed to send verification email'); }
    finally { if (mounted) setState(() => _isResending = false); }
  }

  Future<void> _verifyOTP() async {
    if (_emailController.text.isEmpty) { setState(() => _errorMessage = 'Please enter your email address'); return; }
    if (_otpController.text.length < 6) { setState(() => _errorMessage = 'Please enter a valid 6-digit code'); return; }
    setState(() { _isVerifying = true; _errorMessage = null; _successMessage = null; });
    try {
      final response = await ApiClient().getDio().post('/api/v1/auth/verify-otp', data: {'email': _emailController.text, 'otp': _otpController.text});
      if (mounted) {
        final data = response.data;
        if (data['success'] == true) {
          setState(() { _isVerified = true; _successMessage = 'Email verified successfully!'; _errorMessage = null; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email verified successfully!'), backgroundColor: CoopvestColors.success));
          Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.of(context).pushReplacementNamed('/home'); });
        } else { setState(() => _errorMessage = data['error'] ?? 'Invalid verification code'); }
      }
    } catch (e) { if (mounted) setState(() => _errorMessage = 'Verification failed'); }
    finally { if (mounted) setState(() => _isVerifying = false); }
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(_isVerified ? Icons.check_circle : Icons.mail_outline, size: 50, color: _isVerified ? CoopvestColors.success : CoopvestColors.primary),
              ),
              const SizedBox(height: 32),
              Text(_isVerified ? 'Email Verified!' : 'Verify Your Email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 16),
              Text(_isVerified ? 'Your email has been verified.' : 'Please enter the 6-digit code sent to your email.', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)),
              const SizedBox(height: 32),
              if (!_isVerified) ...[
                AppTextField(label: 'Email Address', hint: 'Enter your registered email', controller: _emailController, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                AppTextField(label: 'Verification Code (OTP)', hint: 'Enter 6-digit code', controller: _otpController, keyboardType: TextInputType.number, maxLength: 6),
                const SizedBox(height: 32),
                if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: CoopvestColors.error, fontSize: 12)),
                if (_successMessage != null) Text(_successMessage!, style: const TextStyle(color: CoopvestColors.success, fontSize: 12)),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Verify Code', onPressed: _verifyOTP, isLoading: _isVerifying, width: double.infinity),
                const SizedBox(height: 16),
                SecondaryButton(label: _cooldownSeconds > 0 ? 'Resend in ${_cooldownSeconds}s' : 'Resend Email', onPressed: _cooldownSeconds > 0 ? () async {} : _resendVerificationEmail, isLoading: _isResending, width: double.infinity),
              ],
            ],
          ),
        ),
      ),
    );
  }
}