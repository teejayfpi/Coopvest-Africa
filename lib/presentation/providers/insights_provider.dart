import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';

/// Insights Data Model
class InsightsData {
  final List<double> monthlyContributions;
  final List<String> months;
  final double totalContributions;
  final double averageContribution;
  final double highestContribution;
  final int contributionCount;

  const InsightsData({
    required this.monthlyContributions,
    required this.months,
    required this.totalContributions,
    required this.averageContribution,
    required this.highestContribution,
    required this.contributionCount,
  });

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    final contributions = (json['monthly_contributions'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final months = (json['months'] as List?)?.map((e) => e as String).toList() ??
        [];

    return InsightsData(
      monthlyContributions: contributions,
      months: months,
      totalContributions: (json['total_contributions'] as num?)?.toDouble() ?? 0.0,
      averageContribution: (json['average_contribution'] as num?)?.toDouble() ?? 0.0,
      highestContribution: (json['highest_contribution'] as num?)?.toDouble() ?? 0.0,
      contributionCount: json['contribution_count'] as int? ?? 0,
    );
  }
}

/// Insights Repository
class InsightsRepository {
  final ApiClient _apiClient;

  InsightsRepository(this._apiClient);

  /// Get insights data
  Future<InsightsData> getInsights({
    int months = 6,
  }) async {
    try {
      final response = await _apiClient.get(
        '/insights/contributions',
        queryParameters: {
          'months': months,
        },
      );

      return InsightsData.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Get insights error: $e');
      // Mock data for development
      return InsightsData(
        monthlyContributions: [20000, 40000, 30000, 50000, 45000, 70000],
        months: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
        totalContributions: 255000,
        averageContribution: 42500,
        highestContribution: 70000,
        contributionCount: 6,
      );
    }
  }
}

/// Insights State
enum InsightsStatus {
  initial,
  loading,
  loaded,
  error,
}

class InsightsState {
  final InsightsStatus status;
  final InsightsData? data;
  final String? error;

  const InsightsState({
    this.status = InsightsStatus.initial,
    this.data,
    this.error,
  });

  bool get isLoading => status == InsightsStatus.loading;
  bool get isLoaded => status == InsightsStatus.loaded;

  InsightsState copyWith({
    InsightsStatus? status,
    InsightsData? data,
    String? error,
  }) {
    return InsightsState(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error,
    );
  }
}

/// Insights Notifier
class InsightsNotifier extends StateNotifier<InsightsState> {
  final InsightsRepository _repository;

  InsightsNotifier(this._repository) : super(const InsightsState());

  /// Load insights
  Future<void> loadInsights({int months = 6}) async {
    state = state.copyWith(status: InsightsStatus.loading);
    try {
      final data = await _repository.getInsights(months: months);
      state = state.copyWith(
        status: InsightsStatus.loaded,
        data: data,
      );
    } catch (e) {
      logger.e('Load insights error: $e');
      state = state.copyWith(
        status: InsightsStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Refresh insights
  Future<void> refreshInsights({int months = 6}) async {
    await loadInsights(months: months);
  }
}

/// Insights Repository Provider
final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InsightsRepository(apiClient);
});

/// Insights Provider
final insightsProvider =
    StateNotifierProvider<InsightsNotifier, InsightsState>((ref) {
  final repository = ref.watch(insightsRepositoryProvider);
  return InsightsNotifier(repository);
});
