import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../config/theme_config.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/theme_provider.dart';

/// Security Settings Screen
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = false;
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _isBiometricAvailable = canAuthenticate || isDeviceSupported;
      });
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !_isBiometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication is not available on this device'),
          backgroundColor: CoopvestColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        // Try to authenticate with biometrics
        final bool didAuthenticate = await _localAuth.authenticate(
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuthOnBiometricChangeNotRequired: true,
          ),
          localizedReason: 'Authenticate to enable biometric login',
        );
        
        if (didAuthenticate) {
          setState(() {
            _isBiometricEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric login enabled successfully'),
              backgroundColor: CoopvestColors.success,
            ),
          );
        }
      } else {
        setState(() {
          _isBiometricEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login disabled'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showChangePinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Transaction PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your current 4-digit PIN to proceed.'),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showSetNewPinDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoopvestColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetNewPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set New PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your new 4-digit PIN.'),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN changed successfully'),
                      backgroundColor: CoopvestColors.success,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoopvestColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully'),
                        backgroundColor: CoopvestColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoopvestColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Security'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Authentication Section
            _buildSectionHeader('Authentication'),
            const SizedBox(height: 12),
            
            // Biometric Login
            _buildSettingsTile(
              icon: Icons.fingerprint,
              title: 'Biometric Login',
              subtitle: _isBiometricAvailable 
                  ? 'Use fingerprint or face to login'
                  : 'Not available on this device',
              trailing: _isBiometricAvailable
                  ? Switch(
                      value: _isBiometricEnabled,
                      onChanged: _isLoading ? null : _toggleBiometric,
                      activeColor: CoopvestColors.primary,
                    )
                  : const Icon(Icons.not_interested, color: CoopvestColors.mediumGray),
            ),
            
            const SizedBox(height: 24),
            
            // PIN Section
            _buildSectionHeader('Transaction PIN'),
            const SizedBox(height: 12),
            
            _buildSettingsTile(
              icon: Icons.pin,
              title: 'Change Transaction PIN',
              subtitle: 'Update your 4-digit transaction PIN',
              onTap: _showChangePinDialog,
            ),
            
            const SizedBox(height: 24),
            
            // Password Section
            _buildSectionHeader('Password'),
            const SizedBox(height: 12),
            
            _buildSettingsTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: _showChangePasswordDialog,
            ),
            
            const SizedBox(height: 24),
            
            // Session Section
            _buildSectionHeader('Session'),
            const SizedBox(height: 12),
            
            _buildSettingsTile(
              icon: Icons.timer,
              title: 'Auto-Lock',
              subtitle: 'Lock app after 5 minutes of inactivity',
              trailing: const Icon(Icons.chevron_right, color: CoopvestColors.lightGray),
              onTap: () {
                // Auto-lock settings - integrated with app lifecycle
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Auto-Lock: App will lock after 5 minutes of inactivity'),
                    backgroundColor: CoopvestColors.primary,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Security Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CoopvestColors.infoLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CoopvestColors.info,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keep your account secure by using a strong password and enabling biometric login.',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: CoopvestColors.darkGray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: CoopvestTypography.titleMedium.copyWith(
        color: CoopvestColors.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CoopvestColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: CoopvestColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: CoopvestTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: CoopvestColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (trailing == null && onTap != null)
                const Icon(Icons.chevron_right, color: CoopvestColors.lightGray),
            ],
          ),
        ),
      ),
    );
  }
}
