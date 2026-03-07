import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/logger_service.dart';
import '../../data/api/rollover_api_service.dart';
import '../../data/models/rollover_models.dart';
import '../../data/repositories/rollover_repository.dart';
import '../../data/repositories/auth_repository.dart';

/// Rollover Provider - State management for member-only rollover operations
///
/// NOTE: Admin operations (approvals, rejections) have been moved to the
/// dedicated admin web portal. This provider only handles member-facing
/// state management for rollover requests.
final rolloverProvider =
    StateNotifierProvider<RolloverNotifier, RolloverState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final rolloverApiService = ref.watch(rolloverApiServiceProvider);
  return RolloverNotifier(authRepository, rolloverApiService);
});

/// Rollover Notifier - Handles member-only rollover state changes
class RolloverNotifier extends StateNotifier<RolloverState> {
  final AuthRepository _authRepository;
  final RolloverApiService _apiService;
  final LoggerService _logger;

  RolloverNotifier(this._authRepository, this._apiService)
      : _logger = LoggerService(),
        super(const RolloverState());

  // ============== Eligibility Check ==============

  /// Check if a loan is eligible for rollover
  Future<RolloverEligibility?> checkEligibility({
    required String loanId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).checkEligibility(loanId: loanId);

      if (result.success && result.data != null) {
        state = state.copyWith(
          eligibility: result.data!,
          isLoading: false,
        );
        return result.data;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to check eligibility',
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

  // ============== Rollover Request ==============

  /// Create a new rollover request
  Future<bool> createRolloverRequest({
    required String loanId,
    required int newTenure,
    required List<GuarantorInfo> guarantors,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).createRolloverRequest(
        loanId: loanId,
        newTenure: newTenure,
        guarantors: guarantors,
      );

      if (result.success && result.data != null) {
        state = state.copyWith(
          currentRollover: result.data!,
          status: RolloverStatus.pending,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to create rollover request',
          isLoading: false,
        );
        return false;
      }
    } catch (e) {
      _logger.error('Create rollover request error: $e');
      state = state.copyWith(
        error: 'Error creating rollover request: $e',
        isLoading: false,
      );
      return false;
    }
  }

  // ============== Rollover Details ==============

  /// Get rollover details
  Future<LoanRollover?> getRolloverDetails({
    required String rolloverId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).getRolloverDetails(rolloverId: rolloverId);

      if (result.success && result.data != null) {
        state = state.copyWith(
          currentRollover: result.data!,
          status: result.data!.status,
          isLoading: false,
        );
        return result.data;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to fetch rollover details',
          isLoading: false,
        );
        return null;
      }
    } catch (e) {
      _logger.error('Get rollover details error: $e');
      state = state.copyWith(
        error: 'Error fetching rollover details: $e',
        isLoading: false,
      );
      return null;
    }
  }

  /// Get all rollovers for the current member
  Future<List<LoanRollover>> getMemberRollovers() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).getMemberRollovers();

      if (result.success && result.data != null) {
        state = state.copyWith(
          rolloverHistory: result.data!,
          isLoading: false,
        );
        return result.data!;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to fetch rollovers',
          isLoading: false,
        );
        return [];
      }
    } catch (e) {
      _logger.error('Get member rollovers error: $e');
      state = state.copyWith(
        error: 'Error fetching rollovers: $e',
        isLoading: false,
      );
      return [];
    }
  }

  // ============== Guarantor Operations ==============

  /// Get guarantors for a rollover
  Future<List<RolloverGuarantor>> getRolloverGuarantors({
    required String rolloverId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).getRolloverGuarantors(rolloverId: rolloverId);

      if (result.success && result.data != null) {
        state = state.copyWith(
          guarantors: result.data!,
          isLoading: false,
        );
        return result.data!;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to fetch guarantors',
          isLoading: false,
        );
        return [];
      }
    } catch (e) {
      _logger.error('Get rollover guarantors error: $e');
      state = state.copyWith(
        error: 'Error fetching guarantors: $e',
        isLoading: false,
      );
      return [];
    }
  }

  /// Guarantor responds to rollover consent request
  Future<bool> guarantorRespond({
    required String rolloverId,
    required String guarantorId,
    required bool accepted,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).guarantorRespond(
        rolloverId: rolloverId,
        guarantorId: guarantorId,
        accepted: accepted,
        reason: reason,
      );

      if (result.success) {
        // Refresh guarantors list
        await getRolloverGuarantors(rolloverId: rolloverId);
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to process guarantor response',
          isLoading: false,
        );
        return false;
      }
    } catch (e) {
      _logger.error('Guarantor respond error: $e');
      state = state.copyWith(
        error: 'Error processing response: $e',
        isLoading: false,
      );
      return false;
    }
  }

  /// Replace a guarantor who declined
  Future<bool> replaceGuarantor({
    required String rolloverId,
    required String oldGuarantorId,
    required String newGuarantorId,
    required String newGuarantorName,
    required String newGuarantorPhone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).replaceGuarantor(
        rolloverId: rolloverId,
        oldGuarantorId: oldGuarantorId,
        newGuarantorId: newGuarantorId,
        newGuarantorName: newGuarantorName,
        newGuarantorPhone: newGuarantorPhone,
      );

      if (result.success) {
        // Refresh guarantors list
        await getRolloverGuarantors(rolloverId: rolloverId);
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to replace guarantor',
          isLoading: false,
        );
        return false;
      }
    } catch (e) {
      _logger.error('Replace guarantor error: $e');
      state = state.copyWith(
        error: 'Error replacing guarantor: $e',
        isLoading: false,
      );
      return false;
    }
  }

  // ============== Member Operations ==============

  /// Member cancels rollover request
  Future<bool> cancelRollover({
    required String rolloverId,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await RolloverRepository(
        apiService: _apiService,
        authRepository: _authRepository,
      ).cancelRollover(rolloverId: rolloverId, reason: reason);

      if (result.success && result.data != null) {
        state = state.copyWith(
          currentRollover: result.data,
          status: RolloverStatus.cancelled,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          error: result.error ?? 'Failed to cancel rollover',
          isLoading: false,
        );
        return false;
      }
    } catch (e) {
      _logger.error('Cancel rollover error: $e');
      state = state.copyWith(
        error: 'Error cancelling rollover: $e',
        isLoading: false,
      );
      return false;
    }
  }

  // ============== Validation Helpers ==============

  /// Check if rollover is eligible for member
  bool isRolloverEligible() {
    final eligibility = state.eligibility;
    if (eligibility == null) return false;
    return eligibility.isEligible;
  }

  /// Check if all guarantors have consented
  bool allGuarantorsConsented() {
    return state.guarantors
        .every((g) => g.status == GuarantorConsentStatus.accepted);
  }

  /// Check if any guarantor declined
  bool hasGuarantorDeclined() {
    return state.guarantors
        .any((g) => g.status == GuarantorConsentStatus.declined);
  }

  /// Get declined guarantors that need replacement
  List<RolloverGuarantor> getDeclinedGuarantors() {
    return state.guarantors
        .where((g) => g.status == GuarantorConsentStatus.declined)
        .toList();
  }

  /// Get pending guarantors
  List<RolloverGuarantor> getPendingGuarantors() {
    return state.guarantors
        .where((g) =>
            g.status == GuarantorConsentStatus.pending ||
            g.status == GuarantorConsentStatus.invited)
        .toList();
  }

  /// Get accepted guarantors count
  int getAcceptedGuarantorsCount() {
    return state.guarantors
        .where((g) => g.status == GuarantorConsentStatus.accepted)
        .length;
  }

  /// Add a new guarantor to the rollover request
  void addGuarantor(GuarantorInfo guarantor) {
    final RolloverGuarantor rolloverGuarantor = RolloverGuarantor(
      id: '',
      rolloverId: '',
      guarantorId: guarantor.guarantorId,
      guarantorName: guarantor.guarantorName,
      guarantorPhone: guarantor.guarantorPhone,
      status: GuarantorConsentStatus.pending,
      declineReason: null,
      invitedAt: null,
      respondedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final updated = [...state.guarantors, rolloverGuarantor];
    state = state.copyWith(guarantors: updated);
  }

  /// Remove a guarantor from the rollover request
  void removeGuarantor(String guarantorId) {
    final updated = state.guarantors
        .where((g) => g.guarantorId != guarantorId)
        .toList();
    state = state.copyWith(guarantors: updated);
  }

  // ============== State Management ==============

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset state
  void reset() {
    state = const RolloverState();
  }

  /// Set current rollover
  void setCurrentRollover(LoanRollover rollover) {
    state = state.copyWith(
      currentRollover: rollover,
      status: rollover.status,
    );
  }

  /// Set eligibility
  void setEligibility(RolloverEligibility eligibility) {
    state = state.copyWith(eligibility: eligibility);
  }
}
