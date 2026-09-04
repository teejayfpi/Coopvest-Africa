import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// KYC Submission Model
class KYCSubmission extends Equatable {
  // Personal Information
  final String? dateOfBirth;
  final String? gender;

  // Employment Details
  final String employmentType;
  final String? organizationId;
  final String? organizationName;
  final String jobTitle;
  final String monthlyIncomeRange;
  // Extra employment fields (aligned with registration onboarding)
  final String? occupation;
  final String? employerName;
  final String? workAddress;
  final String? yearsOfEmployment;

  // Address
  final String residentialAddress;
  final String? city;
  final String? state;
  final String? lga;
  final String? country;

  // ID Document
  final String idType;
  final String? idNumber;
  final String? idPhotoPath;
  final String? staffId;

  // Selfie
  final String? selfiePhotoPath;

  // Next of Kin (aligned with registration onboarding)
  final String? nokName;
  final String? nokRelationship;
  final String? nokPhone;
  final String? nokAddress;

  // Bank Information
  final String? bankName;
  final String? bankCode;
  final String? accountNumber;
  final String? accountName;
  final String? accountType;
  final String? bvn;

  // Contribution channel — 'direct_deposit' or 'salary_deduction'. Chosen at
  // the start of KYC; salary deduction additionally requires the employment
  // section, direct deposit skips it.
  final String contributionType;

  // Status
  final String status; // pending, submitted, approved, rejected
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? rejectionReason;

  const KYCSubmission({
    this.dateOfBirth,
    this.gender,
    this.employmentType = '',
    this.organizationId,
    this.organizationName,
    this.jobTitle = '',
    this.monthlyIncomeRange = '',
    this.occupation,
    this.employerName,
    this.workAddress,
    this.yearsOfEmployment,
    this.residentialAddress = '',
    this.city,
    this.state,
    this.lga,
    this.country,
    this.idType = '',
    this.idNumber,
    this.idPhotoPath,
    this.staffId,
    this.selfiePhotoPath,
    this.nokName,
    this.nokRelationship,
    this.nokPhone,
    this.nokAddress,
    this.bankName,
    this.bankCode,
    this.accountNumber,
    this.accountName,
    this.accountType,
    this.bvn,
    this.contributionType = 'direct_deposit',
    this.status = 'draft',
    this.submittedAt,
    this.approvedAt,
    this.rejectionReason,
  });

  /// True when the member contributes via employer payroll deduction — the
  /// employment section is required for them and skipped otherwise.
  bool get isSalaryDeduction => contributionType == 'salary_deduction';

  Map<String, dynamic> toJson() {
    return {
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'employment_type': employmentType,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'job_title': jobTitle,
      'monthly_income_range': monthlyIncomeRange,
      'occupation': occupation,
      'employer_name': employerName,
      'work_address': workAddress,
      'years_of_employment': yearsOfEmployment,
      'residential_address': residentialAddress,
      'city': city,
      'state': state,
      'lga': lga,
      'country': country ?? 'Nigeria',
      'id_type': idType,
      'id_number': idNumber,
      'id_photo_path': idPhotoPath,
      'staff_id': staffId,
      'selfie_photo_path': selfiePhotoPath,
      'nok_name': nokName,
      'nok_relationship': nokRelationship,
      'nok_phone': nokPhone,
      'nok_address': nokAddress,
      'bank_name': bankName,
      'bank_code': bankCode,
      'account_number': accountNumber,
      'account_name': accountName,
      'account_type': accountType,
      'bvn': bvn,
      'contribution_type': contributionType,
      'status': status,
    };
  }

