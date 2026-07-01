import 'dart:convert';
import 'package:dio/dio.dart';
import 'notification_service.dart';
import '../../data/models/contribution_models.dart';
import '../../config/app_config.dart';
import '../network/api_client.dart';
import 'logger_service.dart';

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
  Future<void> checkAndSendReminders({
    required List<Contribution> contributions,
    required double monthlyAmount,
    required int preferredDay,
    required double totalSavings,
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
    
    // Check if contribution was made this month
    if (thisMonthContribution == null) {
      // No contribution this month yet
      final daysSincePreferredDay = _getDaysSincePreferredDay(preferredDay, now);
      
      if (daysSincePreferredDay == 0) {
        // Due today
        await _notificationService.showNoContributionThisMonthNotification(
          monthlyAmount: monthlyAmount,
          dayOfMonth: preferredDay,
        );
      } else if (daysSincePreferredDay == -3 || daysSincePreferredDay == -1) {
        // Due in 3 days or tomorrow
        await _notificationService.showContributionReminderNotification(
          daysUntilDue: daysSincePreferredDay.abs(),
          monthlyAmount: monthlyAmount,
        );
      } else if (daysSincePreferredDay > 0) {
        // Overdue
        await _notificationService.showMissedContributionNotification(
          monthlyAmount: monthlyAmount,
          daysOverdue: daysSincePreferredDay,
        );
      }
    } else {
      // Contribution was made - check for streak notification
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
    required List<Contribution> contributions,
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
          'lastContributionDate': thisMonthContribution?.createdAt?.toIso8601String(),
          'dueDate': DateTime(now.year, now.month, preferredDay).toIso8601String(),
        },
      );
      logger.debug('Contribution status synced with backend');
    } catch (e) {
      logger.debug('Failed to sync contribution status: $e');
    }
  }

  Contribution? _getThisMonthContribution(List<Contribution> contributions) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    
    for (final contribution in contributions) {
      if (contribution.createdAt != null) {
        final contributionMonth = DateTime(
          contribution.createdAt!.year,
          contribution.createdAt!.month,
        );
        if (contributionMonth == thisMonth) {
          return contribution;
        }
      }
    }
    return null;
  }

  int _calculateContributionStreak(List<Contribution> contributions) {
    if (contributions.isEmpty) return 0;
    
    final sortedContributions = List<Contribution>.from(contributions)
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    
    int streak = 0;
    DateTime? lastMonth;
    
    for (final contribution in sortedContributions) {
      if (contribution.createdAt == null) continue;
      
      final contributionMonth = DateTime(
        contribution.createdAt!.year,
        contribution.createdAt!.month,
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
    final dueDate = DateTime(now.year, now.month, preferredDay);
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
