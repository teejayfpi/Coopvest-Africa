import 'notification_service.dart';
import '../../data/models/contributions/monthly_contribution.dart';
import '../../config/app_config.dart';
import '../network/api_client.dart';
import '../utils/payment_date_utils.dart';
import 'logger_service.dart';

/// The kind of contribution reminder to show, or [none].
enum ContributionReminderKind { none, dueToday, dueSoon, overdue, }

/// A reminder decision: what to show and, for [dueSoon]/[overdue], how many
/// days it refers to.
class ContributionReminderDecision {
  final ContributionReminderKind kind;
  final int days;
  const ContributionReminderDecision(this.kind, [this.days = 0]);

  static const none = ContributionReminderDecision(ContributionReminderKind.none);
}

/// Decide which contribution reminder (if any) a member should see.
///
/// Pure and free of clock/IO concerns so the rules can be unit-tested. This
/// exists because the previous inline logic nagged members who had already paid
/// (it only trusted a `contributions` row, while wallet deposits never write
/// one) and nagged brand-new members whose first due date had not arrived yet.
///
/// [daysSincePreferredDay] is days past this month's due date: 0 = today,
/// negative = still upcoming, positive = overdue.
ContributionReminderDecision evaluateContributionReminder({
  required bool hasPaidThisMonth,
  required bool isNewMember,
  required bool isPayroll,
  required int daysSincePreferredDay,
}) {
  // Nothing to chase: already settled, joined this month, or on payroll.
  if (hasPaidThisMonth || isNewMember || isPayroll) {
    return ContributionReminderDecision.none;
  }

  if (daysSincePreferredDay == 0) {
    return const ContributionReminderDecision(ContributionReminderKind.dueToday);
  }
  if (daysSincePreferredDay == -3 || daysSincePreferredDay == -1) {
    return ContributionReminderDecision(
      ContributionReminderKind.dueSoon,
      daysSincePreferredDay.abs(),
    );
  }
  if (daysSincePreferredDay > 0) {
    return ContributionReminderDecision(
      ContributionReminderKind.overdue,
      daysSincePreferredDay,
    );
  }
  return ContributionReminderDecision.none;
}

/// Contribution Reminder Service - Singleton Pattern
/// Handles contribution reminder notifications with both:
/// - Client-side: In-app reminders when user opens app
/// - Backend-triggered: Push notifications via Supabase Edge Functions
class ContributionReminderService {
  static final ContributionReminderService _instance = ContributionReminderService._();
  factory ContributionReminderService() => _instance;
  ContributionReminderService._();