  factory KYCSubmission.fromJson(Map<String, dynamic> json) {
    return KYCSubmission(
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      employmentType: json['employment_type'] as String? ?? '',
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      jobTitle: json['job_title'] as String? ?? '',
      monthlyIncomeRange: json['monthly_income_range'] as String? ?? '',
      occupation: json['occupation'] as String?,
      employerName: json['employer_name'] as String?,
      workAddress: json['work_address'] as String?,
      yearsOfEmployment: json['years_of_employment'] as String?,
      residentialAddress: json['residential_address'] as String? ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      lga: json['lga'] as String?,
      country: json['country'] as String?,
      idType: json['id_type'] as String? ?? '',
      idNumber: json['id_number'] as String?,
      idPhotoPath: json['id_photo_path'] as String?,
      staffId: json['staff_id'] as String?,
      selfiePhotoPath: json['selfie_photo_path'] as String?,
      nokName: json['nok_name'] as String?,
      nokRelationship: json['nok_relationship'] as String?,
      nokPhone: json['nok_phone'] as String?,
      nokAddress: json['nok_address'] as String?,
      bankName: json['bank_name'] as String?,
      bankCode: json['bank_code'] as String?,
      accountNumber: json['account_number'] as String?,
      accountName: json['account_name'] as String?,
      accountType: json['account_type'] as String?,
      bvn: json['bvn'] as String?,
      contributionType: json['contribution_type'] as String? ?? 'direct_deposit',
      status: json['status'] as String? ?? 'draft',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  KYCSubmission copyWith({
    String? dateOfBirth,
    String? gender,
    String? employmentType,
    String? organizationId,
    String? organizationName,
    String? jobTitle,
    String? monthlyIncomeRange,
    String? occupation,
    String? employerName,
    String? workAddress,
    String? yearsOfEmployment,
    String? residentialAddress,
    String? city,
    String? state,
    String? lga,
    String? country,
    String? idType,
    String? idNumber,
    String? idPhotoPath,
    String? staffId,
    String? selfiePhotoPath,
    String? nokName,
    String? nokRelationship,
    String? nokPhone,
    String? nokAddress,
    String? bankName,
    String? bankCode,
    String? accountNumber,
    String? accountName,
    String? accountType,
    String? bvn,
    String? contributionType,
    String? status,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? rejectionReason,
  }) {
    return KYCSubmission(
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      employmentType: employmentType ?? this.employmentType,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      jobTitle: jobTitle ?? this.jobTitle,
      monthlyIncomeRange: monthlyIncomeRange ?? this.monthlyIncomeRange,
      occupation: occupation ?? this.occupation,
      employerName: employerName ?? this.employerName,
      workAddress: workAddress ?? this.workAddress,
      yearsOfEmployment: yearsOfEmployment ?? this.yearsOfEmployment,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      lga: lga ?? this.lga,
      country: country ?? this.country,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      idPhotoPath: idPhotoPath ?? this.idPhotoPath,
      staffId: staffId ?? this.staffId,
      selfiePhotoPath: selfiePhotoPath ?? this.selfiePhotoPath,
      nokName: nokName ?? this.nokName,
      nokRelationship: nokRelationship ?? this.nokRelationship,
      nokPhone: nokPhone ?? this.nokPhone,
      nokAddress: nokAddress ?? this.nokAddress,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      bvn: bvn ?? this.bvn,
      contributionType: contributionType ?? this.contributionType,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  /// Personal basics everyone needs, regardless of contribution channel.
  bool get _personalBasicsComplete {
    return dateOfBirth != null &&
        gender != null &&
        residentialAddress.isNotEmpty &&
        state != null;
  }

  /// Employment section — only required for salary-deduction members.
  bool get _employmentComplete {
    return employmentType.isNotEmpty &&
        organizationName != null &&
        jobTitle.isNotEmpty &&
        monthlyIncomeRange.isNotEmpty;
  }

  bool get isComplete {
    return _personalBasicsComplete &&
        (!isSalaryDeduction || _employmentComplete) &&
        idType.isNotEmpty &&
        idNumber != null &&
        idPhotoPath != null &&
        selfiePhotoPath != null &&
        nokName != null &&
        nokRelationship != null &&
        nokPhone != null &&
        bankName != null &&
        bankCode != null &&
        accountNumber != null &&
        accountName != null &&
        accountType != null &&
        bvn != null;
  }

  /// Returns the names of required KYC sections that still have missing
  /// values, in flow order. Used by the "Complete KYC" entry to jump the
  /// member straight to the first incomplete step (so only missing data is
  /// asked for).
  List<String> get missingSections {
    final missing = <String>[];
    // Personal basics are always required; the employment fields only for
    // salary-deduction members. Both route to the employment screen, which
    // collects the basics for direct-deposit members without the payroll
    // fields.
    if (!_personalBasicsComplete ||
        (isSalaryDeduction && !_employmentComplete)) {
      missing.add('employment');
    }
    if (idType.isEmpty ||
        idNumber == null ||
        idPhotoPath == null ||
        selfiePhotoPath == null) {
      missing.add('identification');
    }
    if (nokName == null || nokRelationship == null || nokPhone == null) {
      missing.add('nextOfKin');
    }
    if (bankName == null ||
        accountNumber == null ||
        accountName == null ||
        accountType == null ||
        bvn == null) {
      missing.add('bank');
    }
    return missing;
  }

  @override
  List<Object?> get props => [
    dateOfBirth,
    gender,
    employmentType,
    organizationId,
    organizationName,
    jobTitle,
    monthlyIncomeRange,
    occupation,
    employerName,
    workAddress,
    yearsOfEmployment,
    residentialAddress,
    city,
    state,
    lga,
    country,
    idType,
    idNumber,
    idPhotoPath,
    staffId,
    selfiePhotoPath,
    nokName,
    nokRelationship,
    nokPhone,
    nokAddress,
    bankName,
    bankCode,
    accountNumber,
    accountName,
    accountType,
    bvn,
    contributionType,
    status,
    submittedAt,
    approvedAt,
    rejectionReason,
  ];
}

/// Organization Model
class Organization extends Equatable {
  final String id;
  final String name;
  final String category;
  final bool isVerified;

  const Organization({
    required this.id,
    required this.name,
    required this.category,
    this.isVerified = true,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      isVerified: json['is_verified'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'is_verified': isVerified,
    };
  }

  @override
  List<Object?> get props => [id, name, category, isVerified];
}

/// Employment Types
class EmploymentTypes {
  static const List<String> types = [
    'Temporary',
    'Contract',
    'Permanent',
  ];
}

/// Income Ranges
class IncomeRanges {
  static const List<Map<String, dynamic>> ranges = [
    {'label': '₦30,000 - ₦50,000', 'min': 30000, 'max': 50000, 'value': '30000_50000'},
    {'label': '₦50,001 - ₦100,000', 'min': 50001, 'max': 100000, 'value': '50001_100000'},
    {'label': '₦100,001 - ₦200,000', 'min': 100001, 'max': 200000, 'value': '100001_200000'},
    {'label': '₦200,001 - ₦350,000', 'min': 200001, 'max': 350000, 'value': '200001_350000'},
    {'label': '₦350,001 - ₦500,000', 'min': 350001, 'max': 500000, 'value': '350001_500000'},
    {'label': '₦500,001 and above', 'min': 500001, 'max': 10000000, 'value': '500001_plus'},
  ];

  static String getLabel(String value) {
    final range = ranges.firstWhere(
      (r) => r['value'] == value,
      orElse: () => {'label': value},
    );
    return range['label'] as String;
  }
}

/// ID Types
class IDTypes {
  static const List<Map<String, dynamic>> types = [
    {'label': 'National ID Card (NIN)', 'value': 'national_id'},
    {'label': 'Driver\'s License', 'value': 'drivers_license'},
    {'label': 'International Passport', 'value': 'passport'},
    {'label': 'Voter\'s Card', 'value': 'voters_card'},
    {'label': 'Residence Permit', 'value': 'residence_permit'},
  ];

  static String getLabel(String value) {
    final type = types.firstWhere(
      (t) => t['value'] == value,
      orElse: () => {'label': value},
    );
    return type['label'] as String;
  }
}

/// Organization Categories
class OrganizationCategories {
  static const List<Map<String, dynamic>> categories = [
    {
      'label': 'Government',
      'icon': Icons.account_balance,
      'organizations': [
        'Federal Government Ministries, Departments & Agencies (MDAs)',
        'State Government MDAs',
        'Local Government Councils',
      ]
    },
    {
      'label': 'Education',
      'icon': Icons.school,
      'organizations': [
        'Federal Universities',
        'State Universities',
        'Private Universities',
        'Federal Teaching Hospitals',
        'State Teaching Hospitals',
        'Polytechnics',
        'Colleges of Education',
      ]
    },
    {
      'label': 'Health',
      'icon': Icons.local_hospital,
      'organizations': [
        'Federal Health Institutions',
        'State Health Institutions',
        'Private Hospitals',
      ]
    },
    {
      'label': 'Banking & Finance',
      'icon': Icons.account_balance_wallet,
      'organizations': [
        'Commercial Banks',
        'Microfinance Banks',
        'Insurance Companies',
        'Asset Management Companies',
      ]
    },
    {
      'label': 'Private Sector',
      'icon': Icons.business,
      'organizations': [
        'Registered Corporate Organizations',
        'Faith-Based Institutions',
        'Approved Private Companies',
      ]
    },
  ];

  static String getCategory(String organization) {
    for (final category in categories) {
      if ((category['organizations'] as List).contains(organization)) {
        return category['label'] as String;
      }
    }
    return 'Private Sector';
  }
}

/// KYC State
enum KYCStatus {
  initial,
  loading,
  loaded,
  submitting,
  submitted,
  error,
}

class KYCState extends Equatable {
  final KYCStatus status;
  final KYCSubmission? submission;
  final List<Organization> organizations;
  final String? error;
  final int currentStep;
  final int totalSteps;

  const KYCState({
    this.status = KYCStatus.initial,
    // Never null: an empty draft means KYC updates can always be applied,
    // even before /kyc/status has loaded or when it fails.
    this.submission = const KYCSubmission(),
    this.organizations = const [],
    this.error,
    this.currentStep = 0,
    this.totalSteps = 3,
  });

  bool get isLoading => status == KYCStatus.loading;
  bool get isSubmitting => status == KYCStatus.submitting;
  bool get isComplete => submission?.isComplete ?? false;

  double get progress => currentStep / totalSteps;

  KYCState copyWith({
    KYCStatus? status,
    KYCSubmission? submission,
    List<Organization>? organizations,
    String? error,
    int? currentStep,
    int? totalSteps,
  }) {
    return KYCState(
      status: status ?? this.status,
      submission: submission ?? this.submission,
      organizations: organizations ?? this.organizations,
      error: error,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
    );
  }

  @override
  List<Object?> get props => [
    status,
    submission,
    organizations,
    error,
    currentStep,
    totalSteps,
  ];
}

/// Nigerian Banks
///
/// Bundled fallback list of supported banks (commercial + digital/fintech),
/// used when the remote bank directory (`GET /api/v1/banks`) is unavailable.
/// Codes are Paystack NUBAN bank codes so server-side account verification
/// works for every entry.
class BankTypes {
  static const List<Map<String, dynamic>> banks = [
    // ── Commercial banks ────────────────────────────────────────────────
    {'label': 'Access Bank', 'code': '044', 'category': 'commercial'},
    {'label': 'Citibank Nigeria', 'code': '023', 'category': 'commercial'},
    {'label': 'Ecobank Nigeria', 'code': '050', 'category': 'commercial'},
    {'label': 'Fidelity Bank', 'code': '070', 'category': 'commercial'},
    {'label': 'First Bank of Nigeria', 'code': '011', 'category': 'commercial'},
    {'label': 'First City Monument Bank (FCMB)', 'code': '214', 'category': 'commercial'},
    {'label': 'Globus Bank', 'code': '00103', 'category': 'commercial'},
    {'label': 'Guaranty Trust Bank', 'code': '058', 'category': 'commercial'},
    {'label': 'Jaiz Bank', 'code': '301', 'category': 'commercial'},
    {'label': 'Keystone Bank', 'code': '082', 'category': 'commercial'},
    {'label': 'Lotus Bank', 'code': '303', 'category': 'commercial'},
    {'label': 'Optimus Bank', 'code': '107', 'category': 'commercial'},
    {'label': 'Parallex Bank', 'code': '104', 'category': 'commercial'},
    {'label': 'Polaris Bank', 'code': '076', 'category': 'commercial'},
    {'label': 'PremiumTrust Bank', 'code': '105', 'category': 'commercial'},
    {'label': 'Providus Bank', 'code': '101', 'category': 'commercial'},
    {'label': 'Signature Bank', 'code': '106', 'category': 'commercial'},
    {'label': 'Stanbic IBTC Bank', 'code': '221', 'category': 'commercial'},
    {'label': 'Standard Chartered Bank', 'code': '068', 'category': 'commercial'},
    {'label': 'Sterling Bank', 'code': '232', 'category': 'commercial'},
    {'label': 'SunTrust Bank', 'code': '100', 'category': 'commercial'},
    {'label': 'TAJ Bank', 'code': '302', 'category': 'commercial'},
    {'label': 'Titan Bank', 'code': '102', 'category': 'commercial'},
    {'label': 'Union Bank of Nigeria', 'code': '032', 'category': 'commercial'},
    {'label': 'United Bank for Africa (UBA)', 'code': '033', 'category': 'commercial'},
    {'label': 'Unity Bank', 'code': '215', 'category': 'commercial'},
    {'label': 'Wema Bank', 'code': '035', 'category': 'commercial'},
    {'label': 'Zenith Bank', 'code': '057', 'category': 'commercial'},
    // ── Digital banks & fintechs ────────────────────────────────────────
    {'label': 'ALAT by WEMA', 'code': '035A', 'category': 'digital'},
    {'label': 'Carbon', 'code': '565', 'category': 'digital'},
    {'label': 'FairMoney', 'code': '51318', 'category': 'digital'},
    {'label': 'GoMoney', 'code': '100022', 'category': 'digital'},
    {'label': 'Kuda Bank', 'code': '50211', 'category': 'digital'},
    {'label': 'Mint MFB', 'code': '50304', 'category': 'digital'},
    {'label': 'Moniepoint MFB', 'code': '50515', 'category': 'digital'},
    {'label': 'OPay', 'code': '999992', 'category': 'digital'},
    {'label': 'PalmPay', 'code': '999991', 'category': 'digital'},
    {'label': 'Rubies Bank', 'code': '125', 'category': 'digital'},
    {'label': 'Safe Haven MFB', 'code': '51113', 'category': 'digital'},
    {'label': 'Sparkle Microfinance Bank', 'code': '51310', 'category': 'digital'},
    {'label': 'VBank (VFD Microfinance Bank)', 'code': '566', 'category': 'digital'},
  ];

  static String getBankCode(String bankName) {
    final bank = banks.firstWhere(
      (b) => b['label'] == bankName,
      orElse: () => {'code': ''},
    );
    return bank['code'] as String;
  }

  static String getBankName(String bankCode) {
    final bank = banks.firstWhere(
      (b) => b['code'] == bankCode,
      orElse: () => {'label': ''},
    );
    return bank['label'] as String;
  }
}

/// Bank Account Types
class BankAccountTypes {
  static const List<Map<String, dynamic>> types = [
    {'label': 'Savings Account', 'value': 'savings'},
    {'label': 'Current Account', 'value': 'current'},
    {'label': 'Fixed Deposit Account', 'value': 'fixed_deposit'},
  ];

  static String getLabel(String value) {
    final type = types.firstWhere(
      (t) => t['value'] == value,
      orElse: () => {'label': value},
    );
    return type['label'] as String;
  }
}
