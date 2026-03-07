import 'package:equatable/equatable.dart';

/// Referral Model - Represents a referral relationship between members
class Referral extends Equatable {
  final String id;
  final String referrerId;
  final String referrerName;
  final String referredId;
  final String referredName;
  final String referralCode;
  final bool confirmed;
  final bool isFlagged;
  final String? flaggedReason;
  final DateTime? confirmationDate;
  final DateTime? lockInEndDate;
  final double tierBonusPercent;
  final bool bonusConsumed;
  final String? bonusUsedLoanId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Qualification fields
  final bool kycVerified;
  final bool savingsCriteriaMet;
  final int consecutiveSavingsMonths;
  final double totalSavingsAmount;
  final DateTime? minimumSavingsDate; // 3 months from first savings

  const Referral({
    required this.id,
    required this.referrerId,
    required this.referrerName,
    required this.referredId,
    required this.referredName,
    required this.referralCode,
    this.confirmed = false,
    this.isFlagged = false,
    this.flaggedReason,
    this.confirmationDate,
    this.lockInEndDate,
    this.tierBonusPercent = 0,
    this.bonusConsumed = false,
    this.bonusUsedLoanId,
    required this.createdAt,
    required this.updatedAt,
    this.kycVerified = false,
    this.savingsCriteriaMet = false,
    this.consecutiveSavingsMonths = 0,
    this.totalSavingsAmount = 0,
    this.minimumSavingsDate,
  });

  // Tier configuration
  static const Map<int, double> tierThresholds = {
    2: 2.0, // 2 referrals = 2% reduction
    4: 3.0, // 4 referrals = 3% reduction
    6: 4.0, // 6 referrals = 4% reduction (max)
  };

  static const double maxBonusPercent = 4.0;
  static const int lockInDays = 30; // 30-day lock-in period
  static const int minimumSavingsMonths = 3;

