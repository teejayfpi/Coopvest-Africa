import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../kyc/kyc_employment_details_screen.dart';
import '../support/support_home_screen.dart';
import '../security/security_settings_screen.dart';
import '../membership/membership_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'edit_profile_screen.dart';
import 'bank_accounts_screen.dart';
import 'notifications_screen.dart';
import '../transactions/statement_download_screen.dart';

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
          'icon': Icons.account_balance_outlined,
          'label': 'Membership',
          'subtitle': 'View status, request termination',
        },
        {
          'icon': Icons.download_outlined,
          'label': 'Download Statement',
          'subtitle': 'Get PDF statements with date range',
        },
        {
          'icon': Icons.security_outlined,
          'label': 'Security',
          'subtitle': 'Password, PIN, Biometrics',
        },
        {
          'icon': Icons.account_balance_wallet_outlined,
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
          color: context.scaffoldBackground,
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
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Profile Picture',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
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
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(context),
            const SizedBox(height: 32),
            
            // Settings Sections
            ..._settingsItems.map((section) => _buildSettingsSection(section, context)),
            
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

  Widget _buildProfileHeader(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

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
                  backgroundColor: context.secondaryCardBackground,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(Icons.person, size: 60, color: context.textSecondary)
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
                      color: context.scaffoldBackground,
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
                      : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user?.name ?? 'Ayanlowo',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? 'ayanlowo@example.com',
          style: TextStyle(color: context.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(Map<String, dynamic> section, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 24, bottom: 12),
          child: Text(
            section['title'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: CoopvestColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: (section['items'] as List).map((item) {
              final isLast = (section['items'] as List).indexOf(item) == (section['items'] as List).length - 1;
              return _buildSettingsTile(item as Map<String, dynamic>, !isLast, context);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(Map<String, dynamic> item, bool showDivider, BuildContext context) {
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Column(
      children: [
        ListTile(
          onTap: () => _handleSettingsTap(item['label'] as String),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CoopvestColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item['icon'] as IconData, color: CoopvestColors.primary, size: 20),
          ),
          title: Text(
            item['label'] as String,
            style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
          ),
          subtitle: Text(
            item['subtitle'] as String,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          trailing: item['label'] == 'Dark Mode'
              ? Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).toggleTheme();
                  },
                  activeColor: CoopvestColors.primary,
                )
              : (item['trailing'] != null
                  ? Text(item['trailing'] as String, style: TextStyle(color: context.textSecondary))
                  : Icon(Icons.chevron_right, color: context.textSecondary, size: 20)),
        ),
        if (showDivider)
          Divider(height: 1, indent: 56, color: context.dividerColor),
      ],
    );
  }

  void _handleSettingsTap(String label) {
    switch (label) {
      case 'Edit Profile':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        );
        break;
      case 'Membership':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const MembershipScreen()),
        );
        break;
      case 'Download Statement':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const StatementDownloadScreen()),
        );
        break;
      case 'Bank Accounts':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const BankAccountsScreen()),
        );
        break;
      case 'Notifications':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
        );
        break;
      case 'Privacy Policy':
        _showPrivacyPolicyDialog();
        break;
      case 'About':
        _showAboutDialog();
        break;
      case 'Security':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
        );
        break;
      case 'Help Center':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SupportHomeScreen()),
        );
        break;
      case 'Share App':
        Share.share('Check out Coopvest Africa - The best cooperative platform!');
        break;
      default:
        // Handle other taps
        break;
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Text('Privacy Policy', style: TextStyle(color: context.textPrimary)),
        content: SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
            'Last updated: January 2025\n\n'
            'Coopvest Africa ("we", "our", or "us") is committed to protecting your privacy. '
            'This Privacy Policy explains how your personal information is collected, used, and disclosed by Coopvest Africa.\n\n'
            'Information We Collect:\n'
            '- Personal identification information (Name, email, phone number)\n'
            '- Financial information for cooperative services\n'
            '- Transaction history\n'
            '- Device information and usage data\n\n'
            'How We Use Your Information:\n'
            '- To provide and maintain our cooperative services\n'
            '- To process transactions and send related information\n'
            '- To send promotional communications (with your consent)\n'
            '- To detect, prevent, and address technical issues\n\n'
            'Data Protection:\n'
            'We implement appropriate security measures to protect your personal information.\n\n'
            'Contact Us:\n'
            'If you have questions about this Privacy Policy, please contact us at support@coopvest.com',
            style: TextStyle(color: context.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Could open URL to full privacy policy
            },
            child: const Text('Full Policy', style: TextStyle(color: CoopvestColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Row(
          children: [
            const Text('About '),
            Text('Coopvest Africa', style: TextStyle(color: CoopvestColors.primary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CoopvestColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.savings, size: 40, color: CoopvestColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Coopvest Africa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Version 1.0.0', style: TextStyle(color: context.textSecondary)),
              const SizedBox(height: 16),
              Text(
                'Empowering cooperatives through digital innovation. Save, borrow, and invest together.',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAboutButton(Icons.language, 'Website'),
                  const SizedBox(width: 16),
                  _buildAboutButton(Icons.email, 'Contact'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        // Handle website or contact tap
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: CoopvestColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: CoopvestColors.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: CoopvestColors.primary)),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Text('Logout', style: TextStyle(color: context.textPrimary)),
        content: Text('Are you sure you want to logout?', style: TextStyle(color: context.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
            },
            child: const Text('Logout', style: TextStyle(color: CoopvestColors.error)),
          ),
        ],
      ),
    );
  }
}