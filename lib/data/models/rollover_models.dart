import 'package:equatable/equatable.dart';

/// Rollover Status Enum
enum RolloverStatus {
  /// Initial state - no rollover request
  initial,

  /// Checking eligibility
  checkingEligibility,

  /// Member has requested rollover
  pending,

  /// All guarantors have consented
  awaitingAdminApproval,

  /// Admin has approved the rollover
  approved,

  /// Admin has rejected the rollover
  rejected,

  /// Rollover loan has been created and is active
  completed,

  /// Member cancelled the rollover request
  cancelled,

  /// Rollover failed due to system error
  failed,
}

/// Guarantor Consent Status Enum
enum GuarantorConsentStatus {
  /// Not yet invited
  pending,

  /// Invitation sent, awaiting response
  invited,

  /// Guarantor accepted
  accepted,

  /// Guarantor declined
  declined,

  /// Invitation expired
  expired,
}

/// Rollover Eligibility Status
enum RolloverEligibilityStatus {
  /// Not checked yet
  unknown,

  /// Loan is eligible for rollover
  eligible,

  /// Loan is not eligible
  ineligible,

  /// Currently checking
  checking,

  /// Error during check
  error,
}

/// Main Rollover Request Model
class LoanRollover extends Equatable {
  final String id;
  final String originalLoanId;
  final String? newLoanId;
  final String memberId;
  final String memberName;
  final String memberPhone;

  // Financial Details
  final double originalPrincipal;
  final double outstandingBalance;
  final double totalRepaid;
  final double repaymentPercentage;

  // New Loan Details (after rollover)
  final int newTenure;
  final double newInterestRate;
  final double newMonthlyRepayment;
  final double newTotalRepayment;

  // Status Tracking
  final RolloverStatus status;
  final String? statusReason;

