import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/providers/app_settings_provider.dart';

/// Notifications Settings Screen
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

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
            Text('Manage your notification preferences',
                style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 24),

            // Channel Settings
            _buildSectionHeader('Notification Channels'),
            AppCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    context: context,
                    icon: Icons.notifications,
                    title: 'Push Notifications',
                    subtitle: 'Receive notifications on your device',
                    value: settings.pushNotifications,
                    onChanged: notifier.setPushNotifications,
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    context: context,
                    icon: Icons.email,
                    title: 'Email Notifications',
                    subtitle: 'Receive notifications via email',
                    value: settings.emailNotifications,
                    onChanged: notifier.setEmailNotifications,
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    context: context,
                    icon: Icons.sms,
                    title: 'SMS Notifications',
                    subtitle: 'Receive notifications via SMS',
                    value: settings.smsNotifications,
                    onChanged: notifier.setSmsNotifications,
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
                    context: context,
                    icon: Icons.receipt_long,
                    title: 'Transaction Alerts',
                    subtitle: 'Get notified about transactions',
                    value: settings.transactionAlerts,
                    onChanged: notifier.setTransactionAlerts,
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    context: context,
                    icon: Icons.request_quote,
                    title: 'Loan Updates',
                    subtitle: 'Updates on your loan applications',
                    value: settings.loanUpdates,
                    onChanged: notifier.setLoanUpdates,
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    context: context,
                    icon: Icons.savings,
                    title: 'Savings Updates',
                    subtitle: 'Updates on your savings goals',
                    value: settings.savingsUpdates,
                    onChanged: notifier.setSavingsUpdates,
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    context: context,
                    icon: Icons.local_offer,
                    title: 'Promotional Offers',
                    subtitle: 'Special offers and promotions',
                    value: settings.promotionalOffers,
                    onChanged: notifier.setPromotionalOffers,
                  ),
                  Divider(height: 1, indent: 56, color: context.dividerColor),
                  _buildSwitchTile(
                    context: context,
                    icon: Icons.security,
                    title: 'Security Alerts',
                    subtitle: 'Important security notifications',
                    value: settings.securityAlerts,
                    onChanged: notifier.setSecurityAlerts,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirmation button — settings already auto-saved per toggle,
            // but we keep the button to match the expected UX flow.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification preferences saved'),
                      backgroundColor: CoopvestColors.success,
                    ),
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
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
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
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: context.textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: CoopvestColors.primary,
      ),
    );
  }
}
