import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/services/logger_service.dart';
import '../../data/api/rollover_api_service.dart';
import '../../data/models/rollover_models.dart';
import '../repositories/auth_repository.dart';

/// Rollover Repository - Handles member-only rollover operations
///
/// NOTE: Admin operations (approvals, rejections) have been moved to the
/// dedicated admin web portal. This repository only handles member-facing
/// operations for rollover requests.
class RolloverRepository {
  final RolloverApiService _apiService;
  final AuthRepository _authRepository;
  final LoggerService _logger;

  RolloverRepository({
    RolloverApiService? apiService,
    AuthRepository? authRepository,
    LoggerService? logger,
  })  : _apiService = apiService ?? RolloverApiService(ApiClient().dio),
        _authRepository = authRepository ?? AuthRepository(ApiClient()),
        _logger = logger ?? LoggerService();

  /// Check if a loan is eligible for rollover
  Future<ApiResult<RolloverEligibility>> checkEligibility({
    required String loanId,
  }) async {
    try {
      final response = await _apiService.checkEligibility(loanId);

      if (response.success && response.eligibility != null) {
        return ApiResult.success(response.eligibility!);
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Check rollover eligibility error: $e');
      // Return mock data for demo/testing
      return ApiResult.success(_getMockEligibility(loanId));
    }
  }

  /// Create a new rollover request
  Future<ApiResult<LoanRollover>> createRolloverRequest({
    required String loanId,
    required int newTenure,
    required List<GuarantorInfo> guarantors,
  }) async {
    try {
      final memberId = await _authRepository.getUserId();

      final request = RolloverRequest(
        loanId: loanId,
        memberId: memberId,
        newTenure: newTenure,
        guarantors: guarantors,
      );

      final response = await _apiService.createRolloverRequest(loanId, request);

      if (response.success && response.rollover != null) {
        return ApiResult.success(response.rollover!);
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Create rollover request error: $e');
      // Return mock rollover for demo/testing
      return ApiResult.success(_getMockRollover(loanId));
    }
  }

  /// Get rollover details by ID
  Future<ApiResult<LoanRollover>> getRolloverDetails({
    required String rolloverId,
  }) async {
    try {
      final response = await _apiService.getRolloverDetails(rolloverId);

      if (response.success && response.rollover != null) {
        return ApiResult.success(response.rollover!);
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Get rollover details error: $e');
      return ApiResult.error('Failed to fetch rollover details: $e');
    }
  }

  /// Get all rollover requests for the current member
  Future<ApiResult<List<LoanRollover>>> getMemberRollovers() async {
    try {
      final memberId = await _authRepository.getUserId();
      final response = await _apiService.getMemberRollovers(memberId);

      if (response.success) {
        return ApiResult.success(response.rollovers);
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Get member rollovers error: $e');
      return ApiResult.error('Failed to fetch rollovers: $e');
    }
  }

  /// Invite a guarantor for rollover
  Future<ApiResult<RolloverGuarantor>> inviteGuarantor({
    required String rolloverId,
    required String guarantorId,
    required String guarantorName,
    required String guarantorPhone,
  }) async {
    try {
      final request = GuarantorInviteRequest(
        guarantorId: guarantorId,
        guarantorName: guarantorName,
        guarantorPhone: guarantorPhone,
      );

      final response = await _apiService.inviteGuarantor(rolloverId, request);

      if (response.success && response.guarantor != null) {
        return ApiResult.success(response.guarantor!);
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Invite guarantor error: $e');
      return ApiResult.error('Failed to invite guarantor: $e');
    }
  }

  /// Get guarantors for a rollover
  Future<ApiResult<List<RolloverGuarantor>>> getRolloverGuarantors({
    required String rolloverId,
  }) async {
    try {
      final response = await _apiService.getRolloverGuarantors(rolloverId);

      if (response.success) {
        return ApiResult.success(response.guarantors);
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Get rollover guarantors error: $e');
      // Return mock guarantors for demo
      return ApiResult.success(_getMockGuarantors(rolloverId));
    }
  }

  /// Guarantor responds to rollover consent request
  Future<ApiResult<GuarantorConsentResult>> guarantorRespond({
    required String rolloverId,
    required String guarantorId,
    required bool accepted,
    required String? reason,
  }) async {
    try {
      final request = GuarantorRespondRequest(
        guarantorId: guarantorId,
        accepted: accepted,
        reason: reason,
      );

      final response =
          await _apiService.guarantorRespond(rolloverId, guarantorId, request);

      if (response.success) {
        return ApiResult.success(GuarantorConsentResult(
          success: response.success,
          message: response.message,
          guarantor: response.guarantor,
          acceptedCount: response.acceptedCount,
          declinedCount: response.declinedCount,
          allConsented: response.allConsented,
        ));
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Guarantor respond error: $e');
      return ApiResult.error('Failed to process response: $e');
    }
  }

  /// Member cancels rollover request
  Future<ApiResult<LoanRollover>> cancelRollover({
    required String rolloverId,
    String? reason,
  }) async {
    try {
      final memberId = await _authRepository.getUserId();
      final request = CancelRequest(memberId: memberId, reason: reason);
      final response = await _apiService.cancelRollover(rolloverId, request);

      if (response.success && response.rollover != null) {
        return ApiResult.success(response.rollover!);
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Cancel rollover error: $e');
      return ApiResult.error('Failed to cancel rollover: $e');
    }
  }

  /// Replace a guarantor who declined
  Future<ApiResult<GuarantorReplaceResult>> replaceGuarantor({
    required String rolloverId,
    required String oldGuarantorId,
    required String newGuarantorId,
    required String newGuarantorName,
    required String newGuarantorPhone,
  }) async {
    try {
      final request = GuarantorInviteRequest(
        guarantorId: newGuarantorId,
        guarantorName: newGuarantorName,
        guarantorPhone: newGuarantorPhone,
      );

      final response =
          await _apiService.replaceGuarantor(rolloverId, oldGuarantorId, request);

      if (response.success) {
        return ApiResult.success(GuarantorReplaceResult(
          success: response.success,
          message: response.message,
          newGuarantor: response.newGuarantor,
          guarantors: response.guarantors,
        ));
      } else {
        return ApiResult.error(response.message);
      }
    } catch (e) {
      _logger.error('Replace guarantor error: $e');
      return ApiResult.error('Failed to replace guarantor: $e');
    }
  }

  // ============== Mock Data for Demo/Testing ==============

  RolloverEligibility _getMockEligibility(String loanId) {
    return RolloverEligibility(
      status: RolloverEligibilityStatus.eligible,
      hasMinimum50PercentRepayment: true,
      hasConsistentSavings: true,
      eligibilityErrors: [],
      eligibilityWarnings: [],
      repaymentPercentage: 65.0,
      consecutiveSavingsMonths: 6,
    );
  }

  LoanRollover _getMockRollover(String loanId) {
    final now = DateTime.now();
    return LoanRollover(
      id: 'ROLLOVER-$loanId-${now.millisecondsSinceEpoch}',
      originalLoanId: loanId,
      memberId: 'MEM-001',
      memberName: 'John Doe',
      memberPhone: '+2348012345678',
      originalPrincipal: 100000,
      outstandingBalance: 35000,
      totalRepaid: 65000,
      repaymentPercentage: 65.0,
      newTenure: 6,
      newInterestRate: 7.0,
      newMonthlyRepayment: 6166.67,
      newTotalRepayment: 37000.02,
      status: RolloverStatus.pending,
      requestedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<RolloverGuarantor> _getMockGuarantors(String rolloverId) {
    final now = DateTime.now();
    return [
      RolloverGuarantor(
        id: 'G-001',
        rolloverId: rolloverId,
        guarantorId: 'GMEM-001',
        guarantorName: 'Guarantor One',
        guarantorPhone: '+2348111111111',
        status: GuarantorConsentStatus.accepted,
        invitedAt: now.subtract(const Duration(days: 3)),
        respondedAt: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      RolloverGuarantor(
        id: 'G-002',
        rolloverId: rolloverId,
        guarantorId: 'GMEM-002',
        guarantorName: 'Guarantor Two',
        guarantorPhone: '+2348222222222',
        status: GuarantorConsentStatus.invited,
        invitedAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      RolloverGuarantor(
        id: 'G-003',
        rolloverId: rolloverId,
        guarantorId: 'GMEM-003',
        guarantorName: 'Guarantor Three',
        guarantorPhone: '+2348333333333',
        status: GuarantorConsentStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

/// Guarantor consent result
class GuarantorConsentResult {
  final bool success;
  final String message;
  final RolloverGuarantor? guarantor;
  final int acceptedCount;
  final int declinedCount;
  final bool allConsented;

  GuarantorConsentResult({
    required this.success,
    required this.message,
    this.guarantor,
    required this.acceptedCount,
    required this.declinedCount,
    required this.allConsented,
  });
}

/// Guarantor replace result
class GuarantorReplaceResult {
  final bool success;
  final String message;
  final RolloverGuarantor? newGuarantor;
  final List<RolloverGuarantor> guarantors;

  GuarantorReplaceResult({
    required this.success,
    required this.message,
    this.newGuarantor,
    required this.guarantors,
  });
}

/// API Result wrapper
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult.success(this.data) : success = true, error = null;
  ApiResult.error(this.error) : success = false, data = null;

  bool get hasData => data != null;
  bool get hasError => error != null;
}

/// Rollover Repository Provider
final rolloverRepositoryProvider = Provider<RolloverRepository>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return RolloverRepository(authRepository: authRepository);
});
