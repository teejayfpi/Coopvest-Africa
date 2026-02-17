import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import '../models/termination_models.dart';
import '../api/termination_api_service.dart';

/// Termination Repository Provider
final terminationRepositoryProvider = Provider<TerminationRepository>((ref) {
  final apiService = ref.watch(terminationApiServiceProvider);
  return TerminationRepository(apiService);
});

/// Termination Repository
/// Handles termination-related API calls
class TerminationRepository {
  final TerminationApiService _apiService;

  TerminationRepository(this._apiService);

  /// Check if user is eligible for termination
  /// All financial validations are performed by the backend
  Future<TerminationEligibility?> checkEligibility() async {
    try {
      final response = await _apiService.checkEligibility();
      if (response.success && response.eligibility != null) {
        return response.eligibility;
      }
      return null;
    } catch (e) {
      logger.e('Check termination eligibility error: $e');
      rethrow;
    }
  }

  /// Submit a termination request
  /// Backend performs validation before accepting
  Future<TerminationRequest?> submitTerminationRequest({
    required TerminationFormData formData,
  }) async {
    try {
      final response = await _apiService.submitRequest(formData);
      if (response.success && response.request != null) {
        return response.request;
      }
      return null;
    } catch (e) {
      logger.e('Submit termination request error: $e');
      rethrow;
    }
  }

  /// Get current termination request status
  Future<TerminationRequest?> getCurrentRequest() async {
    try {
      final response = await _apiService.getCurrentRequest();
      if (response.success && response.request != null) {
        return response.request;
      }
      return null;
    } catch (e) {
      logger.e('Get current termination request error: $e');
      rethrow;
    }
  }

  /// Get termination request history
  Future<List<TerminationRequest>> getRequestHistory() async {
    try {
      final response = await _apiService.getRequestHistory();
      if (response.success) {
        return response.requests;
      }
      return [];
    } catch (e) {
      logger.e('Get termination history error: $e');
      rethrow;
    }
  }

  /// Cancel a pending termination request
  Future<bool> cancelRequest({required String requestId}) async {
    try {
      final response = await _apiService.cancelRequest(requestId);
      return response.success;
    } catch (e) {
      logger.e('Cancel termination request error: $e');
      rethrow;
    }
  }

  /// Confirm termination after admin approval
  /// This triggers account closure
  Future<bool> confirmTermination({required String requestId}) async {
    try {
      final response = await _apiService.confirmTermination(requestId);
      return response.success;
    } catch (e) {
      logger.e('Confirm termination error: $e');
      rethrow;
    }
  }
}
