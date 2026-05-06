import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';

/// Login History Screen - Shows where and when the account was accessed
class LoginHistoryScreen extends ConsumerWidget {
  const LoginHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock login history data - in production, this would come from an API
    final loginHistory = _getMockLoginHistory();

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Login History'),
        elevation: 0,
      ),
      body: loginHistory.isEmpty
          ? _buildEmptyState(context)
          : _buildLoginList(context, loginHistory),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: context.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No login history',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your login history will appear here',
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginList(BuildContext context, List<LoginRecord> records) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final isLast = index == records.length - 1;
        
        return Column(
          children: [
            _buildLoginItem(context, record),
            if (!isLast) const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildLoginItem(BuildContext context, LoginRecord record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Device icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getDeviceColor(record.deviceType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getDeviceIcon(record.deviceType),
                color: _getDeviceColor(record.deviceType),
              ),
            ),
            const SizedBox(width: 16),
            
            // Login details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        record.deviceName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      if (record.isCurrentSession) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: CoopvestColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 10,
                              color: CoopvestColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.location,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status indicator
            Icon(
              record.isSuccessful ? Icons.check_circle : Icons.error,
              color: record.isSuccessful ? CoopvestColors.success : CoopvestColors.error,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
        return Icons.phone_android;
      case 'tablet':
        return Icons.tablet_android;
      case 'desktop':
        return Icons.desktop_windows;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }

  Color _getDeviceColor(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
        return Colors.blue;
      case 'tablet':
        return Colors.purple;
      case 'desktop':
        return Colors.orange;
      case 'web':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  List<LoginRecord> _getMockLoginHistory() {
    return [
      LoginRecord(
        id: '1',
        deviceName: 'iPhone 14 Pro',
        deviceType: 'Mobile',
        location: 'Lagos, Nigeria',
        ipAddress: '102.88.XXX.XXX',
        date: DateTime.now().subtract(const Duration(hours: 1)),
        isSuccessful: true,
        isCurrentSession: true,
      ),
      LoginRecord(
        id: '2',
        deviceName: 'MacBook Pro',
        deviceType: 'Desktop',
        location: 'Lagos, Nigeria',
        ipAddress: '102.88.XXX.XXX',
        date: DateTime.now().subtract(const Duration(days: 1)),
        isSuccessful: true,
        isCurrentSession: false,
      ),
      LoginRecord(
        id: '3',
        deviceName: 'Samsung Galaxy S23',
        deviceType: 'Mobile',
        location: 'Abuja, Nigeria',
        ipAddress: '197.210.XXX.XXX',
        date: DateTime.now().subtract(const Duration(days: 3)),
        isSuccessful: true,
        isCurrentSession: false,
      ),
      LoginRecord(
        id: '4',
        deviceName: 'iPad Air',
        deviceType: 'Tablet',
        location: 'Lagos, Nigeria',
        ipAddress: '102.88.XXX.XXX',
        date: DateTime.now().subtract(const Duration(days: 5)),
        isSuccessful: false,
        isCurrentSession: false,
      ),
      LoginRecord(
        id: '5',
        deviceName: 'Chrome Browser',
        deviceType: 'Web',
        location: 'Lagos, Nigeria',
        ipAddress: '102.88.XXX.XXX',
        date: DateTime.now().subtract(const Duration(days: 7)),
        isSuccessful: true,
        isCurrentSession: false,
      ),
    ];
  }
}

class LoginRecord {
  final String id;
  final String deviceName;
  final String deviceType;
  final String location;
  final String ipAddress;
  final DateTime date;
  final bool isSuccessful;
  final bool isCurrentSession;

  LoginRecord({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.location,
    required this.ipAddress,
    required this.date,
    required this.isSuccessful,
    required this.isCurrentSession,
  });

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago at ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
