import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/rollover_models.dart';





/// API Service for Loan Rollover Operations - Member-only functionality
///
/// NOTE: Admin operations (approvals, rejections) have been moved to the
/// dedicated admin web portal. This API service only handles member-facing
/// operations for rollover requests.
class RolloverApiService {
  final Dio _dio;

  RolloverApiService(this._dio);

  /// Check eligibility for a loan rollover
  Future<RolloverEligibilityResponse> checkEligibility(String loanId) =>
      _dio.get('/rollovers/$loanId/eligibility')
          .then((r) => RolloverEligibilityResponse.fromJson(r.data));

  /// Create a new rollover request
  Future<RolloverRequestResponse> createRolloverRequest(String loanId, RolloverRequest request) =>
      _dio.post('/rollovers/$loanId', data: request)
          .then((r) => RolloverRequestResponse.fromJson(r.data));

  /// Get rollover details by ID
  Future<RolloverDetailsResponse> getRolloverDetails(String rolloverId) =>
      _dio.get('/rollovers/$rolloverId')
          .then((r) => RolloverDetailsResponse.fromJson(r.data));

  /// Get all rollover requests for a member
  Future<RolloverListResponse> getMemberRollovers(String memberId) =>
      _dio.get('/members/$memberId/rollovers')
          .then((r) => RolloverListResponse.fromJson(r.data));

  /// Invite a guarantor for rollover
  Future<GuarantorInviteResponse> inviteGuarantor(String rolloverId, GuarantorInviteRequest request) =>
      _dio.post('/rollovers/$rolloverId/guarantors', data: request)
          .then((r) => GuarantorInviteResponse.fromJson(r.data));

  /// Get guarantors for a rollover
  Future<GuarantorListResponse> getRolloverGuarantors(String rolloverId) =>
      _dio.get('/rollovers/$rolloverId/guarantors')
          .then((r) => GuarantorListResponse.fromJson(r.data));

  /// Guarantor responds to rollover consent request
  Future<GuarantorConsentResponse> guarantorRespond(String rolloverId, String guarantorId, GuarantorRespondRequest request) =>
      _dio.post('/rollovers/$rolloverId/guarantors/$guarantorId/respond', data: request)
          .then((r) => GuarantorConsentResponse.fromJson(r.data));

  /// Member cancels rollover request
  Future<RolloverActionResponse> cancelRollover(String rolloverId, CancelRequest request) =>
      _dio.post('/rollovers/$rolloverId/cancel', data: request)
          .then((r) => RolloverActionResponse.fromJson(r.data));

  /// Replace a guarantor who declined
  Future<GuarantorReplaceResponse> replaceGuarantor(String rolloverId, String guarantorId, GuarantorInviteRequest request) =>
      _dio.put('/rollovers/$rolloverId/guarantors/$guarantorId', data: request)
          .then((r) => GuarantorReplaceResponse.fromJson(r.data));
}

/// Rollover API Service Provider
final rolloverApiServiceProvider = Provider<RolloverApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RolloverApiService(apiClient.dio);
});

// ============== Request Models ==============

class RolloverRequest {
  final String loanId;
  final String memberId;
  final int newTenure;
  final List<GuarantorInfo> guarantors;

  RolloverRequest({
    required this.loanId,
    required this.memberId,
    required this.newTenure,
    required this.guarantors,
  });

  Map<String, dynamic> toJson() => {
        'loan_id': loanId,
        'member_id': memberId,
        'new_tenure': newTenure,
        'guarantors': guarantors.map((e) => e.toJson()).toList(),
      };
}

class GuarantorInfo {
  final String guarantorId;
  final String guarantorName;
  final String guarantorPhone;

  GuarantorInfo({
    required this.guarantorId,
    required this.guarantorName,
    required this.guarantorPhone,
  });

  Map<String, dynamic> toJson() => {
        'guarantor_id': guarantorId,
        'guarantor_name': guarantorName,
        'guarantor_phone': guarantorPhone,
      };
}

class GuarantorInviteRequest {
  final String guarantorId;
  final String guarantorName;
  final String guarantorPhone;

  GuarantorInviteRequest({
    required this.guarantorId,
    required this.guarantorName,
    required this.guarantorPhone,
  });

  Map<String, dynamic> toJson() => {
        'guarantor_id': guarantorId,
        'guarantor_name': guarantorName,
        'guarantor_phone': guarantorPhone,
      };
}

class GuarantorRespondRequest {
  final String guarantorId;
  final bool accepted;
  final String? reason;

  GuarantorRespondRequest({
    required this.guarantorId,
    required this.accepted,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'guarantor_id': guarantorId,
        'accepted': accepted,
        'reason': reason,
      };
}

class CancelRequest {
  final String memberId;
  final String? reason;

  CancelRequest({
    required this.memberId,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'member_id': memberId,
        'reason': reason,
      };
}

// ============== Response Models ==============

class RolloverEligibilityResponse {
  final bool success;
  final String message;
  final RolloverEligibility? eligibility;

