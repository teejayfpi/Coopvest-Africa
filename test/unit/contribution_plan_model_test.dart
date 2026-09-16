import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/api/contributions/contribution_plan_api_service.dart';

/// The contribution plan used to default `current_monthly_amount` to ₦5,000 in
/// two places — the API service's catch-all and the model's null-coalesce. A
/// member on ₦10,000 therefore saw "Current Monthly Contribution ₦5,000" and
/// was offered ₦10,000 as an "increase" to their own current amount. These tests
/// pin the corrected behaviour: the real figure, or a loud failure.
void main() {
  group('ContributionPlan.fromJson', () {
    test('reads the real current amount', () {
      final plan = ContributionPlan.fromJson({
        'current_monthly_amount': 20000,
        'minimum_amount': 5000,
      });
      expect(plan.currentMonthlyAmount, 20000);
      expect(plan.minimumAmount, 5000);
    });

    test('parses string amounts from PostgREST', () {
      final plan = ContributionPlan.fromJson({
        'current_monthly_amount': '7500.00',
      });
      expect(plan.currentMonthlyAmount, 7500);
    });

    test('throws when current_monthly_amount is missing', () {
      // Better to surface an error than to invent a figure the member will act on.
      expect(
        () => ContributionPlan.fromJson({'minimum_amount': 5000}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when current_monthly_amount is null', () {
      expect(
        () => ContributionPlan.fromJson({'current_monthly_amount': null}),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses a pending reduction request', () {
      final plan = ContributionPlan.fromJson({
        'current_monthly_amount': 10000,
        'pending_reduction': {
          'id': 'r1',
          'requested_amount': 5000,
          'requested_at': '2026-06-27T08:21:39Z',
          'effective_date': '2026-09-27T08:21:39Z',
          'status': 'pending',
        },
      });
      expect(plan.pendingReduction, isNotNull);
      expect(plan.pendingReduction!.requestedAmount, 5000);
    });

    test('has no pending reduction when the field is absent', () {
      final plan = ContributionPlan.fromJson({'current_monthly_amount': 10000});
      expect(plan.pendingReduction, isNull);
    });
  });
}
