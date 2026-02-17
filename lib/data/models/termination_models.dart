import 'package:equatable/equatable.dart';

/// Membership Status Enum
/// Represents the various states a membership can be in
enum MembershipStatus {
  /// Active membership - full access to all services
  active,

  /// Termination request submitted - awaiting admin approval
  pendingTermination,

  /// Membership temporarily suspended
  suspended,

  /// Membership permanently terminated
  terminated,

  /// Inactive membership - no recent activity
  inactive,
}

/// Termination Exit Type
enum TerminationExitType {
  /// Permanent termination - account will be closed
  permanent,

  /// Temporary suspension - can be reinstated
  temporary,
}

/// Termination Reason Enum
enum TerminationReason {
  /// Financial difficulties
  financialDifficulties,

  /// No longer needs cooperative services
  noLongerNeedsServices,

  /// Relocating to another area
  relocating,

  /// Found alternative financial services
  foundAlternative,

  /// Dissatisfied with services
  dissatisfied,

  /// Personal reasons
  personalReasons,

  /// Health issues
  healthIssues,

  /// Employment change
  employmentChange,

  /// Other
  other,
}

/// Termination Eligibility Status
enum TerminationEligibilityStatus {
  /// Not checked yet
  unknown,

  /// Eligible for termination
  eligible,

  /// Not eligible - has financial obligations
  ineligible,

  /// Currently checking
  checking,

  /// Error during check
  error,
}

