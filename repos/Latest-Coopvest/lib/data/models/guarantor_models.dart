/// Guarantor Request Model - Track pending guarantor requests
class GuarantorRequest {
  final String id;
  final String loanId;
  final String loanType;
  final double loanAmount;
  final String memberName;
  final String memberPhone;
  final String memberId;
  final DateTime requestedAt;
  final DateTime? expiresAt;
  final String status; // 'pending', 'accepted', 'declined', 'expired'
  final int requiredGuarantors;
  final int currentGuarantors;

  GuarantorRequest({
    required this.id,
    required this.loanId,
    required this.loanType,
    required this.loanAmount,
    required this.memberName,
    required this.memberPhone,
    required this.memberId,
    required this.requestedAt,
    this.expiresAt,
    required this.status,
    required this.requiredGuarantors,
    required this.currentGuarantors,
  });

  factory GuarantorRequest.fromJson(Map<String, dynamic> json) {
    return GuarantorRequest(
      id: json['id'] ?? '',
      loanId: json['loanId'] ?? '',
      loanType: json['loanType'] ?? '',
      loanAmount: (json['loanAmount'] ?? 0).toDouble(),
      memberName: json['memberName'] ?? '',
      memberPhone: json['memberPhone'] ?? '',
      memberId: json['memberId'] ?? '',
      requestedAt: json['requestedAt'] != null
          ? DateTime.parse(json['requestedAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      status: json['status'] ?? 'pending',
      requiredGuarantors: json['requiredGuarantors'] ?? 2,
      currentGuarantors: json['currentGuarantors'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loanId': loanId,
      'loanType': loanType,
      'loanAmount': loanAmount,
      'memberName': memberName,
      'memberPhone': memberPhone,
      'memberId': memberId,
      'requestedAt': requestedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'status': status,
      'requiredGuarantors': requiredGuarantors,
      'currentGuarantors': currentGuarantors,
    };
  }

  int get remainingGuarantors => requiredGuarantors - currentGuarantors;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  double get progress => currentGuarantors / requiredGuarantors;
}

/// My Guaranteed Loans - Loans where user is a guarantor
class GuaranteedLoan {
  final String id;
  final String loanId;
  final String loanType;
  final double loanAmount;
  final String borrowerName;
  final DateTime guaranteedAt;
  final String status; // 'active', 'completed', 'defaulted'

  GuaranteedLoan({
    required this.id,
    required this.loanId,
    required this.loanType,
    required this.loanAmount,
    required this.borrowerName,
    required this.guaranteedAt,
    required this.status,
  });

  factory GuaranteedLoan.fromJson(Map<String, dynamic> json) {
    return GuaranteedLoan(
      id: json['id'] ?? '',
      loanId: json['loanId'] ?? '',
      loanType: json['loanType'] ?? '',
      loanAmount: (json['loanAmount'] ?? 0).toDouble(),
      borrowerName: json['borrowerName'] ?? '',
      guaranteedAt: json['guaranteedAt'] != null
          ? DateTime.parse(json['guaranteedAt'])
          : DateTime.now(),
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loanId': loanId,
      'loanType': loanType,
      'loanAmount': loanAmount,
      'borrowerName': borrowerName,
      'guaranteedAt': guaranteedAt.toIso8601String(),
      'status': status,
    };
  }
}

/// Guarantor Statistics
class GuarantorStats {
  final int pendingRequests;
  final int acceptedGuarantees;
  final int declinedRequests;
  final double totalGuaranteedAmount;

  GuarantorStats({
    required this.pendingRequests,
    required this.acceptedGuarantees,
    required this.declinedRequests,
    required this.totalGuaranteedAmount,
  });

  factory GuarantorStats.fromJson(Map<String, dynamic> json) {
    return GuarantorStats(
      pendingRequests: json['pendingRequests'] ?? 0,
      acceptedGuarantees: json['acceptedGuarantees'] ?? 0,
      declinedRequests: json['declinedRequests'] ?? 0,
      totalGuaranteedAmount: (json['totalGuaranteedAmount'] ?? 0).toDouble(),
    );
  }
}
