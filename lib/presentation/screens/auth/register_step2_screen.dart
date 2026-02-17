import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/services/api_service.dart';
import '../../widgets/common/buttons.dart';

/// Registration Step 2 - Email Verification with OTP
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
  late List<TextEditingController> _otpControllers;
  late List<FocusNode> _otpFocusNodes;
  int _remainingSeconds = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(6, (_) => TextEditingController());
    _otpFocusNodes = List.generate(6, (_) => FocusNode());
    _startTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) controller.dispose();
    for (var node in _otpFocusNodes) node.dispose();
    super.dispose();
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

  Future<void> _resendOTP() async {
    setState(() {
      _remainingSeconds = 60;
      _canResend = false;
      _isResending = true;
      for (var controller in _otpControllers) controller.clear();
    });
    _startTimer();
    try {
      await _apiService.post('/auth/resend-otp', data: {'email': widget.email});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent successfully'), backgroundColor: CoopvestColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to resend OTP: $e'), backgroundColor: CoopvestColors.error));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onOTPFieldChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter all 6 digits'), backgroundColor: CoopvestColors.error));
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final response = await _apiService.post('/auth/verify-otp', data: {'email': widget.email, 'otp': otp});
      if (response['success'] == true && mounted) {
        Navigator.of(context).pushNamed('/register-step3', arguments: widget.registrationData);
      } else {
        throw Exception(response['message'] ?? 'Verification failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e'), backgroundColor: CoopvestColors.error));
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
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
        title: Text('Verify Email', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
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
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: CoopvestColors.primary, shape: BoxShape.circle),
                    child: const Center(child: Icon(Icons.check, color: Colors.white, size: 18)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 2, color: CoopvestColors.primary)),
                  const SizedBox(width: 8),
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: CoopvestColors.primary, shape: BoxShape.circle),
                    child: const Center(child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Verify Your Email Address', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 8),
              Text('We sent a 6-digit code to ${widget.email}', style: TextStyle(color: context.textSecondary)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => Flexible(
                  child: Container(
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    height: 60,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      onChanged: (value) => _onOTPFieldChanged(value, index),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: context.cardBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.dividerColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CoopvestColors.primary, width: 2)),
                      ),
                      style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    if (!_canResend)
                      Text('Resend code in ${_remainingSeconds}s', style: TextStyle(color: context.textSecondary))
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _resendOTP,
                        child: Text(_isResending ? 'Sending...' : 'Resend Code', style: const TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Verify', onPressed: _verifyOTP, isLoading: _isVerifying, width: double.infinity),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Change Email Address', style: TextStyle(color: CoopvestColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
