import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/referral_models.dart';
import '../../core/network/api_client.dart';
import 'package:dio/dio.dart';

/// API Service for Referral Operations

class ReferralApiService {
  final Dio _dio;
  ReferralApiService(this._dio);

  /// Get user's referral summary
  Future<ReferralSummaryResponse> getReferralSummary() {
    return _dio.get('/referrals/summary').then((response) => ReferralSummaryResponse.fromJson(response.data));
  }

  /// Get user's referral code
  Future<ReferralCodeResponse> getMyReferralCode() {
    return _dio.get('/referrals/my-code').then((response) => ReferralCodeResponse.fromJson(response.data));
  }

  /// Get all user's referrals
  Future<ReferralListResponse> getMyReferrals({String? status, int? page, int? limit}) {
    return _dio.get('/referrals', queryParameters: {
      if (status != null) 'status': status,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    }).then((response) => ReferralListResponse.fromJson(response.data));
  }

  /// Get referral by ID
  Future<ReferralDetailResponse> getReferralById(String referralId) {
    return _dio.get('/referrals/$referralId').then((response) => ReferralDetailResponse.fromJson(response.data));
  }

  /// Register a new referral (when new user registers with code)
  Future<ReferralDetailResponse> registerReferral(ReferralRegisterRequest request) {
    return _dio.post('/referrals/register', data: request.toJson()).then((response) => ReferralDetailResponse.fromJson(response.data));
  }

  /// Check referral status and qualification
  Future<ReferralStatusResponse> checkReferralStatus(String referralId) {
    return _dio.get('/referrals/$referralId/status').then((response) => ReferralStatusResponse.fromJson(response.data));
  }

  /// Trigger referral confirmation process (after qualification met)
  Future<ReferralDetailResponse> confirmReferral(String referralId, String referredUserId) {
    return _dio.post('/referrals/$referralId/confirm', data: {'referredUserId': referredUserId}).then((response) => ReferralDetailResponse.fromJson(response.data));
  }

  /// Apply referral bonus to a loan
  Future<ApplyBonusResponse> applyBonusToLoan(ApplyBonusRequest request) {
    return _dio.post('/referrals/apply-bonus', data: request.toJson()).then((response) => ApplyBonusResponse.fromJson(response.data));
  }

  /// Get loan interest calculation with referral bonus
  Future<InterestCalculationResponse> calculateInterestWithBonus(InterestCalculationRequest request) {
    return _dio.post('/referrals/calculate-interest', data: request.toJson()).then((response) => InterestCalculationResponse.fromJson(response.data));
  }

  /// Share referral link
  Future<ShareLinkResponse> getShareLink() {
    // This might be a client-side generation or a simple API call
    return _dio.get('/referrals/share-link').then((response) => ShareLinkResponse.fromJson(response.data));
  }

  // ============== Admin Endpoints ==============

  /// Get all referrals (admin)
  Future<ReferralListResponse> getAllReferralsAdmin({
    String? status,
    int? page,
    int? limit,
  }) {
    return _dio.get('/admin/referrals', queryParameters: {
      if (status != null) 'status': status,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    }).then((response) => ReferralListResponse.fromJson(response.data));
  }

  /// Get referral statistics (admin)
  Future<ReferralStatsResponse> getReferralStatsAdmin() {
    return _dio.get('/admin/referrals/stats').then((response) => ReferralStatsResponse.fromJson(response.data));
  }

  /// Manually confirm a referral (admin)
  Future<ReferralDetailResponse> adminConfirmReferral(String referralId, AdminConfirmRequest request) {
    return _dio.post('/admin/referrals/$referralId/confirm', data: request.toJson()).then((response) => ReferralDetailResponse.fromJson(response.data));
  }

  /// Flag a referral for review (admin)
  Future<ReferralDetailResponse> adminFlagReferral(String referralId, FlagReferralRequest request) {
    return _dio.post('/admin/referrals/$referralId/flag', data: request.toJson()).then((response) => ReferralDetailResponse.fromJson(response.data));
  }

  /// Unflag a referral (admin)
  Future<ReferralDetailResponse> adminUnflagReferral(String referralId) {
    return _dio.post('/admin/referrals/$referralId/unflag').then((response) => ReferralDetailResponse.fromJson(response.data));
  }

  /// Revoke referral bonus (admin)
  Future<ReferralDetailResponse> adminRevokeBonus(String referralId, RevokeBonusRequest request) {
    return _dio.post('/admin/referrals/$referralId/revoke-bonus', data: request.toJson()).then((response) => ReferralDetailResponse.fromJson(response.data));
  }

  /// Get audit logs (admin)
  Future<AuditLogResponse> getAuditLogs({
    int? page,
    int? limit,
  }) {
    return _dio.get('/admin/audit-logs', queryParameters: {
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    }).then((response) => AuditLogResponse.fromJson(response.data));
  }

