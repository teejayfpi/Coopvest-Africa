/**
 * Referral Service
 *
 * Handles referral logic, tier calculations, and bonus applications against
 * the Supabase-backed schema (`profiles`, `referrals`, `referral_events`,
 * `audit_logs`).
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

// Interest rate table keyed by loan type.
// Mirrors the mobile app (lib/presentation/screens/loan/loan_application_screen.dart)
// so the admin dashboard and the member's app always show identical figures.
const BASE_RATES = {
  'Quick Loan': 7.5,
  'Flexi Loan': 7.0,
  'Stable Loan (12 months)': 5.0,
  'Stable Loan (18 months)': 7.0,
  'Premium Loan': 14.0,
  'Maxi Loan': 19.0,
  // Legacy types kept for backward compatibility with older loans.
  'Micro Loan': 18,
  'Business Loan': 20,
  'Emergency Loan': 12,
};
const DEFAULT_BASE_RATE = 7.5;
// Minimum interest floor = half of each type's base rate (never drops below 50% off).
const MIN_FLOORS = Object.fromEntries(
  Object.entries(BASE_RATES).map(([k, v]) => [k, v / 2])
);
const DEFAULT_MIN_FLOOR = 2.5;

class ReferralService {
  getBaseInterestRate(loanType) { return BASE_RATES[loanType] ?? DEFAULT_BASE_RATE; }
  getMinimumInterestFloor(loanType) { return MIN_FLOORS[loanType] ?? DEFAULT_MIN_FLOOR; }

  // Referral tiers mirror the mobile app: 2% / 1% / 0.5% at 10 / 5 / 2 confirmed referrals.
  calculateTierBonus(count) {
    if (count >= 10) return 2;
    if (count >= 5) return 1;
    if (count >= 2) return 0.5;
    return 0;
  }

  calculateInterestWithBonus(loanType, loanAmount, tenureMonths, bonusPercent) {
    const baseRate = this.getBaseInterestRate(loanType);
    const minimumFloor = this.getMinimumInterestFloor(loanType);
    const effectiveRate = bonusPercent > 0
      ? Math.max(baseRate - bonusPercent, minimumFloor)
      : baseRate;

    // Monthly repayment: EMI (reducing balance) — matches the mobile app.
    const mRate = effectiveRate / 100 / 12;
    const emi = mRate === 0
      ? loanAmount / tenureMonths
      : loanAmount * mRate * Math.pow(1 + mRate, tenureMonths) / (Math.pow(1 + mRate, tenureMonths) - 1);

    const mRateBase = baseRate / 100 / 12;
    const emiBase = mRateBase === 0
      ? loanAmount / tenureMonths
      : loanAmount * mRateBase * Math.pow(1 + mRateBase, tenureMonths) / (Math.pow(1 + mRateBase, tenureMonths) - 1);

    // Total repayment: simple interest — matches the mobile app
    // (amount + amount * rate / 100), NOT EMI * tenure.
    const totalRepayment = loanAmount + (loanAmount * effectiveRate / 100);
    const totalRepaymentBase = loanAmount + (loanAmount * baseRate / 100);
    const totalSavingsFromBonus = Math.max(0, totalRepaymentBase - totalRepayment);

    return {
      loanType,
      baseInterestRate: baseRate,
      referralBonusPercent: bonusPercent,
      effectiveInterestRate: effectiveRate,
      loanAmount,
      tenureMonths,
      monthlyRepaymentBeforeBonus: emiBase,
      monthlyRepaymentAfterBonus: emi,
      totalRepayment,
      totalRepaymentBeforeBonus: totalRepaymentBase,
      totalSavingsFromBonus,
      minimumInterestFloor: minimumFloor,
      bonusApplied: bonusPercent > 0,
    };
  }

  async getReferralSummary(profileId) {
    const { data, error } = await supabase
      .from('referrals')
      .select('*')
      .eq('profile_id', profileId)
      .maybeSingle();
    if (error && error.code !== 'PGRST116') throw error;

    return {
      summary: {
        myReferralCode: data?.my_referral_code || null,
        referralCount: data?.referral_count || 0,
        confirmedReferralCount: data?.confirmed_referral_count || 0,
        currentTierBonus: Number(data?.current_tier_bonus) || 0,
        isBonusAvailable: (Number(data?.current_tier_bonus) || 0) > 0,
      },
    };
  }

  async applyBonusToLoan(profileId, loanId, loanType) {
    const { summary } = await this.getReferralSummary(profileId);
    const bonusPercent = summary.currentTierBonus;

    if (!summary.isBonusAvailable || bonusPercent <= 0) {
      return { success: false, bonusApplied: false, error: 'No referral bonus available' };
    }

    const minimumFloor = this.getMinimumInterestFloor(loanType);
    const baseRate = this.getBaseInterestRate(loanType);
    if (baseRate - bonusPercent < minimumFloor) {
      return {
        success: false,
        bonusApplied: false,
        minimumFloor,
        error: `Cannot apply ${bonusPercent}% bonus. Minimum interest floor for ${loanType} is ${minimumFloor}%`,
      };
    }

    // Consume the oldest unconsumed, confirmed, non-flagged referral for this user.
    const { data: event } = await supabase
      .from('referral_events')
      .select('*')
      .eq('referrer_id', profileId)
      .eq('confirmed', true)
      .eq('is_flagged', false)
      .eq('bonus_consumed', false)
      .order('confirmed_at', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (event) {
      await supabase
        .from('referral_events')
        .update({ bonus_consumed: true, consumed_at: new Date().toISOString() })
        .eq('id', event.id);

      await this.logAuditEvent('BONUS_CONSUMED', profileId, {
        referralId: event.referral_id,
        loanId,
        bonusPercent,
      }, `Bonus of ${bonusPercent}% applied to loan ${loanId}`);
    }

    return {
      success: true,
      bonusApplied: true,
      bonusPercent,
      effectiveInterestRate: baseRate - bonusPercent,
      loanId,
      message: `Referral bonus of ${bonusPercent}% applied successfully`,
    };
  }

  async updateReferrerTier(referrerProfileId) {
    const { count, error: countError } = await supabase
      .from('referral_events')
      .select('id', { count: 'exact', head: true })
      .eq('referrer_id', referrerProfileId)
      .eq('confirmed', true)
      .eq('is_flagged', false);
    if (countError) throw countError;

    const tierBonus = this.calculateTierBonus(count || 0);

    await supabase
      .from('referrals')
      .upsert(
        {
          profile_id: referrerProfileId,
          confirmed_referral_count: count || 0,
          current_tier_bonus: tierBonus,
        },
        { onConflict: 'profile_id' }
      );

    await this.logAuditEvent('TIER_UPDATED', referrerProfileId, { count, tierBonus },
      `User reached ${count} confirmed referrals. Tier bonus: ${tierBonus}%`);
    return tierBonus;
  }

  async checkForAbuse(referrerProfileId, referredProfileId) {
    if (referrerProfileId === referredProfileId) {
      return { isDuplicate: true, reason: 'Self-referral' };
    }
    const { data: existing } = await supabase
      .from('referral_events')
      .select('id')
      .eq('referred_id', referredProfileId)
      .maybeSingle();
    if (existing) return { isDuplicate: true, reason: 'Already referred by another user' };
    return { isDuplicate: false };
  }

  async getShareLink(profileId) {
    const { data: referral } = await supabase
      .from('referrals')
      .select('my_referral_code')
      .eq('profile_id', profileId)
      .maybeSingle();

    const referralCode = referral?.my_referral_code;
    if (!referralCode) throw new Error('Referral code not found');

    const baseUrl = process.env.API_BASE_URL || 'https://coopvest.app';
    return {
      success: true,
      referralCode,
      shareLink: `${baseUrl}/register?ref=${referralCode}`,
      qrCodeUrl: `${baseUrl}/api/v1/referrals/qr/${referralCode}`,
    };
  }

  async logAuditEvent(action, actorProfileId, metadata = {}, details) {
    try {
      await supabase.from('audit_logs').insert({
        actor_id: actorProfileId,
        action,
        target_model: 'Referral',
        target_id: metadata.referralId || null,
        metadata: { ...metadata, details: details || null },
      });
    } catch (err) {
      logger.warn('audit_logs insert failed:', err.message);
    }
  }
}

module.exports = new ReferralService();
