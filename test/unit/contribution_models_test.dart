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
      const filter = ContributionFilter(
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
      final filter = const ContributionFilter().thisMonth();
      final now = DateTime.now();

      expect(filter.year, now.year);
      expect(filter.month, now.month);
      expect(filter.startDate?.month, now.month);
      expect(filter.endDate?.month, now.month);
    });

    test('should create last 3 months filter', () {
      final filter = const ContributionFilter().last3Months();

      expect(filter.startDate, isNotNull);
      expect(filter.endDate, isNotNull);
      
      final diff = filter.endDate!.difference(filter.startDate!).inDays;
      expect(diff, greaterThanOrEqualTo(89)); // ~3 months
    });

    test('should create this year filter', () {
      final filter = const ContributionFilter().thisYear();
      final now = DateTime.now();

      expect(filter.year, now.year);
      expect(filter.startDate?.month, 1);
      expect(filter.endDate?.month, 12);
    });

    test('should create all time filter', () {
      final filter = const ContributionFilter().allTime();

      expect(filter.year, isNull);
      expect(filter.month, isNull);
      expect(filter.startDate, isNull);
      expect(filter.endDate, isNull);
    });

    test('should copy filter with modifications', () {
      const original = ContributionFilter(year: 2024, month: 1);
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

  // The backend returns raw `contributions` rows (GET /contributions does
  // `select('*')`): the member column is `profile_id`, and the table has no
  // `updated_at` and no `contribution_type`. The model used to cast `user_id`
  // and `updated_at` as non-null Strings, so every real row threw
  // "type 'Null' is not a subtype of type 'String' in type cast" and the
  // Monthly Contributions screen failed to load. These tests pin the shape the
  // API actually sends.
  group('parses the raw backend contributions row', () {
    Map<String, dynamic> backendRow() => {
          'id': 'row-1',
          'profile_id': 'profile-9',
          'amount': 5000,
          'status': 'successful',
          'contribution_month': '2026-09',
          'created_at': '2026-09-01T08:00:00Z',
          // No `user_id`, no `updated_at`, no `contribution_type`.
        };

    test('maps profile_id onto userId', () {
      final c = MonthlyContribution.fromJson(backendRow());
      expect(c.userId, 'profile-9');
    });

    test('does not require user_id', () {
      expect(() => MonthlyContribution.fromJson(backendRow()), returnsNormally);
    });

    test('falls back to created_at when updated_at is absent', () {
      final c = MonthlyContribution.fromJson(backendRow());
      expect(c.updatedAt, DateTime.parse('2026-09-01T08:00:00Z'));
    });

    test('derives the month from created_at when contribution_month is null', () {
      final row = backendRow()..['contribution_month'] = null;
      final c = MonthlyContribution.fromJson(row);
      expect(c.contributionMonth, '2026-09');
    });

    test('defaults contribution_type to monthly when absent', () {
      final c = MonthlyContribution.fromJson(backendRow());
      expect(c.type, ContributionType.monthly);
    });

    test('still accepts the legacy user_id/updated_at shape', () {
      final row = <String, dynamic>{
        'id': 'row-2',
        'user_id': 'user-2',
        'profile_id': 'profile-2',
        'amount': 1000,
        'status': 'pending',
        'contribution_month': '2026-08',
        'contribution_type': 'voluntary',
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-02T00:00:00Z',
      };
      final c = MonthlyContribution.fromJson(row);
      // profile_id wins when both are present — it is the live column.
      expect(c.userId, 'profile-2');
      expect(c.updatedAt, DateTime.parse('2026-08-02T00:00:00Z'));
      expect(c.type, ContributionType.voluntary);
    });
  });

  // GET /contributions/:id returns the row at the top level
  // (`{ success: true, ...row }`), not wrapped in a `contribution` key.
  group('ContributionDetail parses a flat backend payload', () {
    test('reads the contribution row from the top level', () {
      final flat = <String, dynamic>{
        'success': true,
        'id': 'row-7',
        'profile_id': 'profile-7',
        'amount': 2500,
        'status': 'successful',
        'contribution_month': '2026-09',
        'created_at': '2026-09-03T09:30:00Z',
      };
      final detail = ContributionDetail.fromJson(flat);
      expect(detail.contribution.id, 'row-7');
      expect(detail.contribution.userId, 'profile-7');
      expect(detail.contribution.amount, 2500.0);
    });

    test('still reads the nested envelope shape', () {
      final nested = <String, dynamic>{
        'contribution': <String, dynamic>{
          'id': 'row-8',
          'profile_id': 'profile-8',
          'amount': 100,
          'status': 'pending',
          'contribution_month': '2026-09',
          'created_at': '2026-09-04T00:00:00Z',
        },
        'receipt_url': 'https://example.test/r.pdf',
      };
      final detail = ContributionDetail.fromJson(nested);
      expect(detail.contribution.id, 'row-8');
      expect(detail.receiptUrl, 'https://example.test/r.pdf');
    });
  });

}
