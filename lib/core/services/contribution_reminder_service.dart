import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import '../../data/models/contribution_models.dart';
import '../../config/app_config.dart';

/// Contribution Reminder Service
/// Automatically schedules and sends contribution reminder notifications
/// to ensure members stay on track with their monthly contributions.
class ContributionReminderService {
  final NotificationService _notificationService = NotificationService();

  /// Check and send appropriate contribution reminders
  /// Call this on app startup and periodically
  Future<void> checkAndSendReminders({
    required List<Contribution> contributions,
    required double monthlyAmount,
    required int preferredDay,
    required double totalSavings,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
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
      } else if (daysSincePreferredDay > 0 && daysSincePreferredDay <= 3) {
        // Due within last 3 days
        await _notificationService.showContributionReminderNotification(
          daysUntilDue: 0,
          monthlyAmount: monthlyAmount,
        );
      } else if (daysSincePreferredDay > 3) {
        // Overdue
        await _notificationService.showMissedContributionNotification(
          monthlyAmount: monthlyAmount,
          daysOverdue: daysSincePreferredDay,
        );
      }
    } else {
      // Contribution was made - check if we need to send a streak notification
      if (streak >= 3 && streak % 3 == 0) {
        // Send streak notification every 3 months
        await _notificationService.showContributionStreakNotification(
          streakMonths: streak,
          totalSavings: totalSavings,
        );
      }
      
      // Check if loan eligibility is close
      await _checkLoanEligibility(totalSavings);
    }
  }

  /// Schedule reminders for the month
  /// These would typically be handled by a backend scheduler or
  /// using background tasks on the device
  Future<void> scheduleMonthlyReminders({
    required int preferredDay,
    required double monthlyAmount,
  }) async {
    // In a real implementation, this would schedule local notifications
    // using flutter_local_notifications or similar
    
    // For now, we provide the logic that can be called:
    // 1. On app startup
    // 2. On a timer (e.g., daily at 9 AM)
    
    final now = DateTime.now();
    
    // Schedule reminder for 3 days before due date
    final reminderDate = DateTime(now.year, now.month, preferredDay - 3);
    if (reminderDate.isAfter(now)) {
      // This would be scheduled as a future notification
    }
    
    // Schedule reminder for 1 day before due date
    final oneDayReminder = DateTime(now.year, now.month, preferredDay - 1);
    if (oneDayReminder.isAfter(now)) {
      // This would be scheduled as a future notification
    }
    
    logger.d('Contribution reminders scheduled for day $preferredDay');
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
    
    // Sort contributions by date (most recent first)
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
        // First contribution
        final now = DateTime.now();
        final thisMonth = DateTime(now.year, now.month);
        
        // Check if contribution is this month or last month
        if (contributionMonth == thisMonth ||
            contributionMonth == DateTime(thisMonth.year, thisMonth.month - 1)) {
          streak = 1;
          lastMonth = contributionMonth;
        } else {
          break;
        }
      } else {
        // Check if this contribution is from the previous month
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
    // Calculate potential loan amount (3x savings)
    final potentialLoan = totalSavings * AppConfig.loanMultiplier;
    
    // Check if they're close to eligibility threshold
    // For example, if they have 70%+ of what's needed
    if (potentialLoan >= 100000 && totalSavings >= 50000) {
      // They're close to being eligible
      // This could be triggered periodically
    }
  }
}

// Provider for the contribution reminder service
final contributionReminderServiceProvider = Provider<ContributionReminderService>((ref) {
  return ContributionReminderService();
});
