import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import '../../data/models/contributions/monthly_contribution.dart';
import '../../data/api/contributions/contribution_api_service.dart';

/// Contribution Repository Provider
final contributionRepositoryProvider = Provider<ContributionRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ContributionRepository(apiClient);
});

/// Contribution Repository
class ContributionRepository {
  final ApiClient _apiClient;
  late ContributionApiService _apiService;

  ContributionRepository(ApiClient apiClient) : _apiClient = apiClient {
    _apiService = ContributionApiService(apiClient.dio);
  }

  /// Get contributions list with pagination and filters
  Future<ContributionsListResponse> getContributions({
    int page = 1,
    int pageSize = 20,
    ContributionFilter? filter,
  }) async {
    try {
      return await _apiService.getContributions(
        page: page,
        pageSize: pageSize,
        filter: filter,
      );
    } catch (e) {
      logger.e('Get contributions error: $e');
      rethrow;
    }
  }

  /// Get contribution detail by ID
  Future<ContributionDetail> getContributionDetail(String contributionId) async {
    try {
      return await _apiService.getContributionDetail(contributionId);
    } catch (e) {
      logger.e('Get contribution detail error: $e');
      rethrow;
    }
  }

  /// Get contribution summary
  Future<ContributionSummary> getContributionSummary() async {
    try {
      return await _apiService.getContributionSummary();
    } catch (e) {
      logger.e('Get contribution summary error: $e');
      rethrow;
    }
  }

  /// Get contribution receipt
  Future<String> getContributionReceipt(String contributionId) async {
    try {
      return await _apiService.getContributionReceipt(contributionId);
    } catch (e) {
      logger.e('Get contribution receipt error: $e');
      rethrow;
    }
  }
}

/// Contribution loading states
enum ContributionStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Contribution State
class ContributionState {
  final ContributionStatus status;
  final List<MonthlyContribution> contributions;
  final ContributionSummary? summary;
  final ContributionDetail? selectedDetail;
  final ContributionFilter filter;
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
  final String? error;
  final bool isRefreshing;

  const ContributionState({
    this.status = ContributionStatus.initial,
    this.contributions = const [],
    this.summary,
    this.selectedDetail,
    this.filter = const ContributionFilter(),
    this.currentPage = 1,
    this.pageSize = 20,
    this.totalCount = 0,
    this.hasMore = false,
    this.error,
    this.isRefreshing = false,
  });

  bool get isLoading => status == ContributionStatus.loading;
  bool get isLoaded => status == ContributionStatus.loaded;

