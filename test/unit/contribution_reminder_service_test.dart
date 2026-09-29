import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/services/contribution_reminder_service.dart';

/// The false "your contribution of 5000 is 24 days overdue" notification fired
/// for members who had already paid and for brand-new members. The decision
/// logic is pure so each case can be pinned without a running app or a clock.
void main() {
  group('evaluateContributionReminder', () {
    test('paid member is never reminded, even when the day has passed', () {
      final decision = evaluateContributionReminder(
        hasPaidThisMonth: true,
        isNewMember: false,
        isPayroll: false,
        daysSincePreferredDay: 24,
      );
      expect(decision.kind, ContributionReminderKind.none);
    });

    test('brand-new member is not nagged before their first due date', () {
      for (final days in [-10, -3, 0, 1, 24]) {
        final decision = evaluateContributionReminder(
          hasPaidThisMonth: false,
          isNewMember: true,
          isPayroll: false,
          daysSincePreferredDay: days,
        );
        expect(decision.kind, ContributionReminderKind.none,
            reason: 'new member with daysSincePreferredDay=$days');
      }
    });

    test('payroll member is never asked to pay in-app', () {
      final decision = evaluateContributionReminder(
        hasPaidThisMonth: false,
        isNewMember: false,
        isPayroll: true,
        daysSincePreferredDay: 5,
      );
      expect(decision.kind, ContributionReminderKind.none);
    });

    test('unpaid, established member is still reminded on the due date', () {
      final decision = evaluateContributionReminder(
        hasPaidThisMonth: false,
        isNewMember: false,
        isPayroll: false,
        daysSincePreferredDay: 0,
      );
      expect(decision.kind, ContributionReminderKind.dueToday);
    });

    test('unpaid member is reminded 3 days out and 1 day out', () {
      expect(
        evaluateContributionReminder(
          hasPaidThisMonth: false,
          isNewMember: false,
          isPayroll: false,
          daysSincePreferredDay: -3,
        ).kind,
        ContributionReminderKind.dueSoon,
      );
      final tomorrow = evaluateContributionReminder(
        hasPaidThisMonth: false,
        isNewMember: false,
        isPayroll: false,
        daysSincePreferredDay: -1,
      );
      expect(tomorrow.kind, ContributionReminderKind.dueSoon);
      expect(tomorrow.days, 1);
    });

    test('the genuine overdue case still reports the day count', () {
      final decision = evaluateContributionReminder(
        hasPaidThisMonth: false,
        isNewMember: false,
        isPayroll: false,
        daysSincePreferredDay: 24,
      );
      expect(decision.kind, ContributionReminderKind.overdue);
      expect(decision.days, 24);
    });

    test('a due date far in the future produces no reminder', () {
      final decision = evaluateContributionReminder(
        hasPaidThisMonth: false,
        isNewMember: false,
        isPayroll: false,
        daysSincePreferredDay: -20,
      );
      expect(decision.kind, ContributionReminderKind.none);
    });
  });
}
