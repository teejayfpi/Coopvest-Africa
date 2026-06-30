import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/contributions/monthly_contribution.dart';

void main() {
  group('Contribution Model Tests', () {
    test('should create MonthlyContribution from JSON', () {
      final json = {
        'id': 'contrib_123',
        'user_id': 'user_456',
        'contribution_month': '2024-01',
        'amount': 10000.0,
        'contribution_type': 'monthly',
        'status': 'successful',
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

      final contribution = MonthlyContribution.fromJson(json);

      expect(contribution.id, 'contrib_123');
      expect(contribution.userId, 'user_456');
      expect(contribution.amount, 10000.0);
      expect(contribution.type, ContributionType.monthly);
      expect(contribution.status, ContributionStatus.successful);
    });

    test('should handle different contribution types', () {
      final types = ['monthly', 'voluntary', 'special', 'arrears', 'topup'];
      
      for (final type in types) {
        final json = {
          'id': 'test_$type',
          'user_id': 'user_1',
          'contribution_month': '2024-01',
          'amount': 5000.0,
          'contribution_type': type,
          'status': 'pending',
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        final contribution = MonthlyContribution.fromJson(json);
        expect(contribution.type.name, type);
      }
    });

    test('should convert MonthlyContribution to JSON', () {
      final contribution = MonthlyContribution(
        id: 'test_convert',
        userId: 'user_test',
        contributionMonth: '2024-02',
        amount: 15000.0,
        type: ContributionType.monthly,
        status: ContributionStatus.successful,
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
      );

      final json = contribution.toJson();

      expect(json['id'], 'test_convert');
      expect(json['amount'], 15000.0);
      expect(json['contribution_type'], 'monthly');
      expect(json['status'], 'successful');
    });

    test('should parse status history', () {
      final json = {
        'id': 'test_history',
        'user_id': 'user_1',
        'contribution_month': '2024-01',
        'amount': 10000.0,
        'contribution_type': 'monthly',
        'status': 'successful',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
        'status_history': [
          {
            'status': 'pending',
            'description': 'Payment initiated',
            'timestamp': '2024-01-01T10:00:00Z',
          },
          {
            'status': 'processing',
            'description': 'Payment being processed',
            'timestamp': '2024-01-01T10:30:00Z',
          },
          {
            'status': 'successful',
            'description': 'Payment completed',
            'timestamp': '2024-01-01T11:00:00Z',
          },
        ],
      };

      final contribution = MonthlyContribution.fromJson(json);

      expect(contribution.statusHistory, isNotNull);
      expect(contribution.statusHistory!.length, 3);
      expect(contribution.statusHistory![0].status, ContributionStatus.pending);
      expect(contribution.statusHistory![2].status, ContributionStatus.successful);
    });
  });

  group('ContributionFilter Tests', () {
    test('should create filter with query parameters', () {
      final filter = ContributionFilter(
        year: 2024,
        month: 1,
        status: ContributionStatus.successful,
        type: ContributionType.monthly,
      );

      final params = filter.toQueryParameters();

      expect(params['year'], 2024);
      expect(params['month'], 1);
      expect(params['status'], 'successful');
      expect(params['type'], 'monthly');
    });

    test('should create this month filter', () {
      final filter = ContributionFilter().thisMonth();
      final now = DateTime.now();

      expect(filter.year, now.year);
      expect(filter.month, now.month);
      expect(filter.startDate?.month, now.month);
      expect(filter.endDate?.month, now.month);
    });

    test('should create last 3 months filter', () {
      final filter = ContributionFilter().last3Months();

      expect(filter.startDate, isNotNull);
      expect(filter.endDate, isNotNull);
      
      final diff = filter.endDate!.difference(filter.startDate!).inDays;
      expect(diff, greaterThanOrEqualTo(89)); // ~3 months
    });

    test('should create this year filter', () {
      final filter = ContributionFilter().thisYear();
      final now = DateTime.now();

      expect(filter.year, now.year);
      expect(filter.startDate?.month, 1);
      expect(filter.endDate?.month, 12);
    });

    test('should create all time filter', () {
      final filter = ContributionFilter().allTime();

      expect(filter.year, isNull);
      expect(filter.month, isNull);
      expect(filter.startDate, isNull);
      expect(filter.endDate, isNull);
    });

    test('should copy filter with modifications', () {
      final original = ContributionFilter(year: 2024, month: 1);
      final modified = original.copyWith(status: ContributionStatus.successful);

      expect(original.year, 2024);
      expect(original.status, isNull);
      expect(modified.year, 2024);
      expect(modified.status, ContributionStatus.successful);
    });
  });

  group('Contribution Summary Tests', () {
    test('should create ContributionSummary from JSON', () {
      final json = {
        'total_this_month': 10000.0,
        'total_this_year': 120000.0,
        'lifetime_contributions': 500000.0,
        'expected_monthly_amount': 10000.0,
        'contribution_status': 'up_to_date',
        'months_contributed': 50,
        'total_contributions_count': 50,
        'pending_amount': 0.0,
        'overdue_amount': 0.0,
      };

      final summary = ContributionSummary.fromJson(json);

      expect(summary.totalThisMonth, 10000.0);
      expect(summary.totalThisYear, 120000.0);
      expect(summary.lifetimeContributions, 500000.0);
      expect(summary.contributionStatus, 'up_to_date');
      expect(summary.monthsContributed, 50);
    });

    test('should handle missing optional fields', () {
      final json = {
        'total_this_month': 5000.0,
        'total_this_year': 60000.0,
        'lifetime_contributions': 200000.0,
        'expected_monthly_amount': 5000.0,
        'contribution_status': 'pending',
        'months_contributed': 40,
        'total_contributions_count': 40,
      };

      final summary = ContributionSummary.fromJson(json);

      expect(summary.pendingAmount, isNull);
      expect(summary.overdueAmount, isNull);
    });
  });

  group('Contribution Method Extension Tests', () {
    test('should return correct display names', () {
      expect(ContributionMethod.manual.displayName, 'Monthly Self Contribution');
      expect(ContributionMethod.payroll.displayName, 'Salary Deduction');
    });

    test('should return correct short names', () {
      expect(ContributionMethod.manual.shortName, 'Manual');
      expect(ContributionMethod.payroll.shortName, 'Payroll');
    });
  });

  group('Contribution Status Extension Tests', () {
    test('should return correct display names', () {
      expect(ContributionStatus.successful.displayName, 'Successful');
      expect(ContributionStatus.pending.displayName, 'Pending');
      expect(ContributionStatus.failed.displayName, 'Failed');
      expect(ContributionStatus.processing.displayName, 'Processing');
    });

    test('should return correct colors', () {
      expect(ContributionStatus.successful.color, 'success');
      expect(ContributionStatus.pending.color, 'warning');
      expect(ContributionStatus.failed.color, 'error');
      expect(ContributionStatus.processing.color, 'info');
    });
  });
}
