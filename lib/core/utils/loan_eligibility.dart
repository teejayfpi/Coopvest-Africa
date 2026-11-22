/// Client-side mirror of the server's loan eligibility rule.
///
/// The server is authoritative (`assessEligibility` in
/// `backend/src/lib/contributionConsistency.js`); this exists only so the app
/// can show a member their standing before they submit. It must answer the
/// same question as the server, or the app says "eligible" and the server
/// answers 403.
///
/// Three surfaces need this answer — the application form, the eligibility
/// card on the dashboard, and the loan dashboard — so it lives here. Copies
/// drift: the dashboard card computed eligibility from membership tenure alone
/// while labelling its progress bar "Contribution months progress".
library;

import '../../data/models/contributions/monthly_contribution.dart';

/// The server's own eligibility answer (`GET /api/v1/loans/eligibility`).
///
/// The server holds every contribution row; the app holds one page. Displaying
/// the server's verdict avoids telling a paying member they are ineligible
/// because their run was cut off by pagination.
class ServerEligibility {
  final bool eligible;
  final int membershipMonths;
  final int membershipRequired;
  final int consecutiveMonths;
  final int consecutiveRequired;
  final bool isCurrent;
  final bool? membershipMet;
  final String? reason;
  final String? guidance;
  final String? termsSectionId;
  final String? termsSectionTitle;

  const ServerEligibility({
    required this.eligible,
    required this.membershipMonths,
    required this.membershipRequired,
    required this.consecutiveMonths,
    required this.consecutiveRequired,
    required this.isCurrent,
    this.membershipMet,
    this.reason,
    this.guidance,
    this.termsSectionId,
    this.termsSectionTitle,
  });

  static ServerEligibility? fromJson(Map<String, dynamic> json) {
    if (json['success'] != true) return null;
    // An environment with the check disabled reports `enforced: false` and no
    // figures; treat it as eligible so the card does not block the member.
    if (json['enforced'] == false) {
      return const ServerEligibility(
        eligible: true,
        membershipMonths: 0,
        membershipRequired: 0,
        consecutiveMonths: 0,
        consecutiveRequired: 0,
        isCurrent: true,
      );
    }
    final section = json['termsSection'];
    return ServerEligibility(
      eligible: json['eligible'] == true,
      membershipMonths: (json['membershipMonths'] as num?)?.toInt() ?? 0,
      membershipRequired: (json['membershipRequired'] as num?)?.toInt() ?? 6,
      consecutiveMonths: (json['consecutiveMonths'] as num?)?.toInt() ?? 0,
      consecutiveRequired: (json['consecutiveRequired'] as num?)?.toInt() ?? 6,
      isCurrent: json['isCurrent'] == true,
      membershipMet: json['membershipMet'] as bool?,
      reason: json['reason'] as String?,
      guidance: json['guidance'] as String?,
      termsSectionId: section is Map ? section['id'] as String? : null,
      termsSectionTitle: section is Map ? section['title'] as String? : null,
    );
  }
}

class LoanEligibility {
  LoanEligibility._();

  /// Months of membership required, per the published Loan Policy.
  static const int membershipMonthsRequired = 6;

  /// Consecutive contributed months required, with no month missed.
  static const int consecutiveMonthsRequired = 6;

  /// Statuses that count as a settled contribution.
  ///
  /// Must match `PAID_STATUSES` on the server. The stored vocabulary
  /// (`successful`, `completed`, `approved`, `confirmed`, `paid`) is wider than
  /// this enum, so `contributionStatusFrom` folds those aliases onto
  /// `successful` while parsing; by the time a contribution reaches here only
  /// the enum names are possible.
  static const Set<String> settledStatuses = {'successful'};

  /// The member's longest run of consecutive contributed months.
  ///
  /// Counting distinct months (the earlier behaviour) scores six for a member
  /// who paid six months, stopped for a year, then paid one — a gap is
  /// invisible. Only an unbroken run can see a gap or a lapse.
  static int longestConsecutiveRun(
    List<MonthlyContribution> contributions, {
    DateTime? now,
  }) {
    final months = contributedMonths(contributions, now: now);
    if (months.isEmpty) return 0;

    final sorted = months.toList()..sort();
    int longest = 1;
    int current = 1;
    for (var i = 1; i < sorted.length; i++) {
      current = isNextMonth(sorted[i - 1], sorted[i]) ? current + 1 : 1;
      if (current > longest) longest = current;
    }
    return longest;
  }

  /// Distinct 'YYYY-MM' keys with at least one settled contribution.
  ///
  /// Contributions older than the window are dropped: a run that ended two
  /// years ago must not read as current standing.
  static Set<String> contributedMonths(
    List<MonthlyContribution> contributions, {
    DateTime? now,
    int windowMonths = 18,
  }) {
    final cutoff = _monthsBefore(now ?? DateTime.now(), windowMonths);
    final months = <String>{};
    for (final c in contributions) {
      if (!settledStatuses.contains(c.status.name)) continue;
      final when = c.postedDate ?? c.createdAt;
      if (when.isBefore(cutoff)) continue;
      final key = c.contributionMonth.trim();
      if (key.isNotEmpty) months.add(key);
    }
    return months;
  }

  /// True when [next] is the calendar month immediately after [previous].
  /// Month keys are 'YYYY-MM'.
  static bool isNextMonth(String previous, String next) {
    final prev = previous.split('-');
    final curr = next.split('-');
    if (prev.length != 2 || curr.length != 2) return false;
    final prevYear = int.tryParse(prev[0]);
    final prevMonth = int.tryParse(prev[1]);
    final currYear = int.tryParse(curr[0]);
    final currMonth = int.tryParse(curr[1]);
    if (prevYear == null || prevMonth == null) return false;
    if (currYear == null || currMonth == null) return false;
    if (prevYear == currYear) return currMonth == prevMonth + 1;
    return currYear == prevYear + 1 && prevMonth == 12 && currMonth == 1;
  }

  /// True when the member contributed in the current month or the one before.
  ///
  /// Mirrors the server's grace period. Without this, a member who is paid up
  /// but whose last contribution landed last month would read as lapsed on the
  /// first day of a new month.
  static bool isCurrent(
    List<MonthlyContribution> contributions, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final months = contributedMonths(contributions, now: today);
    if (months.isEmpty) return false;
    final thisMonth = _monthKey(today);
    final lastMonth = _monthKey(DateTime(today.year, today.month - 1, 1));
    return months.contains(thisMonth) || months.contains(lastMonth);
  }

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime _monthsBefore(DateTime from, int months) =>
      DateTime(from.year, from.month - months, 1);
}
