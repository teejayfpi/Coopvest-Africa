import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/announcement_models.dart';
import '../../../presentation/providers/announcement_provider.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/loading.dart';

/// Announcements Screen - View admin broadcasts
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(announcementProvider.notifier).loadAnnouncements(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Announcements'),
        elevation: 0,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(announcementProvider.notifier).markAllAsRead();
              },
              child: Text(
                'Mark All Read',
                style: TextStyle(color: CoopvestColors.primary),
              ),
            ),
        ],
      ),
      body: state.isLoading && state.announcements.isEmpty
          ? const LoadingWidget()
          : state.announcements.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(announcementProvider.notifier).refreshAnnouncements(),
                  color: CoopvestColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.announcements.length,
                    itemBuilder: (context, index) {
                      final announcement = state.announcements[index];
                      return _buildAnnouncementCard(announcement);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            color: context.textSecondary,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No Announcements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for updates from Coopvest',
            style: TextStyle(
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    final isUnread = !announcement.isRead;
    final isPinned = announcement.isPinned;
    final isExpired = announcement.isExpired;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: isExpired
            ? null
            : () {
                ref
                    .read(announcementProvider.notifier)
                    .markAsRead(announcement.id);
                _showAnnouncementDetail(announcement);
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor(announcement.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(announcement.type),
                        size: 14,
                        color: _getTypeColor(announcement.type),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        announcement.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getTypeColor(announcement.type),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: CoopvestColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isPinned)
                  Icon(
                    Icons.push_pin,
                    size: 16,
                    color: CoopvestColors.warning,
                  ),
                if (isExpired)
                  Text(
                    'Expired',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              announcement.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                color: isExpired ? context.textSecondary : context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            // Preview
            Text(
              announcement.content,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Date
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(announcement.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDetail(Announcement announcement) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.scaffoldBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getTypeColor(announcement.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(announcement.type),
                          size: 16,
                          color: _getTypeColor(announcement.type),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          announcement.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getTypeColor(announcement.type),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    announcement.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('EEEE, MMM dd, yyyy \'at\' h:mm a')
                            .format(announcement.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        announcement.content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CoopvestColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'important':
        return CoopvestColors.error;
      case 'loan':
        return CoopvestColors.primary;
      case 'contribution':
        return CoopvestColors.success;
      case 'event':
        return CoopvestColors.warning;
      default:
        return CoopvestColors.info;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'important':
        return Icons.warning_amber;
      case 'loan':
        return Icons.monetization_on;
      case 'contribution':
        return Icons.savings;
      case 'event':
        return Icons.event;
      default:
        return Icons.campaign;
    }
  }
}
