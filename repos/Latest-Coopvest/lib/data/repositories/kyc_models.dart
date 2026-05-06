// Standalone models file


class KYCSubmission {
  final String id;
  final String userId;
  final String status;
  final DateTime submittedAt;

  KYCSubmission({
    required this.id,
    required this.userId,
    required this.status,
    required this.submittedAt,
  });

  factory KYCSubmission.fromJson(Map<String, dynamic> json) {
    return KYCSubmission(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      status: json['status'] ?? 'pending',
      submittedAt: DateTime.parse(json['submittedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'status': status,
    'submittedAt': submittedAt.toIso8601String(),
  };
}

class Organization {
  final String id;
  final String name;
  final String? logo;

  Organization({
    required this.id,
    required this.name,
    this.logo,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logo': logo,
  };
}