  RolloverEligibilityResponse({
    required this.success,
    required this.message,
    this.eligibility,
  });

  factory RolloverEligibilityResponse.fromJson(Map<String, dynamic> json) {
    return RolloverEligibilityResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      eligibility: json['eligibility'] != null
          ? RolloverEligibility.fromJson(json['eligibility'])
          : null,
    );
  }
}

class RolloverRequestResponse {
  final bool success;
  final String message;
  final LoanRollover? rollover;

  RolloverRequestResponse({
    required this.success,
    required this.message,
    this.rollover,
  });

  factory RolloverRequestResponse.fromJson(Map<String, dynamic> json) {
    return RolloverRequestResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      rollover: json['rollover'] != null
          ? LoanRollover.fromJson(json['rollover'])
          : null,
    );
  }
}

class RolloverDetailsResponse {
  final bool success;
  final String message;
  final LoanRollover? rollover;
  final List<RolloverGuarantor>? guarantors;

  RolloverDetailsResponse({
    required this.success,
    required this.message,
    this.rollover,
    this.guarantors,
  });

  factory RolloverDetailsResponse.fromJson(Map<String, dynamic> json) {
    return RolloverDetailsResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      rollover: json['rollover'] != null
          ? LoanRollover.fromJson(json['rollover'])
          : null,
      guarantors: json['guarantors'] != null
          ? (json['guarantors'] as List<dynamic>)
              .map((e) => RolloverGuarantor.fromJson(e))
              .toList()
          : null,
    );
  }
}

class RolloverListResponse {
  final bool success;
  final String message;
  final List<LoanRollover> rollovers;

  RolloverListResponse({
    required this.success,
    required this.message,
    required this.rollovers,
  });

  factory RolloverListResponse.fromJson(Map<String, dynamic> json) {
    return RolloverListResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      rollovers: (json['rollovers'] as List<dynamic>)
          .map((e) => LoanRollover.fromJson(e))
          .toList(),
    );
  }
}

class GuarantorInviteResponse {
  final bool success;
  final String message;
  final RolloverGuarantor? guarantor;

  GuarantorInviteResponse({
    required this.success,
    required this.message,
    this.guarantor,
  });

  factory GuarantorInviteResponse.fromJson(Map<String, dynamic> json) {
    return GuarantorInviteResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      guarantor: json['guarantor'] != null
          ? RolloverGuarantor.fromJson(json['guarantor'])
          : null,
    );
  }
}

class GuarantorListResponse {
  final bool success;
  final String message;
  final List<RolloverGuarantor> guarantors;

  GuarantorListResponse({
    required this.success,
    required this.message,
    required this.guarantors,
  });

  factory GuarantorListResponse.fromJson(Map<String, dynamic> json) {
    return GuarantorListResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      guarantors: (json['guarantors'] as List<dynamic>)
          .map((e) => RolloverGuarantor.fromJson(e))
          .toList(),
    );
  }
}

class GuarantorConsentResponse {
  final bool success;
  final String message;
  final RolloverGuarantor? guarantor;
  final int acceptedCount;
  final int declinedCount;
  final bool allConsented;

  GuarantorConsentResponse({
    required this.success,
    required this.message,
    this.guarantor,
    required this.acceptedCount,
    required this.declinedCount,
    required this.allConsented,
  });

  factory GuarantorConsentResponse.fromJson(Map<String, dynamic> json) {
    return GuarantorConsentResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      guarantor: json['guarantor'] != null
          ? RolloverGuarantor.fromJson(json['guarantor'])
          : null,
      acceptedCount: json['accepted_count'] as int,
      declinedCount: json['declined_count'] as int,
      allConsented: json['all_consented'] as bool,
    );
  }
}

class RolloverActionResponse {
  final bool success;
  final String message;
  final LoanRollover? rollover;

  RolloverActionResponse({
    required this.success,
    required this.message,
    this.rollover,
  });

  factory RolloverActionResponse.fromJson(Map<String, dynamic> json) {
    return RolloverActionResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      rollover: json['rollover'] != null
          ? LoanRollover.fromJson(json['rollover'])
          : null,
    );
  }
}

class GuarantorReplaceResponse {
  final bool success;
  final String message;
  final RolloverGuarantor? newGuarantor;
  final List<RolloverGuarantor> guarantors;

  GuarantorReplaceResponse({
    required this.success,
    required this.message,
    this.newGuarantor,
    required this.guarantors,
  });

  factory GuarantorReplaceResponse.fromJson(Map<String, dynamic> json) {
    return GuarantorReplaceResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      newGuarantor: json['new_guarantor'] != null
          ? RolloverGuarantor.fromJson(json['new_guarantor'])
          : null,
      guarantors: (json['guarantors'] as List<dynamic>)
          .map((e) => RolloverGuarantor.fromJson(e))
          .toList(),
    );
  }
}
