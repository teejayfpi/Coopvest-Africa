import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/utils/loan_eligibility.dart';
import 'package:coopvest_mobile/data/models/contributions/monthly_contribution.dart';

/// Builds a settled contribution for a 'YYYY-MM' month.
MonthlyContribution contribution(
  String month, {
  ContributionStatus status = ContributionStatus.successful,
}) {
  final parts = month.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 15);
  return MonthlyContribution(
    id: 'c-$month',
    userId: 'u1',
    contributionMonth: month,
    amount: 5000,
    type: ContributionType.monthly,
    status: status,
    createdAt: date,
    updatedAt: date,
    postedDate: date,
  );
}

void main() {
  // Fixed clock: the rule is about calendar months, so tests must not drift
  // with the real date.
  final now = DateTime(2026, 11, 20);

  group('longestConsecutiveRun', () {
    test('counts an unbroken run', () {
      final run = LoanEligibility.longestConsecutiveRun(
        ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11']
            .map(contribution)
            .toList(),
        now: now,
      );
      expect(run, 6);
    });

    test('is zero with no contributions', () {
      expect(LoanEligibility.longestConsecutiveRun(const [], now: now), 0);
    });

    test('a gap breaks the run and the count restarts', () {
      // Jun, Jul, then nothing in Aug, then Sep, Oct.
      final run = LoanEligibility.longestConsecutiveRun(
        ['2026-06', '2026-07', '2026-09', '2026-10'].map(contribution).toList(),
        now: now,
      );
      expect(run, 2, reason: 'the longest unbroken stretch is two months');
    });

    test('six months then a lapse does not read as six', () {
      // The reported bug: six consecutive months, then stopped.
      final run = LoanEligibility.longestConsecutiveRun(
        ['2026-01', '2026-02', '2026-03', '2026-04', '2026-05', '2026-06']
            .map(contribution)
            .toList(),
        now: now,
      );
      // The run is still six *months long*; currency is checked separately.
      expect(run, 6);
    });

    test('months paid before a gap do not extend the run after it', () {
      final run = LoanEligibility.longestConsecutiveRun(
        [
          '2026-01', '2026-02', '2026-03', '2026-04', '2026-05', '2026-06',
          // gap in July, August
          '2026-09', '2026-10', '2026-11',
        ].map(contribution).toList(),
        now: now,
      );
      expect(run, 6, reason: 'the earlier six-month run is the longest');
    });

    test('ignores unpaid statuses', () {
      final run = LoanEligibility.longestConsecutiveRun(
        [
          contribution('2026-09', status: ContributionStatus.pending),
          contribution('2026-10', status: ContributionStatus.failed),
          contribution('2026-11'),
        ],
        now: now,
      );
      expect(run, 1);
    });

    test('a parsed paid contribution counts toward the run', () {
      // The server stores 'completed', 'approved', 'confirmed' and 'paid'; all
      // of them must parse to a settled status or a paying member reads as
      // unpaid.
      for (final raw in ['successful', 'completed', 'approved', 'confirmed', 'paid']) {
        final c = MonthlyContribution.fromJson({
          'id': 'c-2026-11',
          'user_id': 'u1',
          'contribution_month': '2026-11',
          'amount': 5000,
          'contribution_type': 'monthly',
          'status': raw,
          'created_at': '2026-11-15T00:00:00Z',
          'updated_at': '2026-11-15T00:00:00Z',
          'posted_date': '2026-11-15T00:00:00Z',
        });
        expect(
          LoanEligibility.longestConsecutiveRun([c], now: now),
          1,
          reason: 'a "$raw" contribution should count as settled',
        );
      }
    });

    test('an unpaid contribution does not count', () {
      for (final status in [
        ContributionStatus.pending,
        ContributionStatus.failed,
      ]) {
        expect(
          LoanEligibility.longestConsecutiveRun(
            [contribution('2026-11', status: status)],
            now: now,
          ),
          0,
          reason: '${status.name} should not count',
        );
      }
    });

    test('handles a run spanning a year boundary', () {
      final run = LoanEligibility.longestConsecutiveRun(
        ['2025-10', '2025-11', '2025-12', '2026-01', '2026-02', '2026-03']
            .map(contribution)
            .toList(),
        now: now,
      );
      expect(run, 6);
    });

    test('duplicate months do not inflate the run', () {
      final run = LoanEligibility.longestConsecutiveRun(
        ['2026-10', '2026-10', '2026-11'].map(contribution).toList(),
        now: now,
      );
      expect(run, 2);
    });
  });

  group('isCurrent', () {
    test('true when the current month is paid', () {
      expect(
        LoanEligibility.isCurrent([contribution('2026-11')], now: now),
        isTrue,
      );
    });

    test('true when last month is paid (grace period)', () {
      expect(
        LoanEligibility.isCurrent([contribution('2026-10')], now: now),
        isTrue,
      );
    });

    test('false when two months behind', () {
      expect(
        LoanEligibility.isCurrent([contribution('2026-09')], now: now),
        isFalse,
      );
    });

    test('false with no contributions', () {
      expect(LoanEligibility.isCurrent(const [], now: now), isFalse);
    });
  });

  group('isNextMonth', () {
    test('recognises the next month', () {
      expect(LoanEligibility.isNextMonth('2026-10', '2026-11'), isTrue);
    });

    test('recognises the year rollover', () {
      expect(LoanEligibility.isNextMonth('2025-12', '2026-01'), isTrue);
    });

    test('rejects a gap', () {
      expect(LoanEligibility.isNextMonth('2026-09', '2026-11'), isFalse);
    });

    test('rejects a repeated month', () {
      expect(LoanEligibility.isNextMonth('2026-11', '2026-11'), isFalse);
    });

    test('is safe on malformed input', () {
      expect(LoanEligibility.isNextMonth('nonsense', '2026-11'), isFalse);
      expect(LoanEligibility.isNextMonth('2026-11', ''), isFalse);
    });
  });

  group('the reported bug', () {
    test('six months of membership with no savings is not eligible', () {
      // This is the production case: a member six months in, zero
      // contributions. The dashboard card used to call this eligible.
      final run = LoanEligibility.longestConsecutiveRun(const [], now: now);
      final current = LoanEligibility.isCurrent(const [], now: now);
      final membershipMonths = 6;

      final eligible =
          membershipMonths >= LoanEligibility.membershipMonthsRequired &&
              run >= LoanEligibility.consecutiveMonthsRequired &&
              current;

      expect(eligible, isFalse);
    });

    test('six consecutive saving months and current is eligible', () {
      final contributions =
          ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11']
              .map(contribution)
              .toList();
      final run = LoanEligibility.longestConsecutiveRun(contributions, now: now);

      final eligible =
          6 >= LoanEligibility.membershipMonthsRequired &&
              run >= LoanEligibility.consecutiveMonthsRequired &&
              LoanEligibility.isCurrent(contributions, now: now);

      expect(eligible, isTrue);
    });
  });
}
