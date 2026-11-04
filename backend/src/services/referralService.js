/**
 * Referral Service
 *
 * Handles referral logic, tier calculations, and bonus applications against
 * the Supabase-backed schema (`profiles`, `referrals`, `referral_events`,
 * `audit_logs`, `referral_settings`).
 *
 * The rules implemented here are specified in `REFERRAL.md` at the repository
 * root. If this file and that document disagree, this file is wrong.
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

// The single authoritative tier table. REFERRAL.md §1.
// Ordered descending by threshold; the first row that applies wins.
const REFERRAL_TIERS = [
  { minConfirmed: 10, bonusPercent: 2.0 },
  { minConfirmed: 5, bonusPercent: 1.0 },
  { minConfirmed: 2, bonusPercent: 0.5 },
  { minConfirmed: 0, bonusPercent: 0 },
];
const MAX_BONUS_PERCENT = 2.0;

const LOCK_IN_DAYS = 30;
const MINIMUM_SAVINGS_MONTHS = 3;

class ReferralService {
  getBaseInterestRate(loanType) { return BASE_RATES[loanType] ?? DEFAULT_BASE_RATE; }
  getMinimumInterestFloor(loanType) { return MIN_FLOORS[loanType] ?? DEFAULT_MIN_FLOOR; }

  /** Tier table, descending by threshold — for admin display and tests. */
  getTierTable() { return REFERRAL_TIERS.map((t) => ({ ...t })); }

  /** Referral tier bonus for a confirmed-referral count. REFERRAL.md §1. */
  calculateTierBonus(count) {
    const n = Number(count) || 0;
    const tier = REFERRAL_TIERS.find((t) => n >= t.minConfirmed);
    return tier ? tier.bonusPercent : 0;
  }

  /** Progress toward the next tier, for the member-facing UI. */
  tierProgress(count) {
    const n = Number(count) || 0;
    const bonusPercent = this.calculateTierBonus(n);
    const next = REFERRAL_TIERS
      .filter((t) => t.minConfirmed > n)
      .sort((a, b) => a.minConfirmed - b.minConfirmed)[0];
    return {
      confirmedReferrals: n,
      bonusPercent,
      isMaxTier: bonusPercent >= MAX_BONUS_PERCENT,
      nextTierAt: next ? next.minConfirmed : null,
      nextTierBonus: next ? next.bonusPercent : null,
      referralsToNextTier: next ? Math.max(0, next.minConfirmed - n) : 0,
    };
  }

  /**
   * Is an event's lock-in complete? A missing `lock_in_end_date` is treated as
   * complete (legacy rows predate the column).
   */
  isLockInComplete(event, now = new Date()) {
    const end = event?.lock_in_end_date;
    if (!end) return true;
    return new Date(end).getTime() <= new Date(now).getTime();
  }

  /**
   * Can this event be spent on a loan? Confirmed, unflagged, unconsumed, and
   * past lock-in. REFERRAL.md §2.
   */
  isEventConsumable(event, now = new Date()) {
    if (!event) return false;
    return event.confirmed === true
      && event.is_flagged !== true
      && event.bonus_consumed !== true
      && this.isLockInComplete(event, now);
  }

  /** Has a referrer reached the configured cap? 0 or unset means no cap. */
  isAtReferralCap(existingCount, cap) {
    const limit = Number(cap) || 0;
    if (limit <= 0) return false;
    return Number(existingCount) >= limit;
  }

  /** Qualification rules for a referred member. REFERRAL.md §2. */
  evaluateQualification({ kycVerified, consecutiveSavingsMonths }, requiredMonths = MINIMUM_SAVINGS_MONTHS) {
    const months = Number(consecutiveSavingsMonths) || 0;
    const kycOk = kycVerified === true;
    const savingsOk = months >= requiredMonths;
    return {
      qualified: kycOk && savingsOk,
      kycVerified: kycOk,
      savingsCriteriaMet: savingsOk,
      consecutiveSavingsMonths: months,
      requiredSavingsMonths: requiredMonths,
    };
  }

  /** May this event be confirmed now? Lock-in elapsed AND referred member qualifies. */
  canConfirm(event, qualification, now = new Date()) {
    if (!event) return { ok: false, reason: 'Referral not found' };
    if (event.confirmed === true) return { ok: false, reason: 'Referral already confirmed' };
    if (event.is_flagged === true) return { ok: false, reason: 'Referral is flagged' };
    if (!this.isLockInComplete(event, now)) return { ok: false, reason: 'Lock-in period has not elapsed' };
    if (!qualification?.qualified) {
      return { ok: false, reason: 'Referred member has not met the qualification criteria' };
    }
    return { ok: true };
  }

  calculateInterestWithBonus(loanType, loanAmount, tenureMonths, bonusPercent) {
    const baseRate = this.getBaseInterestRate(loanType);
    const minimumFloor = this.getMinimumInterestFloor(loanType);
    const effectiveRate = bonusPercent > 0
      ? Math.max(baseRate - bonusPercent, minimumFloor)
      : baseRate;

    // Total repayment is the authoritative figure: simple interest
    // (amount + amount * rate / 100). This is what `loans.total_repayment`
    // holds and what `remaining_balance` is drawn down against.
    const totalRepayment = loanAmount + (loanAmount * effectiveRate / 100);
    const totalRepaymentBase = loanAmount + (loanAmount * baseRate / 100);

    // The instalment is derived FROM the total, not from a separate
    // reducing-balance EMI. Those two used to be computed independently and
    // disagreed — at ₦900,000 / 5% / 12 months the EMI instalment summed to
    // ₦924,560.76 against a ₦945,000 total (₦20,439 short), and on a Maxi loan
    // it over-repaid by ₦129,617. The member's summary, the repayment
    // schedule, the wallet's monthly obligation and the admin reports all read
    // `monthly_repayment`, while arrears and the balance read
    // `total_repayment`, so the two must reconcile by construction:
    // `monthlyRepayment × tenureMonths === totalRepayment`, exactly.
    const tenure = Number(tenureMonths) > 0 ? Number(tenureMonths) : 1;
    const monthlyRepayment = totalRepayment / tenure;
    const monthlyRepaymentBase = totalRepaymentBase / tenure;

    const totalSavingsFromBonus = Math.max(0, totalRepaymentBase - totalRepayment);

    return {
      loanType,
      baseInterestRate: baseRate,
      referralBonusPercent: bonusPercent,
      effectiveInterestRate: effectiveRate,
      loanAmount,
      tenureMonths,
      monthlyRepaymentBeforeBonus: monthlyRepaymentBase,
      monthlyRepaymentAfterBonus: monthlyRepayment,
      totalRepayment,
      totalRepaymentBeforeBonus: totalRepaymentBase,
      totalSavingsFromBonus,
      minimumInterestFloor: minimumFloor,
      bonusApplied: bonusPercent > 0,
    };
  }

  /**
   * Read the single-row program settings. Defaults to enabled with no bonus.
   *
   * The live table uses `program_enabled` (the older column name); `enabled` is
   * accepted too so the code works against either. Writing `enabled` to the
   * live table fails with "column does not exist", which is why the admin
   * settings page could not save.
   */
  async getProgramSettings() {
    try {
      const { data, error } = await supabase
        .from('referral_settings')
        .select('*')
        .limit(1)
        .maybeSingle();
      if (error && error.code !== 'PGRST116') throw error;
      const enabledFlag = data?.program_enabled ?? data?.enabled;
      return {
        enabled: enabledFlag !== false,
        bonusPerReferral: Number(data?.bonus_per_referral) || 0,
        maxReferralsPerUser: Number(data?.max_referrals_per_user) || 0,
      };
    } catch (err) {
      logger.warn('referralService: referral_settings read failed:', err.message);
      return { enabled: true, bonusPerReferral: 0, maxReferralsPerUser: 0 };
    }
  }

  /** Human-readable tier label for the member-facing dashboard. */
  describeTier(bonusPercent) {
    const p = Number(bonusPercent) || 0;
    if (p >= 2) return 'Gold Tier (2% OFF)';
    if (p >= 1) return 'Silver Tier (1% OFF)';
    if (p >= 0.5) return 'Bronze Tier (0.5% OFF)';
    return 'No Bonus Yet';
  }

  /**
   * The member-facing summary. Field names are snake_case because the Flutter
   * client (`ReferralSummary.fromJson`) reads exactly these keys; a camelCase
   * response parsed to an all-zero summary and the dashboard showed
   * "None / 0% discount" for everyone.
   */
  async getReferralSummary(profileId) {
    const { data, error } = await supabase
      .from('referrals')
      .select('*')
      .eq('profile_id', profileId)
      .maybeSingle();
    if (error && error.code !== 'PGRST116') throw error;

    // Availability is computed from the events, not just the cached tier: the
    // bonus is only spendable once an event is confirmed AND past lock-in.
    let events = [];
    try {
      const { data: rows } = await supabase
        .from('referral_events')
        .select('confirmed, is_flagged, bonus_consumed, lock_in_end_date')
        .eq('referrer_id', profileId)
        .eq('confirmed', true)
        .eq('is_flagged', false)
        .eq('bonus_consumed', false);
      events = rows || [];
    } catch (err) {
      logger.warn('referralService: referral_events read failed:', err.message);
    }

    const now = new Date();
    const spendableCount = events.filter((e) => this.isEventConsumable(e, now)).length;
    const confirmedCount = Number(data?.confirmed_referral_count) || 0;
    const totalCount = Number(data?.referral_count) || 0;
    const tierBonus = this.calculateTierBonus(confirmedCount);

    let recentReferrals = [];
    let nextUnlock = null;
    try {
      const { data: recentRows } = await supabase
        .from('referral_events')
        .select('*')
        .eq('referrer_id', profileId)
        .order('created_at', { ascending: false })
        .limit(10);
      recentReferrals = (recentRows || []).map((e) => ({
        id: e.id,
        referrer_id: e.referrer_id,
        // The client casts these to non-null String, so never send null.
        referrer_name: '',
        referred_id: e.referred_id,
        referred_name: e.referred_name || '',
        referral_code: e.referral_code || '',
        confirmed: e.confirmed === true,
        is_flagged: e.is_flagged === true,
        flagged_reason: e.flagged_reason || null,
        confirmation_date: e.confirmed_at || null,
        lock_in_end_date: e.lock_in_end_date || null,
        tier_bonus_percent: Number(e.tier_bonus_percent) || 0,
        bonus_consumed: e.bonus_consumed === true,
        bonus_used_loan_id: e.bonus_used_loan_id || null,
        created_at: e.created_at || new Date().toISOString(),
        updated_at: e.updated_at || e.created_at || new Date().toISOString(),
        kyc_verified: false,
        savings_criteria_met: false,
        consecutive_savings_months: 0,
        total_savings_amount: 0,
        minimum_savings_date: null,
      }));

      nextUnlock = (recentRows || [])
        .filter((e) => e.confirmed !== true && e.is_flagged !== true && e.lock_in_end_date)
        .map((e) => new Date(e.lock_in_end_date).getTime())
        .sort((a, b) => a - b)[0];
    } catch (err) {
      logger.warn('referralService: recent referrals read failed:', err.message);
    }

    return {
      summary: {
        user_id: profileId,
        referral_code: data?.my_referral_code || '',
        pending_referrals: Math.max(0, totalCount - confirmedCount),
        confirmed_referrals: confirmedCount,
        total_referrals: totalCount,
        current_tier_bonus: tierBonus,
        current_tier_description: this.describeTier(tierBonus),
        is_bonus_available: spendableCount > 0 && tierBonus > 0,
        next_bonus_unlock_date: nextUnlock ? new Date(nextUnlock).toISOString() : null,
        recent_referrals: recentReferrals,
      },
    };
  }

  async applyBonusToLoan(profileId, loanId, loanType) {
    const { summary } = await this.getReferralSummary(profileId);
    const bonusPercent = summary.current_tier_bonus;

    if (!summary.is_bonus_available || bonusPercent <= 0) {
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

    // Consume the oldest spendable (confirmed, unflagged, unconsumed, past
    // lock-in) referral for this user.
    const { data: candidates } = await supabase
      .from('referral_events')
      .select('*')
      .eq('referrer_id', profileId)
      .eq('confirmed', true)
      .eq('is_flagged', false)
      .eq('bonus_consumed', false)
      .order('confirmed_at', { ascending: true });
    const event = (candidates || []).find((e) => this.isEventConsumable(e));

    if (!event) {
      return { success: false, bonusApplied: false, error: 'No referral bonus available' };
    }

    await supabase
      .from('referral_events')
      .update({ bonus_consumed: true, consumed_at: new Date().toISOString() })
      .eq('id', event.id);

    await this.logAuditEvent('BONUS_CONSUMED', profileId, {
      referralId: event.referral_id,
      loanId,
      bonusPercent,
    }, `Bonus of ${bonusPercent}% applied to loan ${loanId}`);

    return {
      success: true,
      bonusApplied: true,
      bonusPercent,
      effectiveInterestRate: baseRate - bonusPercent,
      loanId,
      message: `Referral bonus of ${bonusPercent}% applied successfully`,
    };
  }

  /** Recompute a referrer's confirmed count and tier from their events. */
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

  /**
   * Record a referral relationship. Shared by signup attribution and the
   * `/referrals/claim` endpoint. REFERRAL.md §2.
   */
  async attributeReferral({ referralCode, referredProfileId, referredName }) {
    const settings = await this.getProgramSettings();
    if (!settings.enabled) {
      return { success: false, error: 'The referral program is currently disabled' };
    }

    const { data: referrer, error: rErr } = await supabase
      .from('referrals')
      .select('profile_id, referral_count')
      .eq('my_referral_code', referralCode)
      .maybeSingle();
    if (rErr) throw rErr;
    if (!referrer) return { success: false, error: 'Referral code not found' };

    const abuse = await this.checkForAbuse(referrer.profile_id, referredProfileId);
    if (abuse.isDuplicate) return { success: false, error: abuse.reason };

    // Enforce the per-referrer cap. It was read from settings and displayed but
    // never checked, so the setting did nothing. 0 means "no cap".
    const cap = Number(settings.maxReferralsPerUser) || 0;
    if (cap > 0) {
      const { count, error: cErr } = await supabase
        .from('referral_events')
        .select('id', { count: 'exact', head: true })
        .eq('referrer_id', referrer.profile_id);
      if (cErr) throw cErr;
      if (this.isAtReferralCap(count, cap)) {
        return { success: false, error: 'This referrer has reached the maximum number of referrals' };
      }
    }

    const lockInEnd = new Date();
    lockInEnd.setDate(lockInEnd.getDate() + LOCK_IN_DAYS);

    const { data: event, error } = await supabase
      .from('referral_events')
      .insert({
        referral_id: `REF-${Date.now()}`,
        referrer_id: referrer.profile_id,
        referred_id: referredProfileId,
        referred_name: referredName || null,
        referral_code: referralCode,
        confirmed: false,
        is_flagged: false,
        bonus_consumed: false,
        lock_in_end_date: lockInEnd.toISOString(),
      })
      .select('*')
      .single();
    if (error) throw error;

    await supabase
      .from('referrals')
      .update({ referral_count: (referrer.referral_count || 0) + 1 })
      .eq('profile_id', referrer.profile_id);

    return { success: true, event };
  }

  /** Qualification snapshot for a referred member, read from their own rows. */
  async getQualification(referredProfileId) {
    let kycVerified = false;
    let consecutiveMonths = 0;
    try {
      const { data: profile } = await supabase
        .from('profiles')
        .select('kyc_verified')
        .eq('id', referredProfileId)
        .maybeSingle();
      kycVerified = profile?.kyc_verified === true;

      const { data: savings } = await supabase
        .from('savings')
        .select('consecutive_months')
        .eq('profile_id', referredProfileId)
        .maybeSingle();
      consecutiveMonths = Number(savings?.consecutive_months) || 0;
    } catch (err) {
      logger.warn('referralService: qualification lookup failed:', err.message);
    }
    return this.evaluateQualification({ kycVerified, consecutiveSavingsMonths: consecutiveMonths });
  }

  /**
   * Confirm a referral event, enforcing lock-in and qualification, then
   * refresh the referrer's tier. REFERRAL.md §2.
   */
  async confirmReferralEvent(eventId) {
    const { data: event, error } = await supabase
      .from('referral_events')
      .select('*')
      .eq('id', eventId)
      .maybeSingle();
    if (error) throw error;
    if (!event) return { success: false, error: 'Referral not found' };

    const qualification = await this.getQualification(event.referred_id);
    const gate = this.canConfirm(event, qualification);
    if (!gate.ok) return { success: false, error: gate.reason, qualification };

    const { data: updated, error: uErr } = await supabase
      .from('referral_events')
      .update({ confirmed: true, confirmed_at: new Date().toISOString() })
      .eq('id', eventId)
      .select('*')
      .single();
    if (uErr) throw uErr;

    await this.updateReferrerTier(event.referrer_id);
    return { success: true, event: updated, qualification };
  }

  async getShareLink(profileId) {
    const { data: referral } = await supabase
      .from('referrals')
      .select('my_referral_code')
      .eq('profile_id', profileId)
      .maybeSingle();

    const referralCode = referral?.my_referral_code;
    if (!referralCode) throw new Error('Referral code not found');

    const baseUrl = process.env.APP_BASE_URL || 'https://coopvestafrica.com';
    return {
      success: true,
      referralCode,
      shareLink: `${baseUrl}/join?ref=${referralCode}`,
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

const service = new ReferralService();
service.REFERRAL_TIERS = REFERRAL_TIERS;
service.BASE_RATES = BASE_RATES;
service.MIN_FLOORS = MIN_FLOORS;
service.LOCK_IN_DAYS = LOCK_IN_DAYS;
service.MINIMUM_SAVINGS_MONTHS = MINIMUM_SAVINGS_MONTHS;

module.exports = service;
