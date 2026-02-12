import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CoopvestColors.darkGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: CoopvestColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: CoopvestColors.darkGray,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['body'] as String,
                              style: TextStyle(
                                color: CoopvestColors.mediumGray,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['time'] as String,
                              style: TextStyle(
                                color: CoopvestColors.lightGray,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: CoopvestColors.lightGray,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: CoopvestColors.mediumGray,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
