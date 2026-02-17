import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../../core/services/api_service.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Forgot Password Screen
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late TextEditingController _emailController;
  String? _emailError;
  bool _isLoading = false;
  bool _emailSent = false;

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

  void _validateAndSubmit() {
    setState(() => _emailError = Validators.validateEmail(_emailController.text));
    if (_emailError == null) _sendResetLink();
  }

  Future<void> _sendResetLink() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      final response = await apiService.post('/auth/forgot-password', data: {'email': _emailController.text.trim()});
      if (response['success'] == true && mounted) {
        setState(() { _emailSent = true; _isLoading = false; });
      } else {
        throw Exception(response['message'] ?? 'Failed to send reset link');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reset link: $e'), backgroundColor: CoopvestColors.error));
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
              if (!_emailSent) ...[
                Text('Reset Your Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
                const SizedBox(height: 8),
                Text('Enter your email address and we\'ll send you a link to reset your password', style: TextStyle(color: context.textSecondary)),
                const SizedBox(height: 32),
                AppTextField(label: 'Email Address', hint: 'Enter your registered email', controller: _emailController, keyboardType: TextInputType.emailAddress, errorText: _emailError),
                const SizedBox(height: 32),
                PrimaryButton(label: 'Send Reset Link', onPressed: _validateAndSubmit, isLoading: _isLoading, width: double.infinity),
                const SizedBox(height: 16),
                Center(child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to Login', style: TextStyle(color: CoopvestColors.primary)))),
              ] else ...[
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(color: CoopvestColors.success.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle, size: 80, color: CoopvestColors.success),
                      ),
                      const SizedBox(height: 32),
                      Text('Reset Link Sent!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
                      const SizedBox(height: 16),
                      Text('We\'ve sent a password reset link to ${_emailController.text}.', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)),
                      const SizedBox(height: 32),
                      SecondaryButton(label: 'Back to Login', onPressed: () => Navigator.of(context).pop(), width: double.infinity),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
