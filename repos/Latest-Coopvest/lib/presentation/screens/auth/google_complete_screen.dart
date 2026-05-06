import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';

/// Complete Registration Screen
class CompleteRegistrationScreen extends ConsumerStatefulWidget {
  final GoogleSignInAccount googleUser;
  const CompleteRegistrationScreen({Key? key, required this.googleUser}) : super(key: key);

  @override
  ConsumerState<CompleteRegistrationScreen> createState() => _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState extends ConsumerState<CompleteRegistrationScreen> {
  final phoneController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeRegistration() async {
    final phone = phoneController.text.trim();
    final phoneError = Validators.validatePhone(phone);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phoneError), backgroundColor: CoopvestColors.error));
      return;
    }
    try {
      await ref.read(authProvider.notifier).register(email: widget.googleUser.email, password: '', name: widget.googleUser.displayName ?? 'User', phone: phone);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/register-step3', arguments: {'email': widget.googleUser.email, 'name': widget.googleUser.displayName ?? 'User', 'phone': phone});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e'), backgroundColor: CoopvestColors.error));
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
        title: Text('Complete Registration', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome, ${widget.googleUser.displayName ?? 'User'}!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 8),
              Text('Almost done! Please add your phone number to complete registration.', style: TextStyle(color: context.textSecondary)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: CoopvestColors.primary,
                      radius: 24,
                      backgroundImage: widget.googleUser.photoUrl != null ? NetworkImage(widget.googleUser.photoUrl!) : null,
                      child: widget.googleUser.photoUrl == null ? Text((widget.googleUser.displayName?[0] ?? 'U').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.googleUser.displayName ?? 'User', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                          Text(widget.googleUser.email, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppTextField(label: 'Phone Number', hint: '+234 801 234 5678', controller: phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Complete Registration', onPressed: _completeRegistration, width: double.infinity),
            ],
          ),
        ),
      ),
    );
  }
}
