import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/announcement_api_service.dart';
import '../../data/models/announcement_models.dart';

/// Announcement Provider State
class AnnouncementState {
  final List<Announcement> announcements;
  final bool isLoading;
  final String? error;
  final int unreadCount;
  final bool hasMore;

  AnnouncementState({
    this.announcements = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
    this.hasMore = true,
  });

  AnnouncementState copyWith({
    List<Announcement>? announcements,
    bool? isLoading,
    String? error,
    int? unreadCount,
    bool? hasMore,
  }) {
    return AnnouncementState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Announcement Provider
class AnnouncementProvider extends StateNotifier<AnnouncementState> {
  final AnnouncementApiService _apiService = AnnouncementApiService();

  AnnouncementProvider() : super(AnnouncementState());

  Future<void> loadAnnouncements({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _apiService.getAnnouncements(
        page: refresh ? 1 : (state.announcements.length ~/ 20) + 1,
        limit: 20,
      );

      if (refresh) {
        state = state.copyWith(
          announcements: response.announcements,
          isLoading: false,
          unreadCount: response.unreadCount,
          hasMore: response.announcements.length >= 20,
        );
      } else {
        state = state.copyWith(
          announcements: [...state.announcements, ...response.announcements],
          isLoading: false,
          unreadCount: response.unreadCount,
          hasMore: response.announcements.length >= 20,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refreshAnnouncements() async {
    await loadAnnouncements(refresh: true);
  }

  Future<void> markAsRead(String announcementId) async {
    try {
      await _apiService.markAsRead(announcementId);
      state = state.copyWith(
        announcements: state.announcements.map((announcement) {
          if (announcement.id == announcementId) {
            return announcement.copyWith(isRead: true);
          }
          return announcement;
        }).toList() as List<Announcement>,
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
      );
    } catch (e) {
      // Silently fail for mark as read
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.markAllAsRead();
      state = state.copyWith(
        announcements: state.announcements.map((announcement) {
          return announcement.copyWith(isRead: true);
        }).toList() as List<Announcement>,
        unreadCount: 0,
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final count = await _apiService.getUnreadCount();
      state = state.copyWith(unreadCount: count);
      return count;
    } catch (e) {
      return state.unreadCount;
    }
  }
}

/// Announcement List Provider
final announcementProvider =
    StateNotifierProvider<AnnouncementProvider, AnnouncementState>((ref) {
  return AnnouncementProvider();
});

/// Selected Announcement Provider
final selectedAnnouncementProvider = StateProvider<Announcement?>((ref) {
  return null;
});