  final NotificationService _notificationService = NotificationService();
  bool _initialized = false;
  DateTime? _lastCheckTime;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    logger.info('ContributionReminderService initialized');
  }

  /// Check and send appropriate contribution reminders
  /// Called on app startup and periodically while app is open
  /// [paidThisMonth] and [isNewMember] come from the server's obligations
  /// calculation, which knows about wallet-deposit payments and the join date.
  /// [isPayroll] short-circuits for salary-deduction members, who never pay
  /// in-app and so must never be told they are overdue.
  Future<void> checkAndSendReminders({
    required List<MonthlyContribution> contributions,
    required double monthlyAmount,
    required int preferredDay,
    required double totalSavings,
    bool paidThisMonth = false,
    bool isNewMember = false,
    bool isPayroll = false,
  }) async {
    // Rate limit: Only check once per hour
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!).inMinutes < 60) {
      return;
    }

    _lastCheckTime = DateTime.now();

    final now = DateTime.now();
    
    // Get this month's contribution
    final thisMonthContribution = _getThisMonthContribution(contributions);
    
    // Calculate contribution streak
    final streak = _calculateContributionStreak(contributions);
    
    final decision = evaluateContributionReminder(
      hasPaidThisMonth: paidThisMonth || thisMonthContribution != null,
      isNewMember: isNewMember,
      isPayroll: isPayroll,
      daysSincePreferredDay: _getDaysSincePreferredDay(preferredDay, now),
    );

    switch (decision.kind) {
      case ContributionReminderKind.dueToday:
        await _notificationService.showNoContributionThisMonthNotification(
          monthlyAmount: monthlyAmount,
          dayOfMonth: preferredDay,
        );
        break;
      case ContributionReminderKind.dueSoon:
        await _notificationService.showContributionReminderNotification(
          daysUntilDue: decision.days,
          monthlyAmount: monthlyAmount,
        );
        break;
      case ContributionReminderKind.overdue:
        await _notificationService.showMissedContributionNotification(
          monthlyAmount: monthlyAmount,
          daysOverdue: decision.days,
        );
        break;
      case ContributionReminderKind.none:
        break;
    }

    // Only celebrate/inform about progress when the month is actually paid.
    if (thisMonthContribution != null) {
      if (streak >= 3 && streak % 3 == 0) {
        await _notificationService.showContributionStreakNotification(
          streakMonths: streak,
          totalSavings: totalSavings,
        );
      }

      // Check loan eligibility progress
      await _checkLoanEligibility(totalSavings);
    }

    // Trigger backend notification check (async, doesn't block)
    _triggerBackendNotificationCheck();
  }

  /// Trigger backend to send push notification reminders
  /// This ensures notifications are sent even when app is closed
  Future<void> _triggerBackendNotificationCheck() async {
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/notifications/contribution-reminder-check',
        data: {'triggeredAt': DateTime.now().toIso8601String()},
      );
      logger.debug('Backend notification check triggered');
    } catch (e) {
      // Silently fail - this is just to trigger backend
      logger.debug('Backend notification check failed: $e');
    }
  }

  /// Sync contribution status with backend for cron job processing
  Future<void> syncContributionStatus({
    required String userId,
    required List<MonthlyContribution> contributions,
    required double monthlyAmount,
    required int preferredDay,
    required String contributionMethod,
  }) async {
    if (contributionMethod != 'manual') return;

    try {
      final apiClient = ApiClient();
      final now = DateTime.now();
      final thisMonthContribution = _getThisMonthContribution(contributions);
      final hasContributedThisMonth = thisMonthContribution != null;

      await apiClient.post(
        '/user/contribution-status',
        data: {
          'userId': userId,
          'hasContributedThisMonth': hasContributedThisMonth,
          'preferredDay': preferredDay,
          'monthlyAmount': monthlyAmount,
          'lastContributionDate': thisMonthContribution?.createdAt.toIso8601String(),
          'dueDate': PaymentDateUtils.resolveDueDate(
                  now.year, now.month, preferredDay)
              .toIso8601String(),
        },
      );
      logger.debug('Contribution status synced with backend');
    } catch (e) {
      logger.debug('Failed to sync contribution status: $e');
    }
  }

  /// The contribution that settles THIS calendar month, if any.
  ///
  /// Two bugs here made the "your contribution is due" notification keep
  /// firing for months after a member had actually paid:
  ///
  /// 1. It matched on `createdAt` (when the row was written) instead of
  ///    `contributionMonth` (the month being paid for). A payment made in June
  ///    for May has createdAt in June, so it counted against June and May still
  ///    looked unpaid — and the reminder repeated every month thereafter.
  ///
  /// 2. It ignored status, so a failed, reversed or still-processing row
  ///    counted as paid.
  MonthlyContribution? _getThisMonthContribution(List<MonthlyContribution> contributions) {
    final now = DateTime.now();
    final thisMonth = _monthKey(now.year, now.month);
    for (final contribution in contributions) {
      if (!_isSettled(contribution.status)) continue;
      if (contribution.contributionMonth.trim() == thisMonth) return contribution;
    }
    return null;
  }

  String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  /// True when a contribution is actually paid for its month.
  ///
  /// 'pending' / 'processing' are excluded on purpose: a payment in flight has
  /// not settled, so the month is still due and the reminder is correct.
  bool _isSettled(ContributionStatus status) =>
      status == ContributionStatus.successful ||
      status == ContributionStatus.adjusted;

  int _calculateContributionStreak(List<MonthlyContribution> contributions) {
    if (contributions.isEmpty) return 0;
    
    final sortedContributions = List<MonthlyContribution>.from(contributions)
      ..sort((a, b) => (b.createdAt).compareTo(a.createdAt));
    
    int streak = 0;
    DateTime? lastMonth;
    
    for (final contribution in sortedContributions) {
      final contributionMonth = DateTime(
        contribution.createdAt.year,
        contribution.createdAt.month,
      );
      
      if (lastMonth == null) {
        final now = DateTime.now();
        final thisMonth = DateTime(now.year, now.month);
        
        if (contributionMonth == thisMonth ||
            contributionMonth == DateTime(thisMonth.year, thisMonth.month - 1)) {
          streak = 1;
          lastMonth = contributionMonth;
        } else {
          break;
        }
      } else {
        final expectedMonth = DateTime(lastMonth.year, lastMonth.month - 1);
        if (contributionMonth == expectedMonth) {
          streak++;
          lastMonth = contributionMonth;
        } else {
          break;
        }
      }
    }
    
    return streak;
  }

  int _getDaysSincePreferredDay(int preferredDay, DateTime now) {
    final dueDate =
        PaymentDateUtils.resolveDueDate(now.year, now.month, preferredDay);
    return now.difference(dueDate).inDays;
  }

  Future<void> _checkLoanEligibility(double totalSavings) async {
    final potentialLoan = totalSavings * AppConfig.loanMultiplier;
    if (potentialLoan >= 100000 && totalSavings >= 50000) {
      // Send loan eligibility notification if eligible
      await _notificationService.showLoanEligibilityReminderNotification(
        currentSavings: totalSavings,
        savingsRequired: totalSavings,
        loanAmount: potentialLoan,
      );
    }
  }
}

// Singleton instance for use throughout the app
final contributionReminderService = ContributionReminderService();
