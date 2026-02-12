import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../kyc/kyc_employment_details_screen.dart';
import '../support/support_home_screen.dart';
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
            const CircleAvatar(
              radius: 50,
              backgroundColor: CoopvestColors.veryLightGray,
              child: Icon(Icons.person, size: 50, color: CoopvestColors.mediumGray),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: CoopvestColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
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
      leading: Icon(item['icon'] as IconData, color: CoopvestColors.darkGray),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Security settings coming soon')),
            );
            break;
          case 'Bank Accounts':
            Navigator.of(context).pushNamed('/kyc-bank-info');
            break;
          case 'Notifications':
            Navigator.of(context).pushNamed('/notifications');
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
