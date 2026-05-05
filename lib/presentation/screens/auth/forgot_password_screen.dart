import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/utils.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Forgot Password Screen — Step 1: enter email to receive OTP reset code
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late TextEditingController _emailController;
  String? _emailError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSubmit() async {
    setState(() => _emailError = Validators.validateEmail(_emailController.text));
    if (_emailError != null) return;

    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/auth/request-password-reset', data: {
        'email': _emailController.text.trim().toLowerCase(),
      });
    } catch (_) {
      // Backend always returns success to prevent email enumeration.
      // Navigate to OTP screen regardless.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushNamed(
          '/reset-password-otp',
          arguments: {'email': _emailController.text.trim().toLowerCase()},
        );
      }
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
        title: Text('Forgot Password', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.lock_reset, size: 40, color: CoopvestColors.primary),
              ),
              const SizedBox(height: 24),
              Text('Reset Your Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Enter your registered email address. We\'ll send you a 6-digit code to reset your password.',
                style: TextStyle(color: context.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              AppTextField(
                label: 'Email Address',
                hint: 'Enter your registered email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Send Reset Code',
                onPressed: _validateAndSubmit,
                isLoading: _isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Login', style: TextStyle(color: CoopvestColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