  ContributionState copyWith({
    ContributionStatus? status,
    List<MonthlyContribution>? contributions,
    ContributionSummary? summary,
    ContributionDetail? selectedDetail,
    ContributionFilter? filter,
    int? currentPage,
    int? pageSize,
    int? totalCount,
    bool? hasMore,
    String? error,
    bool? isRefreshing,
  }) {
    return ContributionState(
      status: status ?? this.status,
      contributions: contributions ?? this.contributions,
      summary: summary ?? this.summary,
      selectedDetail: selectedDetail ?? this.selectedDetail,
      filter: filter ?? this.filter,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  ContributionState resetPagination() {
    return copyWith(
      currentPage: 1,
      contributions: [],
      hasMore: false,
      totalCount: 0,
    );
  }
}

/// Contribution Notifier
class ContributionNotifier extends StateNotifier<ContributionState> {
  final ContributionRepository _repository;

  ContributionNotifier(this._repository) : super(const ContributionState());

  /// Load initial contributions and summary
  Future<void> loadContributions() async {
    state = state.copyWith(status: ContributionStatus.loading, error: null);
    try {
      final filter = state.filter;
      final response = await _repository.getContributions(
        page: 1,
        pageSize: state.pageSize,
        filter: filter,
      );
      final summary = await _repository.getContributionSummary();

      state = state.copyWith(
        status: ContributionStatus.loaded,
        contributions: response.contributions,
        summary: summary,
        currentPage: response.page,
        totalCount: response.totalCount,
        hasMore: response.hasMore,
      );
    } catch (e) {
      logger.e('Load contributions error: $e');
      state = state.copyWith(
        status: ContributionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Load more contributions (pagination)
  Future<void> loadMoreContributions() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(status: ContributionStatus.loading);
    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getContributions(
        page: nextPage,
        pageSize: state.pageSize,
        filter: state.filter,
      );

      state = state.copyWith(
        status: ContributionStatus.loaded,
        contributions: [...state.contributions, ...response.contributions],
        currentPage: response.page,
        totalCount: response.totalCount,
        hasMore: response.hasMore,
      );
    } catch (e) {
      logger.e('Load more contributions error: $e');
      state = state.copyWith(status: ContributionStatus.loaded);
    }
  }

  /// Refresh contributions
  Future<void> refreshContributions() async {
    state = state.copyWith(isRefreshing: true, error: null);
    try {
      final filter = state.filter;
      final response = await _repository.getContributions(
        page: 1,
        pageSize: state.pageSize,
        filter: filter,
      );
      final summary = await _repository.getContributionSummary();

      state = state.copyWith(
        status: ContributionStatus.loaded,
        contributions: response.contributions,
        summary: summary,
        currentPage: response.page,
        totalCount: response.totalCount,
        hasMore: response.hasMore,
        isRefreshing: false,
      );
    } catch (e) {
      logger.e('Refresh contributions error: $e');
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString(),
      );
    }
  }

  /// Apply filter and reload
  Future<void> applyFilter(ContributionFilter filter) async {
    state = state.copyWith(filter: filter).resetPagination();
    await loadContributions();
  }

  /// Quick filter - This Month
  Future<void> filterThisMonth() async {
    await applyFilter(ContributionFilter().thisMonth());
  }

  /// Quick filter - Last 3 Months
  Future<void> filterLast3Months() async {
    await applyFilter(ContributionFilter().last3Months());
  }

  /// Quick filter - Last 6 Months
  Future<void> filterLast6Months() async {
    await applyFilter(ContributionFilter().last6Months());
  }

  /// Quick filter - This Year
  Future<void> filterThisYear() async {
    await applyFilter(ContributionFilter().thisYear());
  }

  /// Quick filter - All Time
  Future<void> filterAllTime() async {
    await applyFilter(ContributionFilter().allTime());
  }

  /// Load contribution detail
  Future<void> loadContributionDetail(String contributionId) async {
    state = state.copyWith(selectedDetail: null);
    try {
      final detail = await _repository.getContributionDetail(contributionId);
      state = state.copyWith(selectedDetail: detail);
    } catch (e) {
      logger.e('Load contribution detail error: $e');
      rethrow;
    }
  }

  /// Clear selected detail
  void clearSelectedDetail() {
    state = state.copyWith(selectedDetail: null);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Retry loading
  Future<void> retry() async {
    await loadContributions();
  }
}

/// Contribution Provider
final contributionProvider =
    StateNotifierProvider<ContributionNotifier, ContributionState>((ref) {
  final repository = ref.watch(contributionRepositoryProvider);
  return ContributionNotifier(repository);
});

/// Summary provider
final contributionSummaryProvider = Provider<ContributionSummary?>((ref) {
  final state = ref.watch(contributionProvider);
  return state.summary;
});

/// Contributions list provider
final contributionsListProvider =
    Provider<List<MonthlyContribution>>((ref) {
  final state = ref.watch(contributionProvider);
  return state.contributions;
});

/// Selected contribution detail provider
final selectedContributionDetailProvider =
    Provider<ContributionDetail?>((ref) {
  final state = ref.watch(contributionProvider);
  return state.selectedDetail;
});

/// Loading state provider
final contributionLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(contributionProvider);
  return state.isLoading;
});

/// Error provider
final contributionErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(contributionProvider);
  return state.error;
});

/// Has more provider
final contributionHasMoreProvider = Provider<bool>((ref) {
  final state = ref.watch(contributionProvider);
  return state.hasMore;
});

/// Current filter provider
final contributionFilterProvider = Provider<ContributionFilter>((ref) {
  final state = ref.watch(contributionProvider);
  return state.filter;
});
