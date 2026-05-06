import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/termination_models.dart';

/// API Service for Membership Termination Operations
///
/// NOTE: All validations are performed by the backend system.
/// The mobile application acts only as a request interface.
class TerminationApiService {
  final Dio _dio;

  TerminationApiService(this._dio);

  /// Check if user is eligible for termination
  /// All financial validations are performed by the backend
  Future<TerminationEligibilityResponse> checkEligibility() async {
    try {
      final response = await _dio.get('/termination/eligibility');
      return TerminationEligibilityResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Submit a termination request
  /// Backend performs validation before accepting
  Future<TerminationSubmitResponse> submitRequest(
    TerminationFormData formData,
  ) async {
    try {
      final response = await _dio.post(
        '/termination/request',
        data: formData.toJson(),
      );
      return TerminationSubmitResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Get current termination request status
  Future<TerminationStatusResponse> getCurrentRequest() async {
    try {
      final response = await _dio.get('/termination/current');
      return TerminationStatusResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Get termination request history
  Future<TerminationHistoryResponse> getRequestHistory() async {
    try {
      final response = await _dio.get('/termination/history');
      return TerminationHistoryResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel a pending termination request
  Future<TerminationCancelResponse> cancelRequest(String requestId) async {
    try {
      final response = await _dio.post('/termination/$requestId/cancel');
      return TerminationCancelResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm termination after admin approval
  /// This is the final step that triggers account closure
  Future<TerminationConfirmResponse> confirmTermination(String requestId) async {
    try {
      final response = await _dio.post('/termination/$requestId/confirm');
      return TerminationConfirmResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}

/// Termination API Service Provider
final terminationApiServiceProvider = Provider<TerminationApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TerminationApiService(apiClient.dio);
});

// ============== Response Models ==============

class TerminationEligibilityResponse {
  final bool success;
  final String message;
  final TerminationEligibility? eligibility;

  TerminationEligibilityResponse({
    required this.success,
    required this.message,
    this.eligibility,
  });

  factory TerminationEligibilityResponse.fromJson(Map<String, dynamic> json) {
    return TerminationEligibilityResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      eligibility: json['eligibility'] != null
          ? TerminationEligibility.fromJson(json['eligibility'])
          : null,
    );
  }
}

class TerminationSubmitResponse {
  final bool success;
  final String message;
  final TerminationRequest? request;

  TerminationSubmitResponse({
    required this.success,
    required this.message,
    this.request,
  });

  factory TerminationSubmitResponse.fromJson(Map<String, dynamic> json) {
    return TerminationSubmitResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      request: json['request'] != null
          ? TerminationRequest.fromJson(json['request'])
          : null,
    );
  }
}

class TerminationStatusResponse {
  final bool success;
  final String message;
  final TerminationRequest? request;

  TerminationStatusResponse({
    required this.success,
    required this.message,
    this.request,
  });

  factory TerminationStatusResponse.fromJson(Map<String, dynamic> json) {
    return TerminationStatusResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      request: json['request'] != null
          ? TerminationRequest.fromJson(json['request'])
          : null,
    );
  }
}

class TerminationHistoryResponse {
  final bool success;
  final String message;
  final List<TerminationRequest> requests;

  TerminationHistoryResponse({
    required this.success,
    required this.message,
    required this.requests,
  });

  factory TerminationHistoryResponse.fromJson(Map<String, dynamic> json) {
    return TerminationHistoryResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      requests: (json['requests'] as List<dynamic>)
          .map((e) => TerminationRequest.fromJson(e))
          .toList(),
    );
  }
}

class TerminationCancelResponse {
  final bool success;
  final String message;

  TerminationCancelResponse({
    required this.success,
    required this.message,
  });

  factory TerminationCancelResponse.fromJson(Map<String, dynamic> json) {
    return TerminationCancelResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
    );
  }
}

class TerminationConfirmResponse {
  final bool success;
  final String message;

  TerminationConfirmResponse({
    required this.success,
    required this.message,
  });

  factory TerminationConfirmResponse.fromJson(Map<String, dynamic> json) {
    return TerminationConfirmResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
    );
  }
}