  /// Update referral settings (admin)
  Future<SettingsResponse> updateReferralSettings(ReferralSettingsRequest request) {
    return _dio.post('/admin/referral-settings', data: request.toJson()).then((response) => SettingsResponse.fromJson(response.data));
  }

  /// Get referral settings (admin)
  Future<SettingsResponse> getReferralSettings() {
    return _dio.get('/admin/referral-settings').then((response) => SettingsResponse.fromJson(response.data));
  }
}

/// Referral API Service Provider
final referralApiServiceProvider = Provider<ReferralApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReferralApiService(apiClient.dio);
});

// ============== Request Models ==============

class ReferralRegisterRequest {
  final String referralCode;
  final String referredUserId;
  final String referredUserName;

  ReferralRegisterRequest({
    required this.referralCode,
    required this.referredUserId,
    required this.referredUserName,
  });

  Map<String, dynamic> toJson() => {
        'referralCode': referralCode,
        'referredUserId': referredUserId,
        'referredUserName': referredUserName,
      };
}

class ApplyBonusRequest {
  final String loanId;
  final String loanType;
  final double loanAmount;
  final int tenureMonths;

  ApplyBonusRequest({
    required this.loanId,
    required this.loanType,
    required this.loanAmount,
    required this.tenureMonths,
  });

  Map<String, dynamic> toJson() => {
        'loanId': loanId,
        'loanType': loanType,
        'loanAmount': loanAmount,
        'tenureMonths': tenureMonths,
      };
}

class InterestCalculationRequest {
  final String loanType;
  final double loanAmount;
  final int tenureMonths;

  InterestCalculationRequest({
    required this.loanType,
    required this.loanAmount,
    required this.tenureMonths,
  });

  Map<String, dynamic> toJson() => {
        'loanType': loanType,
        'loanAmount': loanAmount,
        'tenureMonths': tenureMonths,
      };
}

class AdminConfirmRequest {
  final String adminId;
  final String? notes;

  AdminConfirmRequest({
    required this.adminId,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'admin_id': adminId,
        'notes': notes,
      };
}

class FlagReferralRequest {
  final String reason;
  final String adminId;

  FlagReferralRequest({
    required this.reason,
    required this.adminId,
  });

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'admin_id': adminId,
      };
}

class RevokeBonusRequest {
  final String reason;
  final String adminId;

  RevokeBonusRequest({
    required this.reason,
    required this.adminId,
  });

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'admin_id': adminId,
      };
}

class ReferralSettingsRequest {
  final bool enabled;
  final int lockInDays;
  final int minimumSavingsMonths;
  final double? minimumSavingsAmount;
  final Map<String, double>? minimumInterestFloors;

  ReferralSettingsRequest({
    required this.enabled,
    required this.lockInDays,
    required this.minimumSavingsMonths,
    this.minimumSavingsAmount,
    this.minimumInterestFloors,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'lock_in_days': lockInDays,
        'minimum_savings_months': minimumSavingsMonths,
        'minimum_savings_amount': minimumSavingsAmount,
        'minimum_interest_floors': minimumInterestFloors,
      };
}

// ============== Response Models ==============

class ReferralSummaryResponse {
  final bool success;
  final String? error;
  final ReferralSummary? summary;

  ReferralSummaryResponse({
    required this.success,
    this.error,
    this.summary,
  });

  factory ReferralSummaryResponse.fromJson(Map<String, dynamic> json) {
    return ReferralSummaryResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
      summary: json['summary'] != null
          ? ReferralSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReferralCodeResponse {
  final bool success;
  final String? error;
  final String? referralCode;
  final String? qrCodeUrl;

  ReferralCodeResponse({
    required this.success,
    this.error,
    this.referralCode,
    this.qrCodeUrl,
  });

  factory ReferralCodeResponse.fromJson(Map<String, dynamic> json) {
    return ReferralCodeResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
      referralCode: json['referralCode'] as String?,
      qrCodeUrl: json['qrCodeUrl'] as String?,
    );
  }
}

class ReferralListResponse {
  final bool success;
  final String? error;
  final List<Referral> referrals;
  final int total;
  final int page;
  final int limit;