  factory Referral.fromJson(Map<String, dynamic> json) {
    return Referral(
      id: json['id'] as String,
      referrerId: json['referrer_id'] as String,
      referrerName: json['referrer_name'] as String,
      referredId: json['referred_id'] as String,
      referredName: json['referred_name'] as String,
      referralCode: json['referral_code'] as String,
      confirmed: json['confirmed'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      flaggedReason: json['flagged_reason'] as String?,
      confirmationDate: json['confirmation_date'] != null
          ? DateTime.parse(json['confirmation_date'] as String)
          : null,
      lockInEndDate: json['lock_in_end_date'] != null
          ? DateTime.parse(json['lock_in_end_date'] as String)
          : null,
      tierBonusPercent: (json['tier_bonus_percent'] as num?)?.toDouble() ?? 0,
      bonusConsumed: json['bonus_consumed'] as bool? ?? false,
      bonusUsedLoanId: json['bonus_used_loan_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      kycVerified: json['kyc_verified'] as bool? ?? false,
      savingsCriteriaMet: json['savings_criteria_met'] as bool? ?? false,
      consecutiveSavingsMonths: json['consecutive_savings_months'] as int? ?? 0,
      totalSavingsAmount: (json['total_savings_amount'] as num?)?.toDouble() ?? 0,
      minimumSavingsDate: json['minimum_savings_date'] != null
          ? DateTime.parse(json['minimum_savings_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referrer_id': referrerId,
      'referrer_name': referrerName,
      'referred_id': referredId,
      'referred_name': referredName,
      'referral_code': referralCode,
      'confirmed': confirmed,
      'is_flagged': isFlagged,
      'flagged_reason': flaggedReason,
      'confirmation_date': confirmationDate?.toIso8601String(),
      'lock_in_end_date': lockInEndDate?.toIso8601String(),
      'tier_bonus_percent': tierBonusPercent,
      'bonus_consumed': bonusConsumed,
      'bonus_used_loan_id': bonusUsedLoanId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'kyc_verified': kycVerified,
      'savings_criteria_met': savingsCriteriaMet,
      'consecutive_savings_months': consecutiveSavingsMonths,
      'total_savings_amount': totalSavingsAmount,
      'minimum_savings_date': minimumSavingsDate?.toIso8601String(),
    };
  }

  // Calculate tier bonus based on confirmed referral count
  static double calculateTierBonus(int confirmedReferralCount) {
    if (confirmedReferralCount >= 6) return maxBonusPercent;
    if (confirmedReferralCount >= 4) return 3.0;
    if (confirmedReferralCount >= 2) return 2.0;
    return 0;
  }

  // Check if lock-in period is complete
  bool get isLockInComplete {
    if (lockInEndDate == null) return false;
    return DateTime.now().isAfter(lockInEndDate!);
  }

  // Check if bonus is available for use
  bool get isBonusAvailable {
    return confirmed &&
        !bonusConsumed &&
        !isFlagged &&
        isLockInComplete;
  }

  // Get tier description
  String get tierDescription {
    if (tierBonusPercent >= 4.0) return 'Gold Tier (4% OFF)';
    if (tierBonusPercent >= 3.0) return 'Silver Tier (3% OFF)';
    if (tierBonusPercent >= 2.0) return 'Bronze Tier (2% OFF)';
    return 'No Bonus Yet';
  }

  @override
  List<Object?> get props => [
    id,
    referrerId,
    referrerName,
    referredId,
    referredName,
    referralCode,
    confirmed,
    isFlagged,
    flaggedReason,
    confirmationDate,
    lockInEndDate,
    tierBonusPercent,
    bonusConsumed,
    bonusUsedLoanId,
    createdAt,
    updatedAt,
    kycVerified,
    savingsCriteriaMet,
    consecutiveSavingsMonths,
    totalSavingsAmount,
    minimumSavingsDate,
  ];
}

/// Referral Summary for a user
class ReferralSummary extends Equatable {
  final String userId;
  final String referralCode;
  final int pendingReferrals;
  final int confirmedReferrals;
  final int totalReferrals;
  final double currentTierBonus;
  final String currentTierDescription;
  final bool isBonusAvailable;
  final DateTime? nextBonusUnlockDate;
  final List<Referral> recentReferrals;

  const ReferralSummary({
    required this.userId,
    required this.referralCode,
    required this.pendingReferrals,
    required this.confirmedReferrals,
    required this.totalReferrals,
    required this.currentTierBonus,
    required this.currentTierDescription,
    required this.isBonusAvailable,
    this.nextBonusUnlockDate,
    required this.recentReferrals,
  });

  // Progress to next tier
  int get referralsToNextTier {
    if (currentTierBonus >= 4.0) return 0; // Max tier reached
    if (currentTierBonus >= 3.0) return 6 - confirmedReferrals;
    if (currentTierBonus >= 2.0) return 4 - confirmedReferrals;
    return 2 - confirmedReferrals;
  }

  double get progressToNextTier {
    if (currentTierBonus >= 4.0) return 1.0;
    final target = currentTierBonus >= 3.0 ? 6 : (currentTierBonus >= 2.0 ? 4 : 2);
    return (confirmedReferrals / target).clamp(0, 1);
  }

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final referrals = (json['recent_referrals'] as List<dynamic>?)
        ?.map((e) => Referral.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return ReferralSummary(
      userId: json['user_id'] as String,
      referralCode: json['referral_code'] as String,
      pendingReferrals: json['pending_referrals'] as int? ?? 0,
      confirmedReferrals: json['confirmed_referrals'] as int? ?? 0,
      totalReferrals: json['total_referrals'] as int? ?? 0,
      currentTierBonus: (json['current_tier_bonus'] as num?)?.toDouble() ?? 0,
      currentTierDescription: json['current_tier_description'] as String? ?? '',
      isBonusAvailable: json['is_bonus_available'] as bool? ?? false,
      nextBonusUnlockDate: json['next_bonus_unlock_date'] != null
          ? DateTime.parse(json['next_bonus_unlock_date'] as String)
          : null,
      recentReferrals: referrals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'referral_code': referralCode,
      'pending_referrals': pendingReferrals,
      'confirmed_referrals': confirmedReferrals,
      'total_referrals': totalReferrals,
      'current_tier_bonus': currentTierBonus,
      'current_tier_description': currentTierDescription,
      'is_bonus_available': isBonusAvailable,
      'next_bonus_unlock_date': nextBonusUnlockDate?.toIso8601String(),
      'recent_referrals': recentReferrals.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    userId,
    referralCode,
    pendingReferrals,
    confirmedReferrals,
    totalReferrals,
    currentTierBonus,
    currentTierDescription,
    isBonusAvailable,
    nextBonusUnlockDate,
    recentReferrals,
  ];
}

/// Loan Interest Calculation with Referral Bonus
class LoanInterestCalculation extends Equatable {
  final String loanType;
  final double baseInterestRate;
  final double referralBonusPercent;
  final double effectiveInterestRate;
  final double loanAmount;
  final int tenureMonths;
  final double monthlyRepaymentBeforeBonus;
  final double monthlyRepaymentAfterBonus;
  final double totalSavingsFromBonus;
  final double minimumInterestFloor;
  final bool bonusApplied;
  final String? bonusNotAppliedReason;

  const LoanInterestCalculation({
    required this.loanType,
    required this.baseInterestRate,
    required this.referralBonusPercent,
    required this.effectiveInterestRate,
    required this.loanAmount,
    required this.tenureMonths,
    required this.monthlyRepaymentBeforeBonus,
    required this.monthlyRepaymentAfterBonus,
    required this.totalSavingsFromBonus,
    required this.minimumInterestFloor,
    this.bonusApplied = true,
    this.bonusNotAppliedReason,
  });

  // Minimum interest floors per loan type
  static const Map<String, double> minimumInterestFloors = {
    'Quick Loan': 5.0,
    'Flexi Loan': 6.0,
    'Emergency Loan': 7.0,
    'Business Loan': 8.0,
  };

  // Calculate interest with bonus
  static LoanInterestCalculation calculate({
    required String loanType,
    required double baseInterestRate,
    required double referralBonusPercent,
    required double loanAmount,
    required int tenureMonths,
    bool bonusAvailable = true,
    String? bonusNotAppliedReason,
  }) {
    final minimumFloor = minimumInterestFloors[loanType] ?? 5.0;
    
    // Check if bonus can be applied
    bool bonusApplied = bonusAvailable && referralBonusPercent > 0;
    String? reason = bonusNotAppliedReason;
    
    if (!bonusApplied && reason == null && !bonusAvailable) {
      reason = 'Bonus not yet available';
    }

    // Calculate effective rate (cannot go below minimum floor)
    final effectiveRate = bonusApplied
        ? (baseInterestRate - referralBonusPercent).clamp(minimumFloor, baseInterestRate)
        : baseInterestRate;

    // Calculate monthly repayments using simple interest formula
    // EMI = P * r * (1+r)^n / ((1+r)^n - 1)
    final monthlyRate = effectiveRate / 100 / 12;
    final emiAfterBonus = loanAmount * monthlyRate * pow(1 + monthlyRate, tenureMonths) / 
        (pow(1 + monthlyRate, tenureMonths) - 1);
    
    final monthlyRateBefore = baseInterestRate / 100 / 12;
    final emiBeforeBonus = loanAmount * monthlyRateBefore * pow(1 + monthlyRateBefore, tenureMonths) / 
        (pow(1 + monthlyRateBefore, tenureMonths) - 1);

    final totalSavings = (emiBeforeBonus - emiAfterBonus) * tenureMonths;

    return LoanInterestCalculation(
      loanType: loanType,
      baseInterestRate: baseInterestRate,
      referralBonusPercent: referralBonusPercent,
      effectiveInterestRate: effectiveRate,
      loanAmount: loanAmount,
      tenureMonths: tenureMonths,
      monthlyRepaymentBeforeBonus: emiBeforeBonus,
      monthlyRepaymentAfterBonus: emiAfterBonus,
      totalSavingsFromBonus: totalSavings,
      minimumInterestFloor: minimumFloor,
      bonusApplied: bonusApplied,
      bonusNotAppliedReason: reason,
    );
  }

  factory LoanInterestCalculation.fromJson(Map<String, dynamic> json) {
    return LoanInterestCalculation(
      loanType: json['loan_type'] as String,
      baseInterestRate: (json['base_interest_rate'] as num).toDouble(),
      referralBonusPercent: (json['referral_bonus_percent'] as num).toDouble(),
      effectiveInterestRate: (json['effective_interest_rate'] as num).toDouble(),
      loanAmount: (json['loan_amount'] as num).toDouble(),
      tenureMonths: json['tenure_months'] as int,
      monthlyRepaymentBeforeBonus: (json['monthly_repayment_before_bonus'] as num).toDouble(),
      monthlyRepaymentAfterBonus: (json['monthly_repayment_after_bonus'] as num).toDouble(),
      totalSavingsFromBonus: (json['total_savings_from_bonus'] as num).toDouble(),
      minimumInterestFloor: (json['minimum_interest_floor'] as num).toDouble(),
      bonusApplied: json['bonus_applied'] as bool? ?? true,
      bonusNotAppliedReason: json['bonus_not_applied_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loan_type': loanType,
      'base_interest_rate': baseInterestRate,
      'referral_bonus_percent': referralBonusPercent,
      'effective_interest_rate': effectiveInterestRate,
      'loan_amount': loanAmount,
      'tenure_months': tenureMonths,
      'monthly_repayment_before_bonus': monthlyRepaymentBeforeBonus,
      'monthly_repayment_after_bonus': monthlyRepaymentAfterBonus,
      'total_savings_from_bonus': totalSavingsFromBonus,
      'minimum_interest_floor': minimumInterestFloor,
      'bonus_applied': bonusApplied,
      'bonus_not_applied_reason': bonusNotAppliedReason,
    };
  }

  @override
  List<Object?> get props => [
    loanType,
    baseInterestRate,
    referralBonusPercent,
    effectiveInterestRate,
    loanAmount,
    tenureMonths,
    monthlyRepaymentBeforeBonus,
    monthlyRepaymentAfterBonus,
    totalSavingsFromBonus,
    minimumInterestFloor,
    bonusApplied,
    bonusNotAppliedReason,
  ];
}

/// Helper function for power calculation
double pow(double base, int exponent) {
  double result = 1.0;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
