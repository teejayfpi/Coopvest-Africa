import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../kyc/kyc_employment_details_screen.dart';
import '../support/support_home_screen.dart';
import '../../providers/auth_provider.dart';

/// Profile & Settings Screen
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  // Mock user data
  final Map<String, dynamic> _user = {
    'name': 'John Doe',
    'email': 'johndoe@email.com',
    'phone': '+234 801 234 5678',
    'memberId': 'COOP-2024-001234',
    'joinedDate': 'January 2024',
    'isVerified': true,
  };

  final List<Map<String, dynamic>> _settingsSections = [
    {
      'title': 'Account',
      'items': [
        {'icon': Icons.person, 'label': 'Edit Profile', 'subtitle': 'Update your personal information'},
        {'icon': Icons.lock, 'label': 'Security', 'subtitle': 'PIN, Password & Biometrics'},
        {'icon': Icons.credit_card, 'label': 'Bank Accounts', 'subtitle': 'Manage linked bank accounts'},
      ],
    },
    {
      'title': 'Preferences',
      'items': [
        {'icon': Icons.notifications, 'label': 'Notifications', 'subtitle': 'Manage push & email alerts'},
        {'icon': Icons.language, 'label': 'Language', 'subtitle': 'English (US)'},
        {'icon': Icons.dark_mode, 'label': 'Dark Mode', 'subtitle': 'Coming soon', 'trailing': 'OFF'},
      ],
    },
    {
      'title': 'Support',
      'items': [
        {'icon': Icons.help, 'label': 'Help Center', 'subtitle': 'FAQs & Support'},
        {'icon': Icons.chat, 'label': 'Live Chat', 'subtitle': 'Chat with support team'},
        {'icon': Icons.policy, 'label': 'Privacy Policy', 'subtitle': 'View our policies'},
      ],
    },
    {
      'title': 'App',
      'items': [
        {'icon': Icons.star, 'label': 'Rate App', 'subtitle': 'Share your feedback'},
        {'icon': Icons.share, 'label': 'Share App', 'subtitle': 'Invite friends to Coopvest'},
        {'icon': Icons.info, 'label': 'About', 'subtitle': 'Version 1.0.0'},
      ],
    },
  ];

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CoopvestColors.darkGray),
          onPressed: _goBack,
        ),
        title: Text(
          'Profile & Settings',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              _buildProfileHeader(),
              const SizedBox(height: 32),

              // Settings Sections
              ..._settingsSections.map((section) => _buildSettingsSection(section)),

              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showLogoutDialog,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: CoopvestColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: CoopvestColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          // Profile Picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: CoopvestColors.primary,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: CoopvestColors.primary, width: 4),
            ),
            child: Center(
              child: Text(
                _user['name'].toString().substring(0, 2).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _user['name'] as String,
            style: CoopvestTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Member ID: ${_user['memberId']}',
                style: TextStyle(color: CoopvestColors.mediumGray),
              ),
              if (_user['isVerified'] as bool)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.verified, color: CoopvestColors.success, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CoopvestColors.success.withAlpha((255 * 0.1).toInt()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Verified Member',
              style: TextStyle(color: CoopvestColors.success, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(Map<String, dynamic> section) {
    final items = section['items'] as List<Map<String, dynamic>>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section['title'] as String,
          style: CoopvestTypography.titleSmall.copyWith(
            color: CoopvestColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _buildSettingsItem(item)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsItem(Map<String, dynamic> item) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(item['icon'] as IconData, color: CoopvestColors.primary),
        title: Text(
          item['label'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(item['subtitle'] as String),
        trailing: item['trailing'] != null
            ? Text(
                item['trailing'] as String,
                style: TextStyle(color: CoopvestColors.mediumGray),
              )
            : const Icon(Icons.chevron_right, color: CoopvestColors.lightGray),
        onTap: () {
          final label = item['label'] as String;
          switch (label) {
            case 'Edit Profile':
              // We can reuse employment details for editing profile info
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
            case 'Help Center':
            case 'Live Chat':
              Navigator.of(context).pushNamed('/support');
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
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout? You will need to login again to access your account.'),
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
