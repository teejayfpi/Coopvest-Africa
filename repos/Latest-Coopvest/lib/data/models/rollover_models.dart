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
  final bool hasMinimum50PercentRepayment;
  final bool hasConsistentSavings;
  final List<String> eligibilityErrors;
  final List<String> eligibilityWarnings;
  final double repaymentPercentage;
  final int consecutiveSavingsMonths;
  final bool isEligible;

  const RolloverEligibility({
    this.status = RolloverEligibilityStatus.unknown,
    this.hasMinimum50PercentRepayment = false,
    this.hasConsistentSavings = false,
    this.eligibilityErrors = const [],
    this.eligibilityWarnings = const [],
    this.repaymentPercentage = 0,
    this.consecutiveSavingsMonths = 0,
  }) : isEligible = hasMinimum50PercentRepayment && hasConsistentSavings;

  factory RolloverEligibility.fromJson(Map<String, dynamic> json) {
    return RolloverEligibility(
      status: _parseEligibilityStatus(json['status'] as String? ?? 'unknown'),
      hasMinimum50PercentRepayment:
          json['has_minimum_50_percent_repayment'] as bool? ?? false,
      hasConsistentSavings: json['has_consistent_savings'] as bool? ?? false,
      eligibilityErrors: (json['eligibility_errors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      eligibilityWarnings: (json['eligibility_warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      repaymentPercentage: (json['repayment_percentage'] as num?)?.toDouble() ?? 0,
      consecutiveSavingsMonths: json['consecutive_savings_months'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toString().split('.').last,
      'has_minimum_50_percent_repayment': hasMinimum50PercentRepayment,
      'has_consistent_savings': hasConsistentSavings,
      'eligibility_errors': eligibilityErrors,
      'eligibility_warnings': eligibilityWarnings,
      'repayment_percentage': repaymentPercentage,
      'consecutive_savings_months': consecutiveSavingsMonths,
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
        hasMinimum50PercentRepayment,
        hasConsistentSavings,
        eligibilityErrors,
        eligibilityWarnings,
        repaymentPercentage,
        consecutiveSavingsMonths,
        isEligible,
      ];
}

/// Rollover State for Provider
class RolloverState extends Equatable {
  final RolloverStatus status;
  final LoanRollover? currentRollover;
  final List<LoanRollover> rolloverHistory;
  final RolloverEligibility? eligibility;
  final List<RolloverGuarantor> guarantors;
  final String? error;
  final bool isLoading;

  const RolloverState({
    this.status = RolloverStatus.initial,
    this.currentRollover,
    this.rolloverHistory = const [],
    this.eligibility,
    this.guarantors = const [],
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
    String? error,
    bool? isLoading,
  }) {
    return RolloverState(
      status: status ?? this.status,
      currentRollover: currentRollover ?? this.currentRollover,
      rolloverHistory: rolloverHistory ?? this.rolloverHistory,
      eligibility: eligibility ?? this.eligibility,
      guarantors: guarantors ?? this.guarantors,
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
        error,
        isLoading,
      ];
}
