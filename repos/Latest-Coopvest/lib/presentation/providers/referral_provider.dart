import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/referral_models.dart';
import '../../core/services/logger_service.dart';
import '../../data/repositories/referral_repository.dart';

/// Referral Status Enum
enum ReferralStatus { initial, loading, loaded, error }

/// Referral Share Link
class ShareLink extends Equatable {
  final String shareLink;
  final DateTime createdAt;

  const ShareLink({
    required this.shareLink,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [shareLink, createdAt];
}

/// Referral State
class ReferralState extends Equatable {
  final ReferralStatus status;
  final ReferralSummary? summary;
  final String? referralCode;
  final List<Referral> referrals;
  final ShareLink? shareLink;
  final LoanInterestCalculation? interestCalculation;
  final String? error;
  final int confirmedCount;
  final double currentBonus;

  const ReferralState({
    this.status = ReferralStatus.initial,
    this.summary,
    this.referralCode,
    this.referrals = const [],
    this.shareLink,
    this.interestCalculation,
    this.error,
    this.confirmedCount = 0,
    this.currentBonus = 0,
  });

  ReferralState copyWith({
    ReferralStatus? status,
    ReferralSummary? summary,
    String? referralCode,
    List<Referral>? referrals,
    ShareLink? shareLink,
    LoanInterestCalculation? interestCalculation,
    String? error,
    int? confirmedCount,
    double? currentBonus,
  }) {
    return ReferralState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      referralCode: referralCode ?? this.referralCode,
      referrals: referrals ?? this.referrals,
      shareLink: shareLink ?? this.shareLink,
      interestCalculation: interestCalculation ?? this.interestCalculation,
      error: error,
      confirmedCount: confirmedCount ?? this.confirmedCount,
      currentBonus: currentBonus ?? this.currentBonus,
    );
  }

  @override
  List<Object?> get props => [
    status,
    summary,
    referralCode,
    referrals,
    shareLink,
    interestCalculation,
    error,
    confirmedCount,
    currentBonus,
  ];
}

// ...

/// Referral Notifier
class ReferralNotifier extends StateNotifier<ReferralState> {
  final ReferralRepository _repository;
  final LoggerService _logger;

  ReferralNotifier(this._repository) : _logger = LoggerService(), super(const ReferralState());

  /// Load referral summary
  Future<void> loadReferralSummary() async {
    state = state.copyWith(status: ReferralStatus.loading, error: null);
    try {
      final result = await _repository.getReferralSummary();
      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          status: ReferralStatus.loaded,
          summary: result.data,
        );
      } else {
        state = state.copyWith(
          status: ReferralStatus.error,
          error: result.error ?? 'Failed to load referral summary',
        );
      }
    } catch (e) {
      _logger.error('Load referral summary error: $e');
      state = state.copyWith(
        status: ReferralStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Load user's referral code
  Future<void> loadReferralCode() async {
    try {
      final result = await _repository.getReferralCode();
      if (result.isSuccess && result.data != null) {
        state = state.copyWith(referralCode: result.data);
      }
    } catch (e) {
      _logger.error('Load referral code error: $e');
    }
  }

  /// Load all referrals
  Future<void> loadReferrals() async {
    state = state.copyWith(status: ReferralStatus.loading, error: null);
    try {
      final result = await _repository.getMyReferrals();
      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          status: ReferralStatus.loaded,
          referrals: result.data,
        );
      } else {
        state = state.copyWith(
          status: ReferralStatus.error,
          error: result.error ?? 'Failed to load referrals',
        );
      }
    } catch (e) {
      _logger.error('Load referrals error: $e');
      state = state.copyWith(
        status: ReferralStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Calculate interest with bonus
  Future<void> calculateInterest({
    required String loanType,
    required double loanAmount,
    required int tenureMonths,
  }) async {
    try {
      final result = await _repository.calculateInterestWithBonus(
        loanType: loanType,
        loanAmount: loanAmount,
        tenureMonths: tenureMonths,
      );
      if (result.isSuccess && result.data != null) {
        state = state.copyWith(interestCalculation: result.data);
      }
    } catch (e) {
      _logger.error('Calculate interest error: $e');
    }
  }

  /// Get share link
  Future<void> loadShareLink() async {
    try {
      final result = await _repository.getShareLink();
      if (result.isSuccess && result.data != null) {
        final linkResponse = result.data!;
        state = state.copyWith(
          shareLink: ShareLink(
            shareLink: linkResponse.shareLink ?? '',
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      _logger.error('Load share link error: $e');
    }
  }

  /// Register a new referral
  Future<bool> registerReferral({
    required String referralCode,
    required String referredUserId,
  }) async {
    state = state.copyWith(status: ReferralStatus.loading, error: null);
    try {
      final result = await _repository.registerReferral(
        referralCode: referralCode,
        referredUserId: referredUserId,
      );
      if (result.isSuccess) {
        await loadReferrals();
        await loadReferralSummary();
        return true;
      } else {
        state = state.copyWith(
          status: ReferralStatus.error,
          error: result.error,
        );
        return false;
      }
    } catch (e) {
      _logger.error('Register referral error: $e');
      state = state.copyWith(
        status: ReferralStatus.error,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Apply bonus to loan
  Future<bool> applyBonusToLoan({required String loanId}) async {
    try {
      final result = await _repository.applyBonusToLoan(loanId: loanId);
      if (result.isSuccess) {
        await loadReferralSummary();
        return true;
      } else {
        state = state.copyWith(error: result.error);
        return false;
      }
    } catch (e) {
      _logger.error('Apply bonus error: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Get tier progress info
  TierProgress getTierProgress() {
    final confirmed = state.confirmedCount;
    final currentBonus = state.currentBonus;

    if (currentBonus >= 4.0) {
      return TierProgress(
        currentTier: 4.0,
        tierName: 'Gold',
        nextTier: null,
        referralsToNext: 0,
        progress: 1.0,
        isMaxTier: true,
      );
    }

    if (currentBonus >= 3.0) {
      return TierProgress(
        currentTier: 3.0,
        tierName: 'Silver',
        nextTier: 4.0,
        referralsToNext: 6 - confirmed,
        progress: confirmed / 6,
        isMaxTier: false,
      );
    }

    if (currentBonus >= 2.0) {
      return TierProgress(
        currentTier: 2.0,
        tierName: 'Bronze',
        nextTier: 3.0,
        referralsToNext: 4 - confirmed,
        progress: confirmed / 4,
        isMaxTier: false,
      );
    }

    // Starting tier
    return TierProgress(
      currentTier: 0,
      tierName: 'None',
      nextTier: 2.0,
      referralsToNext: 2 - confirmed,
      progress: confirmed / 2,
      isMaxTier: false,
      );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset state
  void reset() {
    state = const ReferralState();
  }
}

/// Tier Progress Info
class TierProgress {
  final double currentTier;
  final String tierName;
  final double? nextTier;
  final int referralsToNext;
  final double progress;
  final bool isMaxTier;

  TierProgress({
    required this.currentTier,
    required this.tierName,
    this.nextTier,
    required this.referralsToNext,
    required this.progress,
    required this.isMaxTier,
  });
}

/// Referral Provider
final referralProvider = StateNotifierProvider<ReferralNotifier, ReferralState>((ref) {
  final repository = ref.watch(referralRepositoryProvider);
  return ReferralNotifier(repository);
});
