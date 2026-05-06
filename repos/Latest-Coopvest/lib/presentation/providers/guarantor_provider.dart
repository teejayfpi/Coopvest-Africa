import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/guarantor_api_service.dart';
import '../../data/models/guarantor_models.dart';

/// Guarantor State
class GuarantorState {
  final List<GuarantorRequest> pendingRequests;
  final List<GuarantorRequest> allRequests;
  final List<GuaranteedLoan> myGuarantees;
  final GuarantorStats stats;
  final bool isLoading;
  final String? error;

  GuarantorState({
    this.pendingRequests = const [],
    this.allRequests = const [],
    this.myGuarantees = const [],
    GuarantorStats? stats,
    this.isLoading = false,
    this.error,
  }) : stats = stats ?? GuarantorStats(
      pendingRequests: 0,
      acceptedGuarantees: 0,
      declinedRequests: 0,
      totalGuaranteedAmount: 0,
    );

  GuarantorState copyWith({
    List<GuarantorRequest>? pendingRequests,
    List<GuarantorRequest>? allRequests,
    List<GuaranteedLoan>? myGuarantees,
    GuarantorStats? stats,
    bool? isLoading,
    String? error,
  }) {
    return GuarantorState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      allRequests: allRequests ?? this.allRequests,
      myGuarantees: myGuarantees ?? this.myGuarantees,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  // Getters
  int get pendingCount => pendingRequests.length;
  int get activeGuaranteesCount =>
      myGuarantees.where((g) => g.status == 'active').length;
}

/// Guarantor Provider
class GuarantorProvider extends StateNotifier<GuarantorState> {
  final GuarantorApiService _apiService = GuarantorApiService();

  GuarantorProvider() : super(GuarantorState());

  Future<void> loadPendingRequests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final requests = await _apiService.getPendingRequests();
      state = state.copyWith(
        pendingRequests: requests,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadAllRequests({String status = 'all'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final requests = await _apiService.getAllRequests(status: status);
      state = state.copyWith(
        allRequests: requests,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMyGuarantees() async {
    try {
      final guarantees = await _apiService.getMyGuarantees();
      state = state.copyWith(myGuarantees: guarantees);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadStats() async {
    try {
      final stats = await _apiService.getStats();
      state = state.copyWith(stats: stats);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        loadPendingRequests(),
        loadAllRequests(),
        loadMyGuarantees(),
        loadStats(),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> acceptRequest(String requestId) async {
    try {
      final success = await _apiService.acceptRequest(requestId);
      if (success) {
        await loadPendingRequests();
        await loadStats();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> declineRequest(String requestId, {String? reason}) async {
    try {
      final success = await _apiService.declineRequest(requestId, reason: reason);
      if (success) {
        await loadPendingRequests();
        await loadStats();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> withdraw(String guaranteeId) async {
    try {
      final success = await _apiService.withdraw(guaranteeId);
      if (success) {
        await loadMyGuarantees();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Guarantor Provider
final guarantorProvider =
    StateNotifierProvider<GuarantorProvider, GuarantorState>((ref) {
  return GuarantorProvider();
});

/// Selected Request Provider
final selectedRequestProvider = StateProvider<GuarantorRequest?>((ref) {
  return null;
});
