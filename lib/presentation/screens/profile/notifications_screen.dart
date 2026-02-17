import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/widgets/common/cards.dart';

/// Notifications Settings Screen
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _transactionAlerts = true;
  bool _loanUpdates = true;
  bool _savingsUpdates = true;
  bool _promotionalOffers = false;
  bool _securityAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage your notification preferences', style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 24),

            // Channel Settings
            _buildSectionHeader('Notification Channels'),
            AppCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications,
                    title: 'Push Notifications',
                    subtitle: 'Receive notifications on your device',
                    value: _pushNotifications,
                    onChanged: (value) => setState(() => _pushNotifications = value),
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    icon: Icons.email,
                    title: 'Email Notifications',
                    subtitle: 'Receive notifications via email',
                    value: _emailNotifications,
                    onChanged: (value) => setState(() => _emailNotifications = value),
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    icon: Icons.sms,
                    title: 'SMS Notifications',
                    subtitle: 'Receive notifications via SMS',
                    value: _smsNotifications,
                    onChanged: (value) => setState(() => _smsNotifications = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notification Types
            _buildSectionHeader('Notification Types'),
            AppCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.receipt_long,
                    title: 'Transaction Alerts',
                    subtitle: 'Get notified about transactions',
                    value: _transactionAlerts,
                    onChanged: (value) => setState(() => _transactionAlerts = value),
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    icon: Icons.request_quote,
                    title: 'Loan Updates',
                    subtitle: 'Updates on your loan applications',
                    value: _loanUpdates,
                    onChanged: (value) => setState(() => _loanUpdates = value),
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    icon: Icons.savings,
                    title: 'Savings Updates',
                    subtitle: 'Updates on your savings goals',
                    value: _savingsUpdates,
                    onChanged: (value) => setState(() => _savingsUpdates = value),
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    icon: Icons.local_offer,
                    title: 'Promotional Offers',
                    subtitle: 'Special offers and promotions',
                    value: _promotionalOffers,
                    onChanged: (value) => setState(() => _promotionalOffers = value),
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    icon: Icons.security,
                    title: 'Security Alerts',
                    subtitle: 'Important security notifications',
                    value: _securityAlerts,
                    onChanged: (value) => setState(() => _securityAlerts = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification preferences saved'), backgroundColor: CoopvestColors.success),
                  );
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoopvestColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: CoopvestColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: CoopvestColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: CoopvestColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: CoopvestColors.primary,
      ),
    );
  }
}
