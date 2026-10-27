import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';

/// Login History Screen - Shows where and when the account was accessed
class LoginHistoryScreen extends ConsumerStatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  ConsumerState<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends ConsumerState<LoginHistoryScreen> {
  late Future<List<LoginRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _load();
  }

  Future<List<LoginRecord>> _load() async {
    final response = await ref.read(apiClientProvider).get('/auth/login-history');
    final records = (response is Map && response['records'] is List)
        ? response['records'] as List
        : const [];
    return records
        .whereType<Map>()
        .map((e) => LoginRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  void _refresh() {
    setState(() {
      _historyFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Login History'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<LoginRecord>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildMessageState(
                context,
                icon: Icons.cloud_off,
                title: 'Could not load login history',
                subtitle: 'Pull down to try again.',
              );
            }
            final records = snapshot.data ?? const <LoginRecord>[];
            if (records.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildLoginList(context, records);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      // Keep the list scrollable so RefreshIndicator still works when empty.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        _buildMessageState(
          context,
          icon: Icons.history,
          title: 'No login history',
          subtitle: 'Your login history will appear here',
        ),
      ],
    );
  }

  Widget _buildMessageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: context.textSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: context.textSecondary)),
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
                color: _getDeviceColor(record.deviceType).withValues(alpha: 0.1),
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
                            color: CoopvestColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
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

  /// Parses one record from `GET /auth/login-history`.
  ///
  /// Every field is read defensively: a missing device, a null IP or an
  /// unparseable timestamp must not crash the screen. `date` falls back to
  /// `now` only as a last resort so the "x ago" label stays sane.
  factory LoginRecord.fromJson(Map<String, dynamic> json) {
    final rawDevice = (json['deviceName'] ?? json['device_type'] ?? '').toString();
    final rawType = (json['deviceType'] ?? '').toString();
    final parsedDate = DateTime.tryParse((json['date'] ?? '').toString());

    return LoginRecord(
      id: (json['id'] ?? '').toString(),
      deviceName: rawDevice.isEmpty ? 'Unknown device' : rawDevice,
      deviceType: rawType.isEmpty ? 'unknown' : rawType,
      location: (json['location'] ?? '').toString(),
      ipAddress: (json['ipAddress'] ?? '').toString(),
      date: parsedDate?.toLocal() ?? DateTime.now(),
      isSuccessful: json['isSuccessful'] == true,
      isCurrentSession: json['isCurrentSession'] == true,
    );
  }

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
