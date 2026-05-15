import 'package:dio/dio.dart';
import '../../../core/utils/utils.dart';

/// Model for the member's current contribution plan
class ContributionPlan {
  final double currentMonthlyAmount;
  final double minimumAmount;
  final PendingReductionRequest? pendingReduction;

  const ContributionPlan({
    required this.currentMonthlyAmount,
    this.minimumAmount = 5000.0,
    this.pendingReduction,
  });

  factory ContributionPlan.fromJson(Map<String, dynamic> json) {
    return ContributionPlan(
      currentMonthlyAmount:
          (json['current_monthly_amount'] as num?)?.toDouble() ?? 5000.0,
      minimumAmount: (json['minimum_amount'] as num?)?.toDouble() ?? 5000.0,
      pendingReduction: json['pending_reduction'] != null
          ? PendingReductionRequest.fromJson(
              json['pending_reduction'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Pending contribution reduction request
class PendingReductionRequest {
  final String id;
  final double requestedAmount;
  final DateTime requestedAt;
  final DateTime effectiveDate;
  final String status;

  const PendingReductionRequest({
    required this.id,
    required this.requestedAmount,
    required this.requestedAt,
    required this.effectiveDate,
    required this.status,
  });

  factory PendingReductionRequest.fromJson(Map<String, dynamic> json) {
    return PendingReductionRequest(
      id: json['id'] as String? ?? '',
      requestedAmount:
          (json['requested_amount'] as num?)?.toDouble() ?? 5000.0,
      requestedAt: DateTime.parse(
          json['requested_at'] as String? ?? DateTime.now().toIso8601String()),
      effectiveDate: DateTime.parse(json['effective_date'] as String? ??
          DateTime.now().add(const Duration(days: 90)).toIso8601String()),
      status: json['status'] as String? ?? 'pending',
    );
  }

  /// How many months remain before the reduction takes effect
  int get monthsRemaining {
    final now = DateTime.now();
    if (effectiveDate.isBefore(now)) return 0;
    final diff = effectiveDate.difference(now);
    return (diff.inDays / 30).ceil().clamp(0, 3);
  }
}

/// API service for contribution plan management
class ContributionPlanApiService {
  final Dio _dio;

  ContributionPlanApiService(this._dio);

  /// Get the member's current contribution plan
  Future<ContributionPlan> getContributionPlan() async {
    try {
      final response = await _dio.get('/contributions/plan');
      return ContributionPlan.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      logger.w('Could not fetch contribution plan from API, using defaults: $e');
      return const ContributionPlan(currentMonthlyAmount: 5000.0);
    }
  }

  /// Increase monthly contribution — takes effect immediately
  Future<ContributionPlan> increaseContribution(double newAmount) async {
    final response = await _dio.patch(
      '/contributions/plan/increase',
      data: {'new_monthly_amount': newAmount},
    );
    return ContributionPlan.fromJson(response.data as Map<String, dynamic>);
  }

  /// Submit a contribution reduction request — 3-month notice period applies
  Future<PendingReductionRequest> requestReduction(double newAmount) async {
    final response = await _dio.post(
      '/contributions/plan/reduction-request',
      data: {'requested_amount': newAmount},
    );
    return PendingReductionRequest.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Cancel a pending reduction request
  Future<void> cancelReductionRequest(String requestId) async {
    await _dio.delete('/contributions/plan/reduction-request/$requestId');
  }
}
