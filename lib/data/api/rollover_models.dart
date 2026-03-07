// Standalone models file


class RolloverEligibility {
  final bool isEligible;
  final String? reason;
  final double? repaymentPercentage;

  RolloverEligibility({
    required this.isEligible,
    this.reason,
    this.repaymentPercentage,
  });

  factory RolloverEligibility.fromJson(Map<String, dynamic> json) {
    return RolloverEligibility(
      isEligible: json['isEligible'] ?? false,
      reason: json['reason'],
      repaymentPercentage: (json['repaymentPercentage'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'isEligible': isEligible,
    'reason': reason,
    'repaymentPercentage': repaymentPercentage,
  };
}

class LoanRollover {
  final String id;
  final String loanId;
  final double amount;
  final String status;
  final DateTime createdAt;

  LoanRollover({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory LoanRollover.fromJson(Map<String, dynamic> json) {
    return LoanRollover(
      id: json['id'] ?? '',
      loanId: json['loanId'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'loanId': loanId,
    'amount': amount,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}

class RolloverGuarantor {
  final String id;
  final String name;
  final String phone;
  final String status;

  RolloverGuarantor({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
  });

  factory RolloverGuarantor.fromJson(Map<String, dynamic> json) {
    return RolloverGuarantor(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'status': status,
  };
}