  ReferralListResponse({
    required this.success,
    this.error,
    required this.referrals,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory ReferralListResponse.fromJson(Map<String, dynamic> json) {
    return ReferralListResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
      referrals: (json['referrals'] as List? ?? [])
          .map((e) => Referral.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
    );
  }
}

class ReferralDetailResponse {
  final bool success;
  final String? error;
  final Referral? referral;

  ReferralDetailResponse({
    required this.success,
    this.error,
    this.referral,
  });

  factory ReferralDetailResponse.fromJson(Map<String, dynamic> json) {
    return ReferralDetailResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
      referral: json['referral'] != null
          ? Referral.fromJson(json['referral'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReferralStatusResponse {
  final bool success;
  final bool qualified;
  final bool kycVerified;
  final bool savingsCriteriaMet;
  final int consecutiveSavingsMonths;
  final int requiredSavingsMonths;
  final bool isFlagged;

  ReferralStatusResponse({
    required this.success,
    required this.qualified,
    required this.kycVerified,
    required this.savingsCriteriaMet,
    required this.consecutiveSavingsMonths,
    required this.requiredSavingsMonths,
    required this.isFlagged,
  });

  factory ReferralStatusResponse.fromJson(Map<String, dynamic> json) {
    return ReferralStatusResponse(
      success: json['success'] as bool,
      qualified: json['qualified'] as bool? ?? false,
      kycVerified: json['kycVerified'] as bool? ?? false,
      savingsCriteriaMet: json['savingsCriteriaMet'] as bool? ?? false,
      consecutiveSavingsMonths: json['consecutiveSavingsMonths'] as int? ?? 0,
      requiredSavingsMonths: json['requiredSavingsMonths'] as int? ?? 3,
      isFlagged: json['isFlagged'] as bool? ?? false,
    );
  }
}

class ApplyBonusResponse {
  final bool success;
  final double bonusPercent;
  final String? message;

  ApplyBonusResponse({
    required this.success,
    required this.bonusPercent,
    this.message,
  });

  factory ApplyBonusResponse.fromJson(Map<String, dynamic> json) {
    return ApplyBonusResponse(
      success: json['success'] as bool,
      bonusPercent: (json['bonusPercent'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String?,
    );
  }
}

class InterestCalculationResponse {
  final bool success;
  final dynamic calculation;

  InterestCalculationResponse({
    required this.success,
    this.calculation,
  });

  factory InterestCalculationResponse.fromJson(Map<String, dynamic> json) {
    return InterestCalculationResponse(
      success: json['success'] as bool,
      calculation: json['calculation'],
    );
  }
}

class ShareLinkResponse {
  final bool success;
  final String shareLink;
  final String referralCode;

  ShareLinkResponse({
    required this.success,
    required this.shareLink,
    required this.referralCode,
  });

  factory ShareLinkResponse.fromJson(Map<String, dynamic> json) {
    return ShareLinkResponse(
      success: json['success'] as bool,
      shareLink: json['shareLink'] as String? ?? '',
      referralCode: json['referralCode'] as String? ?? '',
    );
  }
}

class ReferralStatsResponse {
  final bool success;
  final int totalReferrals;
  final int pendingReferrals;
  final int confirmedReferrals;
  final int flaggedReferrals;
  final Map<String, int> referralsByTier;
  final Map<String, double> totalBonusesApplied;
  final double totalInterestSaved;

  ReferralStatsResponse({
    required this.success,
    required this.totalReferrals,
    required this.pendingReferrals,
    required this.confirmedReferrals,
    required this.flaggedReferrals,
    required this.referralsByTier,
    required this.totalBonusesApplied,
    required this.totalInterestSaved,
  });

  factory ReferralStatsResponse.fromJson(Map<String, dynamic> json) {
    return ReferralStatsResponse(
      success: json['success'] as bool,
      totalReferrals: json['totalReferrals'] as int? ?? 0,
      pendingReferrals: json['pendingReferrals'] as int? ?? 0,
      confirmedReferrals: json['confirmedReferrals'] as int? ?? 0,
      flaggedReferrals: json['flaggedReferrals'] as int? ?? 0,
      referralsByTier: Map<String, int>.from(json['referralsByTier'] ?? {}),
      totalBonusesApplied: Map<String, double>.from(json['totalBonusesApplied'] ?? {}),
      totalInterestSaved: (json['totalInterestSaved'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AuditLogResponse {
  final bool success;
  final List<dynamic> logs;
  final int total;
  final int page;

  AuditLogResponse({
    required this.success,
    required this.logs,
    required this.total,
    required this.page,
  });

  factory AuditLogResponse.fromJson(Map<String, dynamic> json) {
    return AuditLogResponse(
      success: json['success'] as bool,
      logs: json['logs'] as List? ?? [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
    );
  }
}

class SettingsResponse {
  final bool success;
  final bool enabled;
  final int lockInDays;
  final int minimumSavingsMonths;

  SettingsResponse({
    required this.success,
    required this.enabled,
    required this.lockInDays,
    required this.minimumSavingsMonths,
  });

  factory SettingsResponse.fromJson(Map<String, dynamic> json) {
    return SettingsResponse(
      success: json['success'] as bool,
      enabled: json['enabled'] as bool? ?? true,
      lockInDays: json['lockInDays'] as int? ?? 30,
      minimumSavingsMonths: json['minimumSavingsMonths'] as int? ?? 3,
    );
  }
}
