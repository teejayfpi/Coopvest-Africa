/// Document Model - For KYC document submission
class Document {
  final String id;
  final String name;
  final String type; // 'id_card', 'passport', 'utility_bill', 'bank_statement', 'signature', 'other'
  final String status; // 'pending', 'approved', 'rejected'
  final String? fileUrl;
  final String? fileName;
  final DateTime uploadedAt;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? reviewedBy;

  Document({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.fileUrl,
    this.fileName,
    required this.uploadedAt,
    this.reviewedAt,
    this.reviewNotes,
    this.reviewedBy,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'other',
      status: json['status'] ?? 'pending',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'])
          : DateTime.now(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'])
          : null,
      reviewNotes: json['reviewNotes'],
      reviewedBy: json['reviewedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'uploadedAt': uploadedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
      'reviewedBy': reviewedBy,
    };
  }

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
}

/// Document Type options for upload
class DocumentType {
  final String value;
  final String label;
  final String icon;
  final String description;

  const DocumentType({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
  });

  static const List<DocumentType> allTypes = [
    DocumentType(
      value: 'id_card',
      label: 'National ID Card',
      icon: 'badge',
      description: 'Valid government-issued ID',
    ),
    DocumentType(
      value: 'passport',
      label: 'International Passport',
      icon: 'flight',
      description: 'Valid passport with photo',
    ),
    DocumentType(
      value: 'drivers_license',
      label: "Driver's License",
      icon: 'directions_car',
      description: "Valid driver's license",
    ),
    DocumentType(
      value: 'voters_card',
      label: "Voter's Card",
      icon: 'how_to_vote',
      description: 'INEC voter registration card',
    ),
    DocumentType(
      value: 'utility_bill',
      label: 'Utility Bill',
      icon: 'electric_bolt',
      description: 'Bill less than 3 months old',
    ),
    DocumentType(
      value: 'bank_statement',
      label: 'Bank Statement',
      icon: 'account_balance',
      description: 'Recent bank statement',
    ),
    DocumentType(
      value: 'signature',
      label: 'Signature Specimen',
      icon: 'draw',
      description: 'Your signature on white paper',
    ),
    DocumentType(
      value: 'other',
      label: 'Other Document',
      icon: 'description',
      description: 'Any other supporting document',
    ),
  ];

  static DocumentType getByValue(String value) {
    return allTypes.firstWhere(
      (type) => type.value == value,
      orElse: () => allTypes.last,
    );
  }
}

/// Upload response model
class DocumentUploadResponse {
  final bool success;
  final String? message;
  final Document? document;

  DocumentUploadResponse({
    required this.success,
    this.message,
    this.document,
  });

  factory DocumentUploadResponse.fromJson(Map<String, dynamic> json) {
    return DocumentUploadResponse(
      success: json['success'] ?? false,
      message: json['message'],
      document: json['document'] != null
          ? Document.fromJson(json['document'])
          : null,
    );
  }
}
