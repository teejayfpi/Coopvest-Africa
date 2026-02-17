import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';
import '../../../data/models/auth_models.dart';

/// Login Screen
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

  final LocalAuthentication _localAuth = LocalAuthentication();
  final GoogleSignIn _googleSignIn = GoogleSignIn(serverClientId: '1040576298736-991ja94slls4f6csarfheerlkg7bfpon.apps.googleusercontent.com');

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
      await ref.read(authProvider.notifier).login(email: _emailController.text, password: _passwordController.text);
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: CoopvestColors.error));
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
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e'), backgroundColor: CoopvestColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(elevation: 0, automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 8),
              Text('Log in to your Coopvest account', style: TextStyle(color: context.textSecondary)),
              const SizedBox(height: 32),
              AppTextField(label: 'Email or Phone Number', hint: 'Enter your email or phone', controller: _emailController, keyboardType: TextInputType.emailAddress, errorText: _emailError),
              const SizedBox(height: 20),
              AppTextField(label: 'Password', hint: 'Enter your password', controller: _passwordController, obscureText: _obscurePassword, errorText: _passwordError, suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: context.textSecondary), onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Log In', onPressed: _validateAndLogin, isLoading: isLoading, width: double.infinity),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: context.dividerColor)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: context.textSecondary, fontSize: 12))),
                  Expanded(child: Divider(color: context.dividerColor)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleGoogleSignIn,
                  icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg', height: 24, errorBuilder: (c, e, s) => const Icon(Icons.login)),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: context.dividerColor)),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Don\'t have an account? ', style: TextStyle(color: context.textSecondary)),
                  GestureDetector(onTap: () => Navigator.of(context).pushNamed('/register'), child: const Text('Sign Up', style: TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}