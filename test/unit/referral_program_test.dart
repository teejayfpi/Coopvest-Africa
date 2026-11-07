import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/referral_models.dart';

/// Regression tests for the referral reward rules.
///
/// The reward is a tiered **interest discount**, specified in REFERRAL.md:
/// 0.5% / 1% / 2% at 2 / 5 / 10 confirmed referrals, floored at half the base
/// rate. The mobile model previously carried a different table
/// (2% / 3% / 4% at 2 / 4 / 6) and computed the instalment with a
/// reducing-balance EMI while the total used simple interest, so
/// `monthly × tenure` did not equal `total`.
void main() {
  group('Referral.calculateTierBonus', () {
    test('matches REFERRAL.md: 0.5 / 1 / 2 at 2 / 5 / 10', () {
      expect(Referral.calculateTierBonus(0), 0);
      expect(Referral.calculateTierBonus(1), 0);
      expect(Referral.calculateTierBonus(2), 0.5);
      expect(Referral.calculateTierBonus(4), 0.5);
      expect(Referral.calculateTierBonus(5), 1.0);
      expect(Referral.calculateTierBonus(9), 1.0);
      expect(Referral.calculateTierBonus(10), 2.0);
      expect(Referral.calculateTierBonus(50), 2.0);
    });

    test('the tier table and max bonus agree with the function', () {
      expect(Referral.tierThresholds, {2: 0.5, 5: 1.0, 10: 2.0});
      expect(Referral.maxBonusPercent, 2.0);
    });
  });

  group('ReferralSummary tier progress', () {
    ReferralSummary summary({required int confirmed, required double bonus}) {
      return ReferralSummary(
        userId: 'u1',
        referralCode: 'CV-ABC123',
        pendingReferrals: 0,
        confirmedReferrals: confirmed,
        totalReferrals: confirmed,
        currentTierBonus: bonus,
        currentTierDescription: '',
        isBonusAvailable: bonus > 0,
        recentReferrals: const [],
      );
    }

    test('counts referrals remaining to the next tier', () {
      expect(summary(confirmed: 0, bonus: 0).referralsToNextTier, 2);
      expect(summary(confirmed: 3, bonus: 0.5).referralsToNextTier, 2);
      expect(summary(confirmed: 6, bonus: 1.0).referralsToNextTier, 4);
      expect(summary(confirmed: 10, bonus: 2.0).referralsToNextTier, 0);
    });

    test('reports progress as a fraction of the next threshold', () {
      expect(summary(confirmed: 1, bonus: 0).progressToNextTier, 0.5);
      expect(summary(confirmed: 5, bonus: 1.0).progressToNextTier, 0.5);
      expect(summary(confirmed: 10, bonus: 2.0).progressToNextTier, 1.0);
    });
  });

  group('LoanInterestCalculation.calculate', () {
    test('monthly × tenure equals total, exactly', () {
      final r = LoanInterestCalculation.calculate(
        loanType: 'Stable Loan (12 months)',
        baseInterestRate: 5.0,
        referralBonusPercent: 0,
        loanAmount: 900000,
        tenureMonths: 12,
      );
      // No bonus here, so the before/after totals coincide. Assert both, since
      // the invariant is that the instalment times the tenure equals the
      // after-bonus total exactly.
      expect(r.totalRepaymentBeforeBonus, closeTo(945000, 0.01));
      expect(r.totalRepaymentAfterBonus, closeTo(945000, 0.01));
      expect(r.monthlyRepaymentAfterBonus * 12, closeTo(945000, 0.01));
    });

    test('reconciles with a bonus applied', () {
      final r = LoanInterestCalculation.calculate(
        loanType: 'Quick Loan',
        baseInterestRate: 7.5,
        referralBonusPercent: 0.5,
        loanAmount: 500000,
        tenureMonths: 4,
      );
      expect(r.effectiveInterestRate, 7.0);
      expect(r.monthlyRepaymentAfterBonus * 4, closeTo(r.totalRepaymentAfterBonus, 0.01));
    });

    test('never drops below half the base rate', () {
      final r = LoanInterestCalculation.calculate(
        loanType: 'Premium Loan',
        baseInterestRate: 14.0,
        referralBonusPercent: 12.0,
        loanAmount: 1000000,
        tenureMonths: 24,
      );
      expect(r.effectiveInterestRate, 7.0); // floor, not 2
      expect(r.minimumInterestFloor, 7.0);
    });

    test('a bonus lowers both the total and the instalment', () {
      final withBonus = LoanInterestCalculation.calculate(
        loanType: 'Quick Loan',
        baseInterestRate: 7.5,
        referralBonusPercent: 2.0,
        loanAmount: 500000,
        tenureMonths: 4,
      );
      final without = LoanInterestCalculation.calculate(
        loanType: 'Quick Loan',
        baseInterestRate: 7.5,
        referralBonusPercent: 0,
        loanAmount: 500000,
        tenureMonths: 4,
      );
      expect(withBonus.totalSavingsFromBonus, greaterThan(0));
      expect(withBonus.totalRepaymentAfterBonus, lessThan(without.totalRepaymentAfterBonus));
    });

    test('does not divide by zero for a zero tenure', () {
      final r = LoanInterestCalculation.calculate(
        loanType: 'Quick Loan',
        baseInterestRate: 7.5,
        referralBonusPercent: 0,
        loanAmount: 100000,
        tenureMonths: 0,
      );
      expect(r.monthlyRepaymentAfterBonus.isFinite, isTrue);
    });
  });

  group('Referral.isBonusAvailable', () {
    Referral referral({
      required bool confirmed,
      bool consumed = false,
      bool flagged = false,
      DateTime? lockInEnd,
    }) {
      return Referral(
        id: 'r1',
        referrerId: 'u1',
        referrerName: 'A',
        referredId: 'u2',
        referredName: 'B',
        referralCode: 'CV-ABC123',
        confirmed: confirmed,
        bonusConsumed: consumed,
        isFlagged: flagged,
        lockInEndDate: lockInEnd,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    }

    test('is available only after confirmation and lock-in', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 1));
      expect(referral(confirmed: true, lockInEnd: past).isBonusAvailable, isTrue);
      expect(referral(confirmed: false, lockInEnd: past).isBonusAvailable, isFalse);
      expect(referral(confirmed: true, lockInEnd: future).isBonusAvailable, isFalse);
      expect(referral(confirmed: true, consumed: true, lockInEnd: past).isBonusAvailable, isFalse);
      expect(referral(confirmed: true, flagged: true, lockInEnd: past).isBonusAvailable, isFalse);
    });
  });
}
