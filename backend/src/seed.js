/**
 * Database Seeding Script
 * 
 * Initializes the database with sample data for development and testing.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { User, Wallet, Loan, AuditLog } = require('./models');
const connectDB = require('./config/database');
const logger = require('./utils/logger');

const seedData = async () => {
  try {
    // Connect to Database
    await connectDB();
    logger.info('Connected to database for seeding...');

    // Clear existing data (Optional - use with caution)
    // await User.deleteMany({});
    // await Wallet.deleteMany({});
    // await Loan.deleteMany({});
    // await AuditLog.deleteMany({});
    // logger.info('Cleared existing data');

    // 1. Create Admin User
    const adminId = 'USR-ADMIN-001';
    let admin = await User.findOne({ userId: adminId });
    if (!admin) {
      admin = new User({
        userId: adminId,
        email: 'admin@coopvest.africa',
        phone: '+2348000000001',
        name: 'System Admin',
        password: 'AdminPassword123!', // Note: User model should hash this
        role: 'admin',
        isActive: true,
        kyc: { verified: true, verifiedAt: new Date() },
        emailVerification: { isVerified: true },
        referral: {
          myReferralCode: 'COOPADMIN'
        }
      });
      await admin.save();
      logger.info('Admin user created');
    }

    // 2. Create Sample Member
    const memberId = 'USR-MEMBER-001';
    let member = await User.findOne({ userId: memberId });
    if (!member) {
      member = new User({
        userId: memberId,
        email: 'member@example.com',
        phone: '+2348000000002',
        name: 'John Doe',
        password: 'MemberPassword123!',
        role: 'member',
        isActive: true,
        kyc: { verified: true, verifiedAt: new Date() },
        emailVerification: { isVerified: true },
        referral: {
          myReferralCode: 'JOHNDOE123',
          referredBy: adminId,
          referredByCode: 'COOPADMIN'
        },
        savings: {
          totalSaved: 15000,
          consecutiveMonths: 4,
          firstSavingsDate: new Date(new Date().setMonth(new Date().getMonth() - 4))
        }
      });
      await member.save();
      logger.info('Sample member created');
    }

    // 3. Initialize Wallet for Member
    let wallet = await Wallet.findOne({ userId: memberId });
    if (!wallet) {
      wallet = new Wallet({
        userId: memberId,
        balance: 5000,
        currency: 'NGN',
        transactions: [
          {
            transactionId: 'TXN-' + Math.random().toString(36).substr(2, 9).toUpperCase(),
            type: 'deposit',
            amount: 5000,
            status: 'completed',
            description: 'Initial deposit',
            timestamp: new Date()
          }
        ]
      });
      await wallet.save();
      logger.info('Wallet initialized for member');
    }

    // 4. Create Sample Loan for Member
    let loan = await Loan.findOne({ userId: memberId });
    if (!loan) {
      loan = new Loan({
        loanId: 'LOAN-SAMPLE-001',
        userId: memberId,
        loanType: 'Quick Loan',
        amount: 50000,
        tenureMonths: 6,
        purpose: 'Business expansion',
        baseInterestRate: 10,
        referralBonusPercent: 2,
        effectiveInterestRate: 8,
        monthlyRepayment: 9000,
        totalRepayment: 54000,
        savingsFromBonus: 1200,
        status: 'active'
      });
      await loan.save();
      logger.info('Sample loan created');
    }

    logger.info('✅ Seeding completed successfully!');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Seeding failed:', error);
    process.exit(1);
  }
};

seedData();
