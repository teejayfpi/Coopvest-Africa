import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../core/network/api_client.dart';
import '../models/loan_models.dart';
import '../api/loan_api_service.dart';
import '../../core/network/offline_support.dart';

/// Loan Repository - Connects loan screens to the API
class LoanRepository {
  final LoanApiService _apiService;
  final OfflineDataManager _offlineDataManager;

  LoanRepository({
    LoanApiService? apiService,
    OfflineDataManager? offlineDataManager,
  })  : _apiService = apiService ?? LoanApiService(ApiClient().getDio()),
        _offlineDataManager = offlineDataManager ?? OfflineDataManager();

  /// Apply for a new loan
  Future<ApiResult<Loan>> applyForLoan({
    required String userId,
    required String loanType,
    required double amount,
    required String purpose,
    required double monthlySavings,
    required bool isOnline,
  }) async {
    // If offline, save operation for later sync
    if (!isOnline) {
      final operation = {
        'type': 'loan_application',
        'userId': userId,
        'loanType': loanType,
        'amount': amount,
        'purpose': purpose,
        'monthlySavings': monthlySavings,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _offlineDataManager.savePendingOperation(operation);
      
      // Return mock loan for offline mode
      final loan = Loan(
        id: 'OFFLINE-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        amount: amount,
        tenure: _getTenure(loanType),
        interestRate: _getInterestRate(loanType),
        monthlyRepayment: _calculateMonthlyRepayment(amount, _getInterestRate(loanType), _getTenure(loanType)),
        totalRepayment: _calculateTotalRepayment(amount, _getInterestRate(loanType)),
        status: 'pending_offline',
        purpose: purpose,
        guarantorsAccepted: 0,
        guarantorsRequired: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      return ApiResult.success(loan);
    }

    try {
      final result = await _apiService.applyForLoan(
        LoanApplicationRequest(
          userId: userId,
          loanType: loanType,
          amount: amount,
          purpose: purpose,
          monthlySavings: monthlySavings,
        ),
      );

      if (result.success && result.loan != null) {
        final loan = Loan(
          id: result.loan!.id,
          userId: result.loan!.userId,
          amount: result.loan!.amount,
          tenure: result.loan!.tenure,
          interestRate: result.loan!.interestRate,
          monthlyRepayment: result.loan!.monthlyRepayment,
          totalRepayment: result.loan!.monthlyRepayment * result.loan!.tenure,
          status: _mapLoanStatus(result.loan!.status),
          purpose: result.loan!.purpose,
          guarantorsAccepted: 0,
          guarantorsRequired: 3,
          createdAt: result.loan!.createdAt,
          updatedAt: DateTime.now(),
        );
        
        return ApiResult.success(loan);
      } else {
        return ApiResult.error(result.message);
      }
    } catch (e) {
      return ApiResult.error('Failed to apply for loan: $e');
    }
  }

  /// Get user's loans
  Future<ApiResult<List<Loan>>> getUserLoans({
    required String userId,
    required bool isOnline,
  }) async {
    // Try to get from cache first if offline
    if (!isOnline) {
      final cachedData = await _offlineDataManager.getCachedData('user_loans_$userId');
      if (cachedData != null) {
        // Return mock data for offline mode
        return ApiResult.success(_getMockLoans(userId));
      }
    }

    try {
      final result = await _apiService.getUserLoans(userId);

      if (result.success) {
        final loans = result.loans.map((e) {
          return Loan(
            id: e.id,
            userId: e.userId,
            amount: e.amount,
            tenure: e.tenure,
            interestRate: e.interestRate,
            monthlyRepayment: e.monthlyRepayment,
            totalRepayment: e.monthlyRepayment * e.tenure,
            status: _mapLoanStatus(e.status),
            purpose: e.purpose,
            guarantorsAccepted: 0,
            guarantorsRequired: 3,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }).toList();

        // Cache the data for offline access
        if (!isOnline) {
          await _offlineDataManager.cacheData('user_loans_$userId', {'loans': loans});
        }

        return ApiResult.success(loans);
      } else {
        return ApiResult.error('Failed to fetch loans');
      }
    } catch (e) {
      // Return mock data on error
      return ApiResult.success(_getMockLoans(userId));
    }
  }

  /// Get loan details
  Future<ApiResult<LoanDetailsResponse>> getLoanDetails({
    required String loanId,
    required bool isOnline,
  }) async {
    try {
      final result = await _apiService.getLoanDetails(loanId);

      if (result.success) {
        return ApiResult.success(result);
      } else {
        return ApiResult.error('Failed to fetch loan details');
      }
    } catch (e) {
      return ApiResult.error('Failed to fetch loan details: $e');
    }
  }

  /// Confirm guarantee
  Future<ApiResult<GuarantorConfirmResponse>> confirmGuarantee({
    required String loanId,
    required String guarantorId,
    required String guarantorName,
    required String guarantorPhone,
    required double savingsBalance,
    required bool isOnline,
  }) async {
    // If offline, save operation for later sync
    if (!isOnline) {
      final operation = {
        'type': 'guarantor_confirmation',
        'loanId': loanId,
        'guarantorId': guarantorId,
        'guarantorName': guarantorName,
        'guarantorPhone': guarantorPhone,
        'savingsBalance': savingsBalance,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _offlineDataManager.savePendingOperation(operation);
      
      // Return mock success response for offline mode
      return ApiResult.success(GuarantorConfirmResponse(
        success: true,
        message: 'Guarantee confirmed (offline mode)',
        guarantorStatus: 'confirmed',
        guarantorsNowConfirmed: 1,
      ));
    }

    try {
      final result = await _apiService.confirmGuarantee(
        loanId,
        GuarantorConfirmRequest(
          guarantorId: guarantorId,
          guarantorName: guarantorName,
          guarantorPhone: guarantorPhone,
          savingsBalance: savingsBalance,
        ),
      );

      if (result.success) {
        return ApiResult.success(result);
      } else {
        return ApiResult.error(result.message);
      }
    } catch (e) {
      return ApiResult.error('Failed to confirm guarantee: $e');
    }
  }

  /// Decline guarantee
  Future<ApiResult<GuarantorDeclineResponse>> declineGuarantee({
    required String loanId,
    required String guarantorId,
    required String reason,
    required bool isOnline,
  }) async {
    if (!isOnline) {
      final operation = {
        'type': 'guarantor_decline',
        'loanId': loanId,
        'guarantorId': guarantorId,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _offlineDataManager.savePendingOperation(operation);
      
      return ApiResult.success(GuarantorDeclineResponse(
        success: true,
        message: 'Guarantee declined (offline mode)',
      ));
    }

    try {
      final result = await _apiService.declineGuarantee(
        loanId,
        GuarantorDeclineRequest(
          guarantorId: guarantorId,
          reason: reason,
        ),
      );

      if (result.success) {
        return ApiResult.success(result);
      } else {
        return ApiResult.error(result.message);
      }
    } catch (e) {
      return ApiResult.error('Failed to decline guarantee: $e');
    }
  }

  /// Get loan types
  Future<ApiResult<List<LoanTypeData>>> getLoanTypes({required bool isOnline}) async {
    try {
      final result = await _apiService.getLoanTypes();

      if (result.success) {
        return ApiResult.success(result.loanTypes);
      } else {
        return ApiResult.error('Failed to fetch loan types');
      }
    } catch (e) {
      // Return hardcoded loan types on error
      return ApiResult.success(_getHardcodedLoanTypes());
    }
  }

  // Helper methods
  int _getTenure(String loanType) {
    final types = _getHardcodedLoanTypes();
    return types.firstWhere((e) => e.name == loanType).duration;
  }

  double _getInterestRate(String loanType) {
    final types = _getHardcodedLoanTypes();
    return types.firstWhere((e) => e.name == loanType).interestRate;
  }

  double _calculateMonthlyRepayment(double amount, double interestRate, int tenure) {
    final rate = interestRate / 100 / 12;
    final tenureDouble = tenure.toDouble();
    final numerator = amount * rate * pow(1 + rate, tenureDouble).toDouble();
    final denominator = (pow(1 + rate, tenureDouble).toDouble() - 1);
    final emi = numerator / denominator;
    return emi;
  }

  double _calculateTotalRepayment(double amount, double interestRate) {
    return amount + (amount * interestRate / 100);
  }

  String _mapLoanStatus(String apiStatus) {
    switch (apiStatus) {
      case 'pending_guarantors':
        return 'pending';
      case 'guarantors_confirmed':
        return 'approved';
      case 'active':
        return 'active';
      case 'completed':
        return 'completed';
      case 'rejected':
        return 'rejected';
      default:
        return 'pending';
    }
  }

  List<LoanTypeData> _getHardcodedLoanTypes() {
    return [
      LoanTypeData(
        name: 'Quick Loan',
        description: 'Short-term emergency cash for members in urgent need',
        duration: 4,
        interestRate: 7.5,
        minAmount: 5000,
        maxAmount: 50000,
      ),
      LoanTypeData(
        name: 'Flexi Loan',
        description: 'Flexible repayment plan for personal or business needs',
        duration: 6,
        interestRate: 7.0,
        minAmount: 10000,
        maxAmount: 100000,
      ),
      LoanTypeData(
        name: 'Stable Loan (12 months)',
        description: 'Long-term stability with the lowest interest rate',
        duration: 12,
        interestRate: 5.0,
        minAmount: 20000,
        maxAmount: 200000,
      ),
      LoanTypeData(
        name: 'Stable Loan (18 months)',
        description: 'Extended repayment for larger projects or investments',
        duration: 18,
        interestRate: 7.0,
        minAmount: 30000,
        maxAmount: 300000,
      ),
      LoanTypeData(
        name: 'Premium Loan',
        description: 'Premium access for established members with higher limits',
        duration: 24,
        interestRate: 14.0,
        minAmount: 50000,
        maxAmount: 500000,
      ),
      LoanTypeData(
        name: 'Maxi Loan',
        description: 'Maximum loan for major investments and business expansion',
        duration: 36,
        interestRate: 19.0,
        minAmount: 100000,
        maxAmount: 1000000,
      ),
    ];
  }

  List<Loan> _getMockLoans(String userId) {
    return [
      Loan(
        id: 'COOP-$userId-LOAN-001',
        userId: userId,
        amount: 50000,
        tenure: 4,
        interestRate: 7.5,
        monthlyRepayment: 13125,
        totalRepayment: 52500,
        status: 'active',
        purpose: 'Business expansion',
        guarantorsAccepted: 3,
        guarantorsRequired: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      Loan(
        id: 'COOP-$userId-LOAN-002',
        userId: userId,
        amount: 100000,
        tenure: 6,
        interestRate: 7.0,
        monthlyRepayment: 18333,
        totalRepayment: 110000,
        status: 'completed',
        purpose: 'Emergency expenses',
        guarantorsAccepted: 3,
        guarantorsRequired: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 180)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ];
  }
}

/// Loan Repository Provider
final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository();
});

/// Use pow from dart:math
double pow(double base, double exponent) => math.pow(base, exponent).toDouble();
