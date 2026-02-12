import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../config/theme_config.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../kyc/kyc_employment_details_screen.dart';
import '../support/support_home_screen.dart';
import '../security/security_settings_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Profile & Settings Screen
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  File? _profileImage;
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _settingsItems = [
    {
      'title': 'Account',
      'items': [
        {
          'icon': Icons.person_outline,
          'label': 'Edit Profile',
          'subtitle': 'Personal information, contact details',
        },
        {
          'icon': Icons.security_outlined,
          'label': 'Security',
          'subtitle': 'Password, PIN, Biometrics',
        },
        {
          'icon': Icons.account_balance_outlined,
          'label': 'Bank Accounts',
          'subtitle': 'Manage your linked bank accounts',
        },
      ],
    },
    {
      'title': 'Preferences',
      'items': [
        {
          'icon': Icons.notifications_none_outlined,
          'label': 'Notifications',
          'subtitle': 'Push notifications, email alerts',
        },
        {
          'icon': Icons.dark_mode_outlined,
          'label': 'Dark Mode',
          'subtitle': 'Switch between light and dark themes',
        },
      ],
    },
    {
      'title': 'Support',
      'items': [
        {
          'icon': Icons.help_outline,
          'label': 'Help Center',
          'subtitle': 'FAQs, user guides',
        },
        {
          'icon': Icons.chat_bubble_outline,
          'label': 'Live Chat',
          'subtitle': 'Talk to our support team',
        },
      ],
    },
    {
      'title': 'About',
      'items': [
        {
          'icon': Icons.share_outlined,
          'label': 'Share App',
          'subtitle': 'Invite friends to Coopvest',
        },
        {
          'icon': Icons.policy_outlined,
          'label': 'Privacy Policy',
          'subtitle': 'Terms of service, privacy',
        },
        {
          'icon': Icons.info_outline,
          'label': 'About',
          'subtitle': 'App version, company info',
          'trailing': 'v1.0.0',
        },
      ],
    },
  ];

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: CoopvestColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CoopvestColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Change Profile Picture',
              style: CoopvestTypography.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CoopvestColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: CoopvestColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: CoopvestTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 32),
            
            // Settings Sections
            ..._settingsItems.map((section) => _buildSettingsSection(section)),
            
            const SizedBox(height: 32),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CoopvestColors.error,
                  side: const BorderSide(color: CoopvestColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Logout'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _isLoading ? null : _showImageSourceDialog,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CoopvestColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: CoopvestColors.veryLightGray,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(Icons.person, size: 60, color: CoopvestColors.mediumGray)
                      : null,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _isLoading ? null : _showImageSourceDialog,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CoopvestColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 3,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'User Name',
          style: CoopvestTypography.headlineLarge,
        ),
        const Text(
          'user@example.com',
          style: CoopvestTypography.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _showImageSourceDialog,
          child: const Text('Change Profile Picture'),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(Map<String, dynamic> section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            section['title'] as String,
            style: CoopvestTypography.titleMedium.copyWith(
              color: CoopvestColors.primary,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...(section['items'] as List).asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == (section['items'] as List).length - 1;
                
                return Column(
                  children: [
                    _buildSettingsItem(item),
                    if (!isLast)
                      const Divider(height: 1, indent: 56),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsItem(Map<String, dynamic> item) {
    return ListTile(
      leading: Icon(
        item['icon'] as IconData? ?? Icons.settings, 
        color: CoopvestColors.darkGray
      ),
      title: Text(
        item['label'] as String,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(item['subtitle'] as String),
      trailing: item['label'] == 'Dark Mode'
          ? Switch(
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
              activeColor: CoopvestColors.primary,
            )
          : (item['trailing'] != null
              ? Text(
                  item['trailing'] as String,
                  style: TextStyle(color: CoopvestColors.mediumGray),
                )
              : const Icon(Icons.chevron_right, color: CoopvestColors.lightGray)),
      onTap: () {
        final label = item['label'] as String;
        switch (label) {
          case 'Edit Profile':
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const KYCEmploymentDetailsScreen()),
            );
            break;
          case 'Security':
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
            );
            break;
          case 'Bank Accounts':
            Navigator.of(context).pushNamed('/kyc-bank-info');
            break;
          case 'Notifications':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification settings coming soon')),
            );
            break;
          case 'Dark Mode':
            ref.read(themeModeProvider.notifier).toggleTheme();
            break;
          case 'Help Center':
          case 'Live Chat':
            Navigator.of(context).pushNamed('/support');
            break;
          case 'Share App':
            Share.share('Check out Coopvest Africa! Save, Borrow, and Invest together. Download now at https://coopvestafrica.com');
            break;
          case 'Privacy Policy':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy Policy document opening...')),
            );
            break;
          case 'About':
            showAboutDialog(
              context: context,
              applicationName: 'Coopvest Africa',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.account_balance, color: CoopvestColors.primary),
              children: const [
                Text('Coopvest Africa is a cooperative financial platform for savings, loans, and investments.'),
              ],
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label feature coming soon')),
            );
        }
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(authProvider.notifier).logout();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e'), backgroundColor: CoopvestColors.error),
                  );
                }
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: CoopvestColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
