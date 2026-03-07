import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/announcement_models.dart';

/// API Service for Announcements - Admin broadcasts to all members
class AnnouncementApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get all announcements for the current user
  Future<AnnouncementsResponse> getAnnouncements({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/announcements',
        queryParameters: {
          'page': page,
          'limit': limit,
          'unreadOnly': unreadOnly,
        },
      );

      if (response.statusCode == 200) {
        return AnnouncementsResponse.fromJson(response.data);
      }
      throw Exception('Failed to fetch announcements');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch announcements');
    }
  }

  /// Get a single announcement by ID
  Future<Announcement> getAnnouncement(String id) async {
    try {
      final response = await _apiClient.dio.get(
        '/announcements/$id',
      );

      if (response.statusCode == 200) {
        return Announcement.fromJson(response.data);
      }
      throw Exception('Failed to fetch announcement');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch announcement');
    }
  }

  /// Mark an announcement as read
  Future<bool> markAsRead(String announcementId) async {
    try {
      final response = await _apiClient.dio.post(
        '/announcements/$announcementId/read',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to mark as read');
    }
  }

  /// Mark all announcements as read
  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiClient.dio.post(
        '/announcements/read-all',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to mark all as read');
    }
  }

  /// Get unread announcement count
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.dio.get(
        '/announcements/unread-count',
      );
      return response.data['count'] ?? 0;
    } on DioException catch (e) {
      return 0;
    }
  }

  /// Delete an announcement (admin only - not needed for members)
}
