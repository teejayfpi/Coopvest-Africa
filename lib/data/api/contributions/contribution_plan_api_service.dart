import 'package:dio/dio.dart';

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

  /// Parse the plan payload.
  ///
  /// `current_monthly_amount` is required: defaulting it to ₦5,000 when the
  /// field was missing produced a display that contradicted the real plan, so
  /// a malformed payload now throws instead.
  ///
  /// Values are parsed defensively: PostgREST returns `numeric` columns as JSON
  /// strings (e.g. `"10000.00"`), so a bare `as num` cast throws on a perfectly
  /// valid response.
  factory ContributionPlan.fromJson(Map<String, dynamic> json) {
    final amount = _toDouble(json['current_monthly_amount']);
    if (amount == null) {
      throw const FormatException(
        'Contribution plan response is missing current_monthly_amount',
      );
    }
    return ContributionPlan(
      currentMonthlyAmount: amount,
      minimumAmount: _toDouble(json['minimum_amount']) ?? 5000.0,
      pendingReduction: json['pending_reduction'] != null
          ? PendingReductionRequest.fromJson(
              json['pending_reduction'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Accepts num or numeric string; returns null for anything unparseable.
  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
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
      // PostgREST returns numeric as a JSON string; `as num` would throw.
      requestedAmount: ContributionPlan._toDouble(json['requested_amount']) ?? 0,
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
  ///
  /// Throws on failure rather than inventing a figure. This previously
  /// swallowed every error and returned a fabricated ₦5,000, so a member whose
  /// plan is ₦10,000 saw "Current Monthly Contribution ₦5,000" and was offered
  /// ₦10,000 as an "increase" — i.e. their own current amount. A wrong money
  /// figure must surface as an error, never as plausible-looking data.
  Future<ContributionPlan> getContributionPlan() async {
    final response = await _dio.get('/contributions/plan');
    return ContributionPlan.fromJson(response.data as Map<String, dynamic>);
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
