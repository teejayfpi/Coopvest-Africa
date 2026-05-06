import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/logger_service.dart';
import '../../data/api/termination_api_service.dart';
import '../../data/models/termination_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/termination_repository.dart';

/// Termination Provider - State management for membership termination operations
///
/// NOTE: All validations are performed by the backend system.
/// The mobile application acts only as a request interface.
final terminationProvider =
    StateNotifierProvider<TerminationNotifier, TerminationState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final terminationRepository = ref.watch(terminationRepositoryProvider);
  return TerminationNotifier(authRepository, terminationRepository);
});

/// Termination Notifier - Handles termination state changes
class TerminationNotifier extends StateNotifier<TerminationState> {
  final AuthRepository _authRepository;
  final TerminationRepository _terminationRepository;
  final LoggerService _logger;

  TerminationNotifier(this._authRepository, this._terminationRepository)
      : _logger = LoggerService(),
        super(const TerminationState());

  // ============== Eligibility Check ==============

  /// Check if user is eligible for termination
  /// All financial validations are performed by the backend
  Future<TerminationEligibility?> checkEligibility() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _terminationRepository.checkEligibility();

      if (result != null) {
        state = state.copyWith(
          eligibility: result,
          isLoading: false,
        );
        return result;
      } else {
        state = state.copyWith(
          error: 'Failed to check eligibility',
          isLoading: false,
        );
        return null;
      }
    } catch (e) {
      _logger.error('Check eligibility error: $e');
      state = state.copyWith(
        error: 'Error checking eligibility: $e',
        isLoading: false,
      );
      return null;
    }
  }

  // ============== Submit Request ==============

  /// Submit a termination request
  /// Backend performs validation before accepting
  Future<bool> submitTerminationRequest({
    required TerminationFormData formData,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, formData: formData);

    try {
      final result =
          await _terminationRepository.submitTerminationRequest(
        formData: formData,
      );

      if (result != null) {
        state = state.copyWith(
          currentRequest: result,
          isSubmitting: false,
        );
        return true;
      } else {
        state = state.copyWith(
          error: 'Failed to submit termination request',
          isSubmitting: false,
        );
        return false;
      }
    } catch (e) {
      _logger.error('Submit termination request error: $e');
      state = state.copyWith(
        error: 'Error submitting request: $e',
        isSubmitting: false,
      );
      return false;
    }
  }

  // ============== Get Current Request ==============

  /// Get current termination request status
  Future<void> getCurrentRequest() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _terminationRepository.getCurrentRequest();

      state = state.copyWith(
        currentRequest: result,
        isLoading: false,
      );
    } catch (e) {
      _logger.error('Get current request error: $e');
      state = state.copyWith(
        error: 'Error fetching request: $e',
        isLoading: false,
      );
    }
  }

  // ============== Get Request History ==============

  /// Get termination request history
  Future<List<TerminationRequest>> getRequestHistory() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _terminationRepository.getRequestHistory();

      state = state.copyWith(
        requestHistory: result,
        isLoading: false,
      );
      return result;
    } catch (e) {
      _logger.error('Get request history error: $e');
      state = state.copyWith(
        error: 'Error fetching history: $e',
        isLoading: false,
      );
      return [];
    }
  }

  // ============== Cancel Request ==============

  /// Cancel a pending termination request
  Future<bool> cancelRequest({required String requestId}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _terminationRepository.cancelRequest(
        requestId: requestId,
      );

      if (result) {
        // Refresh current request status
        await getCurrentRequest();
      }

      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      _logger.error('Cancel request error: $e');
      state = state.copyWith(
        error: 'Error cancelling request: $e',
        isLoading: false,
      );
      return false;
    }
  }

  // ============== Confirm Termination ==============

  /// Confirm termination after admin approval
  /// This triggers account closure and logout
  Future<bool> confirmTermination({required String requestId}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _terminationRepository.confirmTermination(
        requestId: requestId,
      );

      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      _logger.error('Confirm termination error: $e');
      state = state.copyWith(
        error: 'Error confirming termination: $e',
        isLoading: false,
      );
      return false;
    }
  }

  // ============== Validation Helpers ==============

  /// Check if user is eligible for termination
  bool isEligible() {
    final eligibility = state.eligibility;
    if (eligibility == null) return false;
    return eligibility.isEligible;
  }

  /// Get list of eligibility errors
  List<String> getEligibilityErrors() {
    return state.eligibility?.eligibilityErrors ?? [];
  }

  /// Check if user has a pending request
  bool hasPendingRequest() {
    return state.currentRequest != null && state.currentRequest!.isPending;
  }

  /// Check if termination is confirmed
  bool isTerminated() {
    return state.currentRequest != null && state.currentRequest!.isEffective;
  }

  // ============== State Management ==============

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset state
  void reset() {
    state = const TerminationState();
  }

  /// Update form data
  void updateFormData(TerminationFormData formData) {
    state = state.copyWith(formData: formData);
  }

  /// Clear form data
  void clearFormData() {
    state = state.copyWith(formData: null);
  }
}

/// Termination Eligibility Provider
final terminationEligibilityProvider = Provider<TerminationEligibility?>((ref) {
  final terminationState = ref.watch(terminationProvider);
  return terminationState.eligibility;
});

/// Termination Current Request Provider
final terminationCurrentRequestProvider =
    Provider<TerminationRequest?>((ref) {
  final terminationState = ref.watch(terminationProvider);
  return terminationState.currentRequest;
});

/// Is Termination Eligible Provider
final isTerminationEligibleProvider = Provider<bool>((ref) {
  final eligibility = ref.watch(terminationEligibilityProvider);
  return eligibility?.isEligible ?? false;
});

/// Termination Loading Provider
final isTerminationLoadingProvider = Provider<bool>((ref) {
  final terminationState = ref.watch(terminationProvider);
  return terminationState.isLoading;
});

/// Termination Submitting Provider
final isTerminationSubmittingProvider = Provider<bool>((ref) {
  final terminationState = ref.watch(terminationProvider);
  return terminationState.isSubmitting;
});
