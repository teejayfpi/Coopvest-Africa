import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/inputs.dart';
import '../../../data/models/auth_models.dart';

const String _bioEmailKey = 'biometric_email';
const String _bioPasswordKey = 'biometric_password';

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
  bool _biometricAvailable = false;
  bool _biometricCredentialsSaved = false;
  bool _biometricLoading = false;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final hasCredentials = await _secureStorage.read(key: _bioEmailKey) != null;
      if (mounted) {
        setState(() {
          _biometricAvailable = canAuth && isDeviceSupported;
          _biometricCredentialsSaved = hasCredentials;
        });
      }
    } catch (_) {}
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
      await ref.read(authProvider.notifier).login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Save credentials for future biometric use
      await _secureStorage.write(key: _bioEmailKey, value: _emailController.text);
      await _secureStorage.write(key: _bioPasswordKey, value: _passwordController.text);
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: CoopvestColors.error),
        );
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() => _biometricLoading = true);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Use your fingerprint to sign in to Coopvest',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!authenticated) {
        setState(() => _biometricLoading = false);
        return;
      }

      final email = await _secureStorage.read(key: _bioEmailKey);
      final password = await _secureStorage.read(key: _bioPasswordKey);

      if (email == null || password == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No saved credentials found. Please sign in with your password first.'),
              backgroundColor: CoopvestColors.warning,
            ),
          );
        }
        setState(() => _biometricLoading = false);
        return;
      }

      await ref.read(authProvider.notifier).login(email: email, password: password);
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric error: ${e.message}'), backgroundColor: CoopvestColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: CoopvestColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final showBiometric = _biometricAvailable && _biometricCredentialsSaved;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(elevation: 0, automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to your Coopvest account',
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 32),

              AppTextField(
                label: 'Email or Phone Number',
                hint: 'Enter your email or phone',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: context.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/forgot-password'),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Log In',
                onPressed: _validateAndLogin,
                isLoading: isLoading,
                width: double.infinity,
              ),

              if (showBiometric) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: context.dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: context.dividerColor)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _biometricLoading || isLoading ? null : _authenticateWithBiometrics,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: CoopvestColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _biometricLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(CoopvestColors.primary),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint, color: CoopvestColors.primary, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'Sign in with Fingerprint',
                                style: TextStyle(
                                  color: CoopvestColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Don\'t have an account? ', style: TextStyle(color: context.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/register'),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
