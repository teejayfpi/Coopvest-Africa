import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/guarantor_models.dart';

/// API Service for Guarantor Management - Track pending guarantor requests
class GuarantorApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get all pending guarantor requests for the user
  Future<List<GuarantorRequest>> getPendingRequests() async {
    try {
      final response = await _apiClient.dio.get(
        '/guarantor/pending-requests',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['requests'] ?? [];
        return data.map((json) => GuarantorRequest.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch pending requests');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch pending requests');
    }
  }

  /// Get all guarantor requests (all statuses)
  Future<List<GuarantorRequest>> getAllRequests({String status = 'all'}) async {
    try {
      final response = await _apiClient.dio.get(
        '/guarantor/requests',
        queryParameters: {'status': status},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['requests'] ?? [];
        return data.map((json) => GuarantorRequest.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch requests');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch requests');
    }
  }

  /// Get a single guarantor request by ID
  Future<GuarantorRequest> getRequest(String requestId) async {
    try {
      final response = await _apiClient.dio.get(
        '/guarantor/requests/$requestId',
      );

      if (response.statusCode == 200) {
        return GuarantorRequest.fromJson(response.data);
      }
      throw Exception('Failed to fetch request');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch request');
    }
  }

  /// Accept a guarantor request
  Future<bool> acceptRequest(String requestId) async {
    try {
      final response = await _apiClient.dio.post(
        '/guarantor/requests/$requestId/accept',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to accept request');
    }
  }

  /// Decline a guarantor request
  Future<bool> declineRequest(String requestId, {String? reason}) async {
    try {
      final response = await _apiClient.dio.post(
        '/guarantor/requests/$requestId/decline',
        data: {'reason': reason},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to decline request');
    }
  }

  /// Get loans where user is a guarantor
  Future<List<GuaranteedLoan>> getMyGuarantees() async {
    try {
      final response = await _apiClient.dio.get(
        '/guarantor/my-guarantees',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['guarantees'] ?? [];
        return data.map((json) => GuaranteedLoan.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch guarantees');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch guarantees');
    }
  }

  /// Get guarantor statistics
  Future<GuarantorStats> getStats() async {
    try {
      final response = await _apiClient.dio.get(
        '/guarantor/stats',
      );

      if (response.statusCode == 200) {
        return GuarantorStats.fromJson(response.data);
      }
      throw Exception('Failed to fetch stats');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch stats');
    }
  }

  /// Withdraw from a guarantor request (before loan is approved)
  Future<bool> withdraw(String guaranteeId) async {
    try {
      final response = await _apiClient.dio.post(
        '/guarantor/withdraw/$guaranteeId',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to withdraw');
    }
  }
}
