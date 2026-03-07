/**
 * Referral Service
 * 
 * Handles referral logic, tier calculations, and bonus applications
 */

const { Referral, User } = require('../models');
const logger = require('../utils/logger');
const AuditLog = require('../models/AuditLog');

class ReferralService {
  /**
   * Apply referral bonus to a loan
   */
  async applyBonusToLoan(userId, loanId, loanType) {
    try {
      // Get user's current tier bonus
      const summary = await this.getReferralSummary(userId);
      const bonusPercent = summary.summary.currentTierBonus;
      const isBonusAvailable = summary.summary.isBonusAvailable;

      if (!isBonusAvailable || bonusPercent <= 0) {
        return {
          success: false,
          error: 'No referral bonus available',
          bonusApplied: false
        };
      }

      // Check minimum interest floor for loan type
      const minimumFloor = this.getMinimumInterestFloor(loanType);
      const baseRate = this.getBaseInterestRate(loanType);
      
      if (baseRate - bonusPercent < minimumFloor) {
        return {
          success: false,
          error: `Cannot apply ${bonusPercent}% bonus. Minimum interest floor for ${loanType} is ${minimumFloor}%`,
          bonusApplied: false,
          minimumFloor
        };
      }

      // Mark bonus as consumed
      const referral = await Referral.findOne({
        referrerId: userId,
        confirmed: true,
        isFlagged: false,
        bonusConsumed: false,
        lockInEndDate: { $lte: new Date() }
      });

      if (referral) {
        await referral.applyBonusToLoan(loanId);
        
        // Update all referrals for this user to current tier
        await Referral.updateUserTierBonuses(userId);

        // Log the action
        await this.logAuditEvent('BONUS_CONSUMED', referral.referralId, userId, null, loanId,
          `Bonus of ${bonusPercent}% applied to loan ${loanId}`);

        logger.info(`Bonus applied to loan ${loanId}: ${bonusPercent}%`);
      }

      return {
        success: true,
        bonusApplied: true,
        bonusPercent,
        effectiveInterestRate: baseRate - bonusPercent,
        loanId,
        message: `Referral bonus of ${bonusPercent}% applied successfully`
      };
    } catch (error) {
      logger.error('Error applying bonus to loan:', error.message);
      throw error;
    }
  }

  /**
   * Calculate loan interest with referral bonus
   */
  calculateInterestWithBonus(loanType, loanAmount, tenureMonths, bonusPercent) {
    const baseRate = this.getBaseInterestRate(loanType);
    const minimumFloor = this.getMinimumInterestFloor(loanType);
    
    // Calculate effective rate (cannot go below minimum floor)
    const effectiveRate = bonusPercent > 0 
      ? Math.max(baseRate - bonusPercent, minimumFloor)
      : baseRate;

    // Calculate EMI using standard formula
    const monthlyRate = effectiveRate / 100 / 12;
    const emi = loanAmount * monthlyRate * Math.pow(1 + monthlyRate, tenureMonths) / 
                (Math.pow(1 + monthlyRate, tenureMonths) - 1);

    const monthlyRateBefore = baseRate / 100 / 12;
    const emiBeforeBonus = loanAmount * monthlyRateBefore * Math.pow(1 + monthlyRateBefore, tenureMonths) / 
                           (Math.pow(1 + monthlyRateBefore, tenureMonths) - 1);

    const totalSavingsFromBonus = (emiBeforeBonus - emi) * tenureMonths;

    return {
      loanType,
      baseInterestRate: baseRate,
      referralBonusPercent: bonusPercent,
      effectiveInterestRate: effectiveRate,
      loanAmount,
      tenureMonths,
      monthlyRepaymentBeforeBonus: emiBeforeBonus,
      monthlyRepaymentAfterBonus: emi,
      totalSavingsFromBonus,
      minimumInterestFloor: minimumFloor,
      bonusApplied: bonusPercent > 0
    };
  }

  /**
   * Get share link for referral
   */
  async getShareLink(userId) {
    try {
      const user = await User.findOne({ userId });
      if (!user) {
        throw new Error('User not found');
      }

      const referralCode = user.referral.myReferralCode;
      const baseUrl = process.env.API_BASE_URL || 'https://coopvest.app';
      const shareLink = `${baseUrl}/register?ref=${referralCode}`;

      return {
        success: true,
        referralCode,
        shareLink,
        qrCodeUrl: `${baseUrl}/api/v1/referrals/qr/${referralCode}`
      };
    } catch (error) {
      logger.error('Error getting share link:', error.message);
      throw error;
    }
  }

  /**
   * Update referrer's tier after new confirmation
   */
  async updateReferrerTier(referrerId) {
    try {
      // Count confirmed referrals
      const confirmedCount = await Referral.countDocuments({
        referrerId,
        confirmed: true,
        isFlagged: false
      });

      // Calculate new tier bonus
      const tierBonus = this.calculateTierBonus(confirmedCount);

      // Update referrer's profile
      await User.findOneAndUpdate(
        { userId: referrerId },
        {
          'referral.confirmedReferralCount': confirmedCount,
          'referral.currentTierBonus': tierBonus
        }
      );

      // Update all unconsumed referrals for this user
      await Referral.updateUserTierBonuses(referrerId);

      // Log tier update
      await this.logAuditEvent('TIER_UPDATED', null, referrerId, null,
        `User reached ${confirmedCount} confirmed referrals. Tier bonus: ${tierBonus}%`);

      return tierBonus;
    } catch (error) {
      logger.error('Error updating referrer tier:', error.message);
      throw error;
    }
  }

  /**
   * Check for abuse (self-referral, duplicate accounts)
   */
  async checkForAbuse(referrerId, referredUserId) {
    // Check self-referral
    if (referrerId === referredUserId) {
      return { isDuplicate: true, reason: 'Self-referral' };
    }

    // Check if referred user was already referred by someone else
    const existingReferral = await Referral.findOne({ referredId: referredUserId });
    if (existingReferral) {
      return { isDuplicate: true, reason: 'Already referred by another user' };
    }
    
    return { isDuplicate: false };
  }

  // Helper methods
  getBaseInterestRate(loanType) {
    const rates = { 'PERSONAL': 15, 'EMERGENCY': 12, 'BUSINESS': 18 };
    return rates[loanType] || 15;
  }

  getMinimumInterestFloor(loanType) {
    const floors = { 'PERSONAL': 5, 'EMERGENCY': 4, 'BUSINESS': 7 };
    return floors[loanType] || 5;
  }

  calculateTierBonus(count) {
    if (count >= 50) return 5;
    if (count >= 20) return 3;
    if (count >= 10) return 2;
    if (count >= 5) return 1;
    return 0;
  }

  async getReferralSummary(userId) {
    const user = await User.findOne({ userId });
    return {
      summary: {
        currentTierBonus: user?.referral?.currentTierBonus || 0,
        isBonusAvailable: true
      }
    };
  }

  async logAuditEvent(action, referralId, userId, adminId, loanId, details) {
    await AuditLog.create({
      action,
      referralId,
      userId,
      adminId,
      loanId,
      details,
      timestamp: new Date()
    });
  }
}

module.exports = new ReferralService();
