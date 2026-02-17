import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../widgets/common/cards.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock notifications
    final List<Map<String, dynamic>> notifications = [
      {
        'title': 'Welcome to Coopvest Africa',
        'body': 'Thank you for joining our cooperative. Start your savings journey today!',
        'time': '2 hours ago',
        'icon': Icons.celebration,
        'color': CoopvestColors.primary,
      },
      {
        'title': 'KYC Verified',
        'body': 'Your identity verification has been approved. You can now apply for loans.',
        'time': '1 day ago',
        'icon': Icons.verified,
        'color': CoopvestColors.success,
      },
      {
        'title': 'New Loan Feature',
        'body': 'Check out our new loan rollover feature on the dashboard.',
        'time': '2 days ago',
        'icon': Icons.new_releases,
        'color': Colors.orange,
      },
    ];

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withAlpha((255 * 0.1).toInt()),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'] as IconData? ?? Icons.notifications,
                          color: item['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['body'] as String,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['time'] as String,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: context.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