  // Timestamps
  final DateTime requestedAt;
  final DateTime? guarantorConsentDeadline;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  // Metadata
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LoanRollover({
    required this.id,
    required this.originalLoanId,
    this.newLoanId,
    required this.memberId,
    required this.memberName,
    required this.memberPhone,
    required this.originalPrincipal,
    required this.outstandingBalance,
    required this.totalRepaid,
    required this.repaymentPercentage,
    required this.newTenure,
    required this.newInterestRate,
    required this.newMonthlyRepayment,
    required this.newTotalRepayment,
    required this.status,
    this.statusReason,
    required this.requestedAt,
    this.guarantorConsentDeadline,
    this.approvedAt,
    this.rejectedAt,
    this.completedAt,
    this.cancelledAt,
    this.adminNotes,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if rollover is eligible
  bool get isEligible =>
      repaymentPercentage >= 50 &&
      status == RolloverStatus.pending;

  /// Check if all guarantors have consented
  bool get allGuarantorsConsented =>
      guarantors.every((g) => g.status == GuarantorConsentStatus.accepted);

  /// Check if any guarantor declined
  bool get hasGuarantorDeclined =>
      guarantors.any((g) => g.status == GuarantorConsentStatus.declined);

  /// List of guarantors (populated after fetching)
  final List<RolloverGuarantor> guarantors = const [];

  factory LoanRollover.fromJson(Map<String, dynamic> json) {
    return LoanRollover(
      id: json['id'] as String,
      originalLoanId: json['original_loan_id'] as String,
      newLoanId: json['new_loan_id'] as String?,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String,
      memberPhone: json['member_phone'] as String,
      originalPrincipal: (json['original_principal'] as num).toDouble(),
      outstandingBalance: (json['outstanding_balance'] as num).toDouble(),
      totalRepaid: (json['total_repaid'] as num).toDouble(),
      repaymentPercentage: (json['repayment_percentage'] as num).toDouble(),
      newTenure: json['new_tenure'] as int,
      newInterestRate: (json['new_interest_rate'] as num).toDouble(),
      newMonthlyRepayment: (json['new_monthly_repayment'] as num).toDouble(),
      newTotalRepayment: (json['new_total_repayment'] as num).toDouble(),
      status: _parseRolloverStatus(json['status'] as String),
      statusReason: json['status_reason'] as String?,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      guarantorConsentDeadline: json['guarantor_consent_deadline'] != null
          ? DateTime.parse(json['guarantor_consent_deadline'] as String)
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      adminNotes: json['admin_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_loan_id': originalLoanId,
      'new_loan_id': newLoanId,
      'member_id': memberId,
      'member_name': memberName,
      'member_phone': memberPhone,
      'original_principal': originalPrincipal,
      'outstanding_balance': outstandingBalance,
      'total_repaid': totalRepaid,
      'repayment_percentage': repaymentPercentage,
      'new_tenure': newTenure,
      'new_interest_rate': newInterestRate,
      'new_monthly_repayment': newMonthlyRepayment,
      'new_total_repayment': newTotalRepayment,
      'status': status.toString().split('.').last,
      'status_reason': statusReason,
      'requested_at': requestedAt.toIso8601String(),
      'guarantor_consent_deadline': guarantorConsentDeadline?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'admin_notes': adminNotes,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LoanRollover copyWith({
    String? id,
    String? originalLoanId,
    String? newLoanId,
    String? memberId,
    String? memberName,
    String? memberPhone,
    double? originalPrincipal,
    double? outstandingBalance,
    double? totalRepaid,
    double? repaymentPercentage,
    int? newTenure,
    double? newInterestRate,
    double? newMonthlyRepayment,
    double? newTotalRepayment,
    RolloverStatus? status,
    String? statusReason,
    DateTime? requestedAt,
    DateTime? guarantorConsentDeadline,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? adminNotes,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LoanRollover(
      id: id ?? this.id,
      originalLoanId: originalLoanId ?? this.originalLoanId,
      newLoanId: newLoanId ?? this.newLoanId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      memberPhone: memberPhone ?? this.memberPhone,
      originalPrincipal: originalPrincipal ?? this.originalPrincipal,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      totalRepaid: totalRepaid ?? this.totalRepaid,
      repaymentPercentage: repaymentPercentage ?? this.repaymentPercentage,
      newTenure: newTenure ?? this.newTenure,
      newInterestRate: newInterestRate ?? this.newInterestRate,
      newMonthlyRepayment: newMonthlyRepayment ?? this.newMonthlyRepayment,
      newTotalRepayment: newTotalRepayment ?? this.newTotalRepayment,
      status: status ?? this.status,
      statusReason: statusReason ?? this.statusReason,
      requestedAt: requestedAt ?? this.requestedAt,
      guarantorConsentDeadline:
          guarantorConsentDeadline ?? this.guarantorConsentDeadline,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static RolloverStatus _parseRolloverStatus(String status) {
    switch (status) {
      case 'initial':
        return RolloverStatus.initial;
      case 'pending':
        return RolloverStatus.pending;
      case 'awaiting_admin_approval':
        return RolloverStatus.awaitingAdminApproval;
      case 'approved':
        return RolloverStatus.approved;
      case 'rejected':
        return RolloverStatus.rejected;
      case 'completed':
        return RolloverStatus.completed;
      case 'cancelled':
        return RolloverStatus.cancelled;
      case 'failed':
        return RolloverStatus.failed;
      default:
        return RolloverStatus.initial;
    }
  }

  @override
  List<Object?> get props => [
        id,
        originalLoanId,
        newLoanId,
        memberId,
        memberName,
        memberPhone,
        originalPrincipal,
        outstandingBalance,
        totalRepaid,
        repaymentPercentage,
        newTenure,
        newInterestRate,
        newMonthlyRepayment,
        newTotalRepayment,
        status,
        statusReason,
        requestedAt,
        guarantorConsentDeadline,
        approvedAt,
        rejectedAt,
        completedAt,
        cancelledAt,
        adminNotes,
        rejectionReason,
        createdAt,
        updatedAt,
      ];
}

/// Rollover Guarantor Model
class RolloverGuarantor extends Equatable {
  final String id;
  final String rolloverId;
  final String guarantorId;
  final String guarantorName;
  final String guarantorPhone;
  final GuarantorConsentStatus status;
  final String? declineReason;
  final DateTime? invitedAt;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RolloverGuarantor({
    required this.id,
    required this.rolloverId,
    required this.guarantorId,
    required this.guarantorName,
    required this.guarantorPhone,
    required this.status,
    this.declineReason,
    this.invitedAt,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RolloverGuarantor.fromJson(Map<String, dynamic> json) {
    return RolloverGuarantor(
      id: json['id'] as String,
      rolloverId: json['rollover_id'] as String,
      guarantorId: json['guarantor_id'] as String,
      guarantorName: json['guarantor_name'] as String,
      guarantorPhone: json['guarantor_phone'] as String,
      status: _parseConsentStatus(json['status'] as String),
      declineReason: json['decline_reason'] as String?,
      invitedAt: json['invited_at'] != null
          ? DateTime.parse(json['invited_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rollover_id': rolloverId,
      'guarantor_id': guarantorId,
      'guarantor_name': guarantorName,
      'guarantor_phone': guarantorPhone,
      'status': status.toString().split('.').last,
      'decline_reason': declineReason,
      'invited_at': invitedAt?.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static GuarantorConsentStatus _parseConsentStatus(String status) {
    switch (status) {
      case 'pending':
        return GuarantorConsentStatus.pending;
      case 'invited':
        return GuarantorConsentStatus.invited;
      case 'accepted':
        return GuarantorConsentStatus.accepted;
      case 'declined':
        return GuarantorConsentStatus.declined;
      case 'expired':
        return GuarantorConsentStatus.expired;
      default:
        return GuarantorConsentStatus.pending;
    }
  }

  @override
  List<Object?> get props => [
        id,
        rolloverId,
        guarantorId,
        guarantorName,
        guarantorPhone,
        status,
        declineReason,
        invitedAt,
        respondedAt,
        createdAt,
        updatedAt,
      ];
}

/// Rollover Eligibility Check Result
class RolloverEligibility extends Equatable {
  final RolloverEligibilityStatus status;

  /// Whether the member may REQUEST a rollover. Never an approval.
  final bool isEligible;

  /// The threshold in force, read from the backend so the business can change
  /// it (70% today) without an app release.
  final double minPrincipalPercentage;

  /// Percentage of the ORIGINAL PRINCIPAL repaid — not of the total amount
  /// paid. Interest, fees and penalties inflate "amount paid", so a member
  /// could otherwise appear eligible without having repaid 70% of what they
  /// actually borrowed.
  final double repaymentPercentage;

  /// The five rules, reported individually so the screen can show a checklist.
  final bool hasMinimumPrincipalRepaid;
  final bool hasNoSeriousDefault;
  final bool accountInGoodStanding;
  final bool withinRolloverLimit;
  final bool loanIsActive;

  final int rolloverCount;
  final int maxConsecutiveRollovers;

  /// Human-readable reasons the member cannot roll over yet.
  final List<String> blockers;

  /// The loan's human reference (e.g. LN-000123), needed to reload terms.
  final String? loanRef;

  /// Principal position: original, repaid and outstanding.
  final double originalPrincipal;
  final double principalRepaid;
  final double outstandingPrincipal;
  final double outstandingBalance;

  const RolloverEligibility({
    this.status = RolloverEligibilityStatus.unknown,
    this.isEligible = false,
    this.minPrincipalPercentage = 70,
    this.repaymentPercentage = 0,
    this.hasMinimumPrincipalRepaid = false,
    this.hasNoSeriousDefault = false,
    this.accountInGoodStanding = false,
    this.withinRolloverLimit = false,
    this.loanIsActive = false,
    this.rolloverCount = 0,
    this.maxConsecutiveRollovers = 2,
    this.blockers = const [],
    this.loanRef,
    this.originalPrincipal = 0,
    this.principalRepaid = 0,
    this.outstandingPrincipal = 0,
    this.outstandingBalance = 0,
  });

  /// How much principal is still outstanding before the member qualifies.
  double get principalStillRequired {
    final target = originalPrincipal * (minPrincipalPercentage / 100);
    return (target - principalRepaid).clamp(0, double.infinity).toDouble();
  }

  /// 0..1 progress toward the threshold, for the progress bar.
  double get thresholdProgress {
    final target = originalPrincipal * (minPrincipalPercentage / 100);
    if (target <= 0) return 0;
    return (principalRepaid / target).clamp(0, 1).toDouble();
  }

  factory RolloverEligibility.fromJson(Map<String, dynamic> json) {
    final position = (json['position'] as Map<String, dynamic>?) ?? const {};
    double num_(dynamic v) => (v as num?)?.toDouble() ?? 0;

    return RolloverEligibility(
      status: _parseEligibilityStatus(json['status'] as String? ?? 'unknown'),
      isEligible: json['is_eligible'] as bool? ?? false,
      minPrincipalPercentage: num_(json['min_principal_percentage'] ?? 70),
      repaymentPercentage: num_(json['repayment_percentage']),
      hasMinimumPrincipalRepaid: json['has_minimum_principal_repaid'] as bool? ?? false,
      hasNoSeriousDefault: json['has_no_serious_default'] as bool? ?? false,
      accountInGoodStanding: json['account_in_good_standing'] as bool? ?? false,
      withinRolloverLimit: json['within_rollover_limit'] as bool? ?? false,
      loanIsActive: json['loan_is_active'] as bool? ?? true,
      rolloverCount: (json['rollover_count'] as num?)?.toInt() ?? 0,
      maxConsecutiveRollovers: (json['max_consecutive_rollovers'] as num?)?.toInt() ?? 2,
      // Blockers arrive as objects with a message; keep the messages.
      blockers: (json['blockers'] as List<dynamic>?)
              ?.map((b) => b is Map ? (b['message']?.toString() ?? '') : b.toString())
              .where((m) => m.isNotEmpty)
              .toList() ??
          const [],
      loanRef: position['loan_ref']?.toString(),
      originalPrincipal: num_(position['original_principal']),
      principalRepaid: num_(position['principal_repaid']),
      outstandingPrincipal: num_(position['outstanding_principal']),
      outstandingBalance: num_(position['outstanding_balance']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toString().split('.').last,
      'is_eligible': isEligible,
      'min_principal_percentage': minPrincipalPercentage,
      'repayment_percentage': repaymentPercentage,
      'has_minimum_principal_repaid': hasMinimumPrincipalRepaid,
      'has_no_serious_default': hasNoSeriousDefault,
      'account_in_good_standing': accountInGoodStanding,
      'within_rollover_limit': withinRolloverLimit,
      'rollover_count': rolloverCount,
      'max_consecutive_rollovers': maxConsecutiveRollovers,
      'blockers': blockers,
      'original_principal': originalPrincipal,
      'principal_repaid': principalRepaid,
      'outstanding_principal': outstandingPrincipal,
      'outstanding_balance': outstandingBalance,
    };
  }

  static RolloverEligibilityStatus _parseEligibilityStatus(String status) {
    switch (status) {
      case 'eligible':
        return RolloverEligibilityStatus.eligible;
      case 'ineligible':
        return RolloverEligibilityStatus.ineligible;
      case 'checking':
        return RolloverEligibilityStatus.checking;
      case 'error':
        return RolloverEligibilityStatus.error;
      default:
        return RolloverEligibilityStatus.unknown;
    }
  }

  @override
  List<Object?> get props => [
        status,
        isEligible,
        minPrincipalPercentage,
        repaymentPercentage,
        hasMinimumPrincipalRepaid,
        hasNoSeriousDefault,
        accountInGoodStanding,
        withinRolloverLimit,
        rolloverCount,
        blockers,
        loanRef,
        originalPrincipal,
        principalRepaid,
        outstandingPrincipal,
        outstandingBalance,
      ];
}

/// Rollover State for Provider
class RolloverState extends Equatable {
  final RolloverStatus status;
  final LoanRollover? currentRollover;
  final List<LoanRollover> rolloverHistory;
  final RolloverEligibility? eligibility;
  final List<RolloverGuarantor> guarantors;
  final List<RolloverGuarantor> selectedGuarantors;
  final int? newTenure;
  /// The refinancing calculation for the current amount/tenure selection.
  final RolloverTerms? rolloverTerms;
  /// The amount the member is asking for, kept so a tenure change can
  /// recompute the terms.
  final double? rolloverAmount;
  final String? error;
  final bool isLoading;

  const RolloverState({
    this.status = RolloverStatus.initial,
    this.currentRollover,
    this.rolloverHistory = const [],
    this.eligibility,
    this.guarantors = const [],
    this.selectedGuarantors = const [],
    this.newTenure,
    this.rolloverTerms,
    this.rolloverAmount,
    this.error,
    this.isLoading = false,
  });

  bool get isChecking => isLoading || status == RolloverStatus.initial;
  bool get isProcessing =>
      isLoading ||
      status == RolloverStatus.pending ||
      status == RolloverStatus.awaitingAdminApproval;

  RolloverState copyWith({
    RolloverStatus? status,
    LoanRollover? currentRollover,
    List<LoanRollover>? rolloverHistory,
    RolloverEligibility? eligibility,
    List<RolloverGuarantor>? guarantors,
    List<RolloverGuarantor>? selectedGuarantors,
    int? newTenure,
    RolloverTerms? rolloverTerms,
    double? rolloverAmount,
    String? error,
    bool? isLoading,
  }) {
    return RolloverState(
      status: status ?? this.status,
      currentRollover: currentRollover ?? this.currentRollover,
      rolloverHistory: rolloverHistory ?? this.rolloverHistory,
      eligibility: eligibility ?? this.eligibility,
      guarantors: guarantors ?? this.guarantors,
      selectedGuarantors: selectedGuarantors ?? this.selectedGuarantors,
      newTenure: newTenure ?? this.newTenure,
      rolloverTerms: rolloverTerms ?? this.rolloverTerms,
      rolloverAmount: rolloverAmount ?? this.rolloverAmount,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentRollover,
        rolloverHistory,
        eligibility,
        guarantors,
        selectedGuarantors,
        newTenure,
        error,
        isLoading,
      ];
}

/// The refinancing calculation for a rollover.
///
/// The member must see this before accepting, because the new loan does NOT pay
/// out in full: the outstanding balance is settled from it, and only the
/// difference is disbursed.
///
///   new loan - existing balance settled = net amount to the member
class RolloverTerms extends Equatable {
  final bool valid;
  final List<String> errors;

  /// The ceiling for the new loan: savings x the product multiplier.
  final double maximumEligible;
  final double loanMultiplier;
  final double memberSavings;

  final double requestedAmount;
  final double interestRate;
  final int newTenureMonths;
  final double totalRepayment;
  final double monthlyRepayment;

  /// The breakdown: new loan, what it settles, and what the member receives.
  final double settlementAmount;
  final double netAmountToMember;

  const RolloverTerms({
    this.valid = false,
    this.errors = const [],
    this.maximumEligible = 0,
    this.loanMultiplier = 3,
    this.memberSavings = 0,
    this.requestedAmount = 0,
    this.interestRate = 0,
    this.newTenureMonths = 12,
    this.totalRepayment = 0,
    this.monthlyRepayment = 0,
    this.settlementAmount = 0,
    this.netAmountToMember = 0,
  });

  factory RolloverTerms.fromJson(Map<String, dynamic> json) {
    final settlement = (json['settlement'] as Map<String, dynamic>?) ?? const {};
    double num_(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return RolloverTerms(
      valid: json['valid'] as bool? ?? false,
      // Errors arrive as objects with a message.
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e is Map ? (e['message']?.toString() ?? '') : e.toString())
              .where((m) => m.isNotEmpty)
              .toList() ??
          const [],
      maximumEligible: num_(json['maximum_eligible']),
      loanMultiplier: num_(json['loan_multiplier'] ?? 3),
      memberSavings: num_(json['member_savings']),
      requestedAmount: num_(json['requested_amount']),
      interestRate: num_(json['interest_rate']),
      newTenureMonths: (json['new_tenure_months'] as num?)?.toInt() ?? 12,
      totalRepayment: num_(json['total_repayment']),
      monthlyRepayment: num_(json['monthly_repayment']),
      settlementAmount: num_(settlement['existing_balance_settled']),
      netAmountToMember: num_(settlement['net_amount_to_member']),
    );
  }

  @override
  List<Object?> get props => [
        valid, errors, maximumEligible, requestedAmount, newTenureMonths,
        totalRepayment, monthlyRepayment, settlementAmount, netAmountToMember,
      ];
}