/// Membership Termination Request Model
class TerminationRequest extends Equatable {
  final String id;
  final String userId;
  final TerminationReason reason;
  final String? reasonDetails;
  final TerminationExitType exitType;
  final bool hasActiveLoan;
  final bool hasPendingRepayments;
  final bool hasActiveInvestments;
  final bool hasLockedSavings;
  final bool isGuarantorForActiveLoan;
  final String status; // pending, approved, rejected, cancelled
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final DateTime? effectiveDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TerminationRequest({
    required this.id,
    required this.userId,
    required this.reason,
    this.reasonDetails,
    required this.exitType,
    required this.hasActiveLoan,
    required this.hasPendingRepayments,
    required this.hasActiveInvestments,
    required this.hasLockedSavings,
    required this.isGuarantorForActiveLoan,
    required this.status,
    this.adminNotes,
    this.rejectionReason,
    required this.requestedAt,
    this.reviewedAt,
    this.effectiveDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if termination is pending approval
  bool get isPending => status == 'pending';

  /// Check if termination was approved
  bool get isApproved => status == 'approved';

  /// Check if termination was rejected
  bool get isRejected => status == 'rejected';

  /// Check if termination was cancelled
  bool get isCancelled => status == 'cancelled';

  /// Check if termination is effective
  bool get isEffective => status == 'approved' && effectiveDate != null;

  factory TerminationRequest.fromJson(Map<String, dynamic> json) {
    return TerminationRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      reason: _parseReason(json['reason'] as String),
      reasonDetails: json['reason_details'] as String?,
      exitType: _parseExitType(json['exit_type'] as String),
      hasActiveLoan: json['has_active_loan'] as bool? ?? false,
      hasPendingRepayments: json['has_pending_repayments'] as bool? ?? false,
      hasActiveInvestments: json['has_active_investments'] as bool? ?? false,
      hasLockedSavings: json['has_locked_savings'] as bool? ?? false,
      isGuarantorForActiveLoan: json['is_guarantor_for_active_loan'] as bool? ?? false,
      status: json['status'] as String,
      adminNotes: json['admin_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      effectiveDate: json['effective_date'] != null
          ? DateTime.parse(json['effective_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'reason': reason.toString().split('.').last,
      'reason_details': reasonDetails,
      'exit_type': exitType.toString().split('.').last,
      'has_active_loan': hasActiveLoan,
      'has_pending_repayments': hasPendingRepayments,
      'has_active_investments': hasActiveInvestments,
      'has_locked_savings': hasLockedSavings,
      'is_guarantor_for_active_loan': isGuarantorForActiveLoan,
      'status': status,
      'admin_notes': adminNotes,
      'rejection_reason': rejectionReason,
      'requested_at': requestedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'effective_date': effectiveDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static TerminationReason _parseReason(String reason) {
    switch (reason) {
      case 'financial_difficulties':
        return TerminationReason.financialDifficulties;
      case 'no_longer_needs_services':
        return TerminationReason.noLongerNeedsServices;
      case 'relocating':
        return TerminationReason.relocating;
      case 'found_alternative':
        return TerminationReason.foundAlternative;
      case 'dissatisfied':
        return TerminationReason.dissatisfied;
      case 'personal_reasons':
        return TerminationReason.personalReasons;
      case 'health_issues':
        return TerminationReason.healthIssues;
      case 'employment_change':
        return TerminationReason.employmentChange;
      default:
        return TerminationReason.other;
    }
  }

  static TerminationExitType _parseExitType(String exitType) {
    switch (exitType) {
      case 'permanent':
        return TerminationExitType.permanent;
      case 'temporary':
        return TerminationExitType.temporary;
      default:
        return TerminationExitType.permanent;
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        reason,
        reasonDetails,
        exitType,
        hasActiveLoan,
        hasPendingRepayments,
        hasActiveInvestments,
        hasLockedSavings,
        isGuarantorForActiveLoan,
        status,
        adminNotes,
        rejectionReason,
        requestedAt,
        reviewedAt,
        effectiveDate,
        createdAt,
        updatedAt,
      ];
}

/// Termination Eligibility Check Result
class TerminationEligibility extends Equatable {
  final TerminationEligibilityStatus status;
  final bool hasOutstandingLoanBalance;
  final bool hasActiveRepaymentObligations;
  final bool hasActiveInvestments;
  final bool hasLockedSavings;
  final bool isGuarantorForActiveLoan;
  final bool isEligible;
  final List<String> eligibilityErrors;
  final List<String> eligibilityWarnings;

  const TerminationEligibility({
    this.status = TerminationEligibilityStatus.unknown,
    this.hasOutstandingLoanBalance = false,
    this.hasActiveRepaymentObligations = false,
    this.hasActiveInvestments = false,
    this.hasLockedSavings = false,
    this.isGuarantorForActiveLoan = false,
  })  : isEligible = !hasOutstandingLoanBalance &&
            !hasActiveRepaymentObligations &&
            !hasActiveInvestments &&
            !hasLockedSavings &&
            !isGuarantorForActiveLoan,
        eligibilityErrors = const [],
        eligibilityWarnings = const [];

  const TerminationEligibility.withErrors({
    required this.status,
    required this.eligibilityErrors,
    this.eligibilityWarnings = const [],
    this.hasOutstandingLoanBalance = false,
    this.hasActiveRepaymentObligations = false,
    this.hasActiveInvestments = false,
    this.hasLockedSavings = false,
    this.isGuarantorForActiveLoan = false,
  })  : isEligible = false;

  factory TerminationEligibility.fromJson(Map<String, dynamic> json) {
    final status = _parseStatus(json['status'] as String? ?? 'unknown');
    final hasOutstandingLoanBalance =
        json['has_outstanding_loan_balance'] as bool? ?? false;
    final hasActiveRepaymentObligations =
        json['has_active_repayment_obligations'] as bool? ?? false;
    final hasActiveInvestments =
        json['has_active_investments'] as bool? ?? false;
    final hasLockedSavings = json['has_locked_savings'] as bool? ?? false;
    final isGuarantorForActiveLoan =
        json['is_guarantor_for_active_loan'] as bool? ?? false;

    final errors = <String>[];
    final warnings = <String>[];

    if (hasOutstandingLoanBalance) {
      errors.add('You have an outstanding loan balance that must be settled.');
    }
    if (hasActiveRepaymentObligations) {
      errors.add(
          'You have active repayment obligations that must be completed.');
    }
    if (hasActiveInvestments) {
      errors.add(
          'You have active investments that must be liquidated or matured.');
    }
    if (hasLockedSavings) {
      errors.add(
          'You have locked or restricted savings that are not accessible.');
    }
    if (isGuarantorForActiveLoan) {
      errors.add(
          'You are registered as a guarantor for an active loan and cannot terminate until released.');
    }

    return TerminationEligibility.withErrors(
      status: status,
      eligibilityErrors: errors,
      eligibilityWarnings: warnings,
      hasOutstandingLoanBalance: hasOutstandingLoanBalance,
      hasActiveRepaymentObligations: hasActiveRepaymentObligations,
      hasActiveInvestments: hasActiveInvestments,
      hasLockedSavings: hasLockedSavings,
      isGuarantorForActiveLoan: isGuarantorForActiveLoan,
    );
  }

  static TerminationEligibilityStatus _parseStatus(String status) {
    switch (status) {
      case 'eligible':
        return TerminationEligibilityStatus.eligible;
      case 'ineligible':
        return TerminationEligibilityStatus.ineligible;
      case 'checking':
        return TerminationEligibilityStatus.checking;
      case 'error':
        return TerminationEligibilityStatus.error;
      default:
        return TerminationEligibilityStatus.unknown;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toString().split('.').last,
      'has_outstanding_loan_balance': hasOutstandingLoanBalance,
      'has_active_repayment_obligations': hasActiveRepaymentObligations,
      'has_active_investments': hasActiveInvestments,
      'has_locked_savings': hasLockedSavings,
      'is_guarantor_for_active_loan': isGuarantorForActiveLoan,
      'is_eligible': isEligible,
      'eligibility_errors': eligibilityErrors,
      'eligibility_warnings': eligibilityWarnings,
    };
  }

  @override
  List<Object?> get props => [
        status,
        hasOutstandingLoanBalance,
        hasActiveRepaymentObligations,
        hasActiveInvestments,
        hasLockedSavings,
        isGuarantorForActiveLoan,
        isEligible,
        eligibilityErrors,
        eligibilityWarnings,
      ];
}

/// Termination Request Form Data
class TerminationFormData extends Equatable {
  final TerminationReason reason;
  final String? reasonDetails;
  final TerminationExitType exitType;
  final bool acknowledgedFinancialObligations;
  final bool acknowledgedServiceTermination;
  final bool acknowledgedGuarantorObligations;

  const TerminationFormData({
    required this.reason,
    this.reasonDetails,
    required this.exitType,
    required this.acknowledgedFinancialObligations,
    required this.acknowledgedServiceTermination,
    required this.acknowledgedGuarantorObligations,
  });

  /// Validate form is complete for submission
  bool get isValid {
    return acknowledgedFinancialObligations &&
        acknowledgedServiceTermination &&
        acknowledgedGuarantorObligations;
  }

  Map<String, dynamic> toJson() {
    return {
      'reason': reason.toString().split('.').last,
      'reason_details': reasonDetails,
      'exit_type': exitType.toString().split('.').last,
      'acknowledged_financial_obligations': acknowledgedFinancialObligations,
      'acknowledged_service_termination': acknowledgedServiceTermination,
      'acknowledged_guarantor_obligations': acknowledgedGuarantorObligations,
    };
  }

  @override
  List<Object?> get props => [
        reason,
        reasonDetails,
        exitType,
        acknowledgedFinancialObligations,
        acknowledgedServiceTermination,
        acknowledgedGuarantorObligations,
      ];
}

/// Termination State for Provider
class TerminationState extends Equatable {
  final TerminationEligibility? eligibility;
  final TerminationRequest? currentRequest;
  final List<TerminationRequest> requestHistory;
  final String? error;
  final bool isLoading;
  final bool isSubmitting;
  final TerminationFormData? formData;

  const TerminationState({
    this.eligibility,
    this.currentRequest,
    this.requestHistory = const [],
    this.error,
    this.isLoading = false,
    this.isSubmitting = false,
    this.formData,
  });

  bool get isChecking => isLoading;
  bool get isSubmittingForm => isSubmitting;
  bool get hasPendingRequest =>
      currentRequest != null && currentRequest!.isPending;

  TerminationState copyWith({
    TerminationEligibility? eligibility,
    TerminationRequest? currentRequest,
    List<TerminationRequest>? requestHistory,
    String? error,
    bool? isLoading,
    bool? isSubmitting,
    TerminationFormData? formData,
  }) {
    return TerminationState(
      eligibility: eligibility ?? this.eligibility,
      currentRequest: currentRequest ?? this.currentRequest,
      requestHistory: requestHistory ?? this.requestHistory,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      formData: formData ?? this.formData,
    );
  }

  @override
  List<Object?> get props => [
        eligibility,
        currentRequest,
        requestHistory,
        error,
        isLoading,
        isSubmitting,
        formData,
      ];
}

/// Get human-readable reason text
String getTerminationReasonText(TerminationReason reason) {
  switch (reason) {
    case TerminationReason.financialDifficulties:
      return 'Financial difficulties';
    case TerminationReason.noLongerNeedsServices:
      return 'No longer need cooperative services';
    case TerminationReason.relocating:
      return 'Relocating to another area';
    case TerminationReason.foundAlternative:
      return 'Found alternative financial services';
    case TerminationReason.dissatisfied:
      return 'Dissatisfied with services';
    case TerminationReason.personalReasons:
      return 'Personal reasons';
    case TerminationReason.healthIssues:
      return 'Health issues';
    case TerminationReason.employmentChange:
      return 'Employment change';
    case TerminationReason.other:
      return 'Other';
  }
}

/// Get human-readable membership status text
String getMembershipStatusText(String status) {
  switch (status) {
    case 'active':
      return 'Active';
    case 'pending_termination':
      return 'Pending Termination';
    case 'suspended':
      return 'Suspended';
    case 'terminated':
      return 'Terminated';
    case 'inactive':
      return 'Inactive';
    default:
      return status;
  }
}

/// Get membership status color
/// Returns a hex color code based on status
String getMembershipStatusColor(String status) {
  switch (status) {
    case 'active':
      return '#4CAF50'; // Green
    case 'pending_termination':
      return '#FF9800'; // Orange
    case 'suspended':
      return '#F44336'; // Red
    case 'terminated':
      return '#9C27B0'; // Purple
    case 'inactive':
      return '#9E9E9E'; // Gray
    default:
      return '#9E9E9E';
  }
}
