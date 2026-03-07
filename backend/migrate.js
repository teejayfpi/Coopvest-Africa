/**
 * Database Migration Script
 * 
 * This script handles database schema migrations for the Coopvest Africa API.
 * Run this script when deploying new versions that require schema changes.
 * 
 * Usage:
 *   npm run migrate                    - Run pending migrations
 *   npm run migrate:status             - Check migration status
 *   npm run migrate:rollback           - Rollback last migration (if implemented)
 *   npm run migrate:seed-admin         - Seed admin users
 */

require('dotenv').config();
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const bcrypt = require('bcryptjs');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/coopvest';

// Migration state tracking
const migrations = [
  {
    name: '001_initial_schema',
    description: 'Initial schema setup with users, loans, referrals, tickets',
    timestamp: new Date('2026-01-01'),
    up: async () => {
      logger.info('Running initial schema migration...');
      // Initial schema is defined in models, no action needed
      logger.info('Initial schema migration complete');
    }
  },
  {
    name: '002_add_audit_fields',
    description: 'Add audit and timestamp fields to all schemas',
    timestamp: new Date('2026-01-15'),
    up: async () => {
      const db = mongoose.connection.db;
      
      // Add indexes for performance
      await db.collection('users').createIndex({ email: 1 }, { unique: true });
      await db.collection('users').createIndex({ phone: 1 });
      await db.collection('users').createIndex({ createdAt: -1 });
      
      await db.collection('referrals').createIndex({ referralCode: 1 }, { unique: true });
      await db.collection('referrals').createIndex({ referrerId: 1 });
      await db.collection('referrals').createIndex({ referredEmail: 1 });
      await db.collection('referrals').createIndex({ confirmed: 1, isFlagged: 1 });
      
      await db.collection('loans').createIndex({ userId: 1 });
      await db.collection('loans').createIndex({ status: 1 });
      await db.collection('loans').createIndex({ createdAt: -1 });
      
      await db.collection('tickets').createIndex({ userId: 1 });
      await db.collection('tickets').createIndex({ status: 1 });
      await db.collection('tickets').createIndex({ priority: 1 });
      
      await db.collection('auditlogs').createIndex({ createdAt: -1 });
      await db.collection('auditlogs').createIndex({ action: 1 });
      
      logger.info('Indexes created successfully');
    }
  },
  {
    name: '003_add_token_blacklist',
    description: 'Create token blacklist collection for logout tracking',
    timestamp: new Date('2026-02-01'),
    up: async () => {
      const db = mongoose.connection.db;
      await db.collection('tokenblacklists').createIndex({ token: 1 }, { unique: true });
      await db.collection('tokenblacklists').createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });
      logger.info('Token blacklist collection created');
    }
  }
];

// Migration history collection
const MIGRATION_COLLECTION = 'migrations';

/**
 * Get migration history from database
 */
const getMigrationHistory = async () => {
  const db = mongoose.connection.db;
  try {
    const collection = db.collection(MIGRATION_COLLECTION);
    const history = await collection.find({}).toArray();
    return new Set(history.map(m => m.name));
  } catch (error) {
    // Collection might not exist yet
    return new Set();
  }
};

/**
 * Record a migration as completed
 */
const recordMigration = async (migration) => {
  const db = mongoose.connection.db;
  const collection = db.collection(MIGRATION_COLLECTION);
  await collection.insertOne({
    name: migration.name,
    description: migration.description,
    executedAt: new Date(),
    timestamp: migration.timestamp
  });
};

/**
 * Run all pending migrations
 */
const runMigrations = async () => {
  logger.info('Starting database migrations...');
  
  try {
    await mongoose.connect(MONGODB_URI, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000
    });
    logger.info('Connected to MongoDB');
    
    const appliedMigrations = await getMigrationHistory();
    const pendingMigrations = migrations.filter(m => !appliedMigrations.has(m.name));
    
    logger.info(`Found ${appliedMigrations.size} applied migrations`);
    logger.info(`Found ${pendingMigrations.length} pending migrations`);
    
    for (const migration of pendingMigrations) {
      logger.info(`Running migration: ${migration.name} - ${migration.description}`);
      
      try {
        await migration.up();
        await recordMigration(migration);
        logger.info(`✓ Migration ${migration.name} completed successfully`);
      } catch (error) {
        logger.error(`✗ Migration ${migration.name} failed:`, error);
        throw error;
      }
    }
    
    logger.info('All migrations completed successfully!');
    
  } catch (error) {
    logger.error('Migration failed:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    logger.info('Disconnected from MongoDB');
  }
};

/**
 * Check migration status
 */
const checkStatus = async () => {
  logger.info('Checking migration status...');
  
  try {
    await mongoose.connect(MONGODB_URI, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000
    });
    
    const appliedMigrations = await getMigrationHistory();
    
    logger.info('\n=== Migration Status ===\n');
    
    for (const migration of migrations) {
      const applied = appliedMigrations.has(migration.name);
      const status = applied ? '✓ APPLIED' : '✗ PENDING';
      const date = migration.timestamp.toISOString().split('T')[0];
      console.log(`[${status}] ${migration.name} (${date}) - ${migration.description}`);
    }
    
    console.log(`\nTotal: ${migrations.length} migrations, ${appliedMigrations.size} applied`);
    
  } catch (error) {
    logger.error('Failed to check migration status:', error);
  } finally {
    await mongoose.disconnect();
  }
};

/**
 * Seed admin user(s)
 */
const seedAdmin = async () => {
  logger.info('Seeding admin users...');
  
  try {
    await mongoose.connect(MONGODB_URI, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000
    });
    
    const { User } = require('../models');
    
    const adminUsers = [
      {
        email: 'admin@coopvestafrica.org',
        name: 'System Administrator',
        phone: '+2348000000001',
        role: 'superadmin',
        kycStatus: 'approved',
        employmentStatus: 'employed',
        salaryRange: '500000+',
        createdAt: new Date()
      }
    ];
    
    for (const adminData of adminUsers) {
      const existingUser = await User.findOne({ email: adminData.email });
      
      if (existingUser) {
        // Update existing admin
        const hashedPassword = await bcrypt.hash(process.env.ADMIN_DEFAULT_PASSWORD || 'Admin@123', 12);
        await User.updateOne(
          { email: adminData.email },
          { 
            ...adminData,
            password: hashedPassword,
            updatedAt: new Date()
          }
        );
        logger.info(`Updated admin user: ${adminData.email}`);
      } else {
        // Create new admin
        const hashedPassword = await bcrypt.hash(process.env.ADMIN_DEFAULT_PASSWORD || 'Admin@123', 12);
        const admin = new User({
          ...adminData,
          userId: `admin_${Date.now()}`,
          password: hashedPassword
        });
        await admin.save();
        logger.info(`Created admin user: ${adminData.email}`);
      }
    }
    
    logger.info('Admin seeding completed!');
    logger.info('Default password: ' + (process.env.ADMIN_DEFAULT_PASSWORD || 'Admin@123'));
    
  } catch (error) {
    logger.error('Admin seeding failed:', error);
    throw error;
  } finally {
    await mongoose.disconnect();
  }
};

// CLI interface
const command = process.argv[2];

if (command === 'status') {
  checkStatus().then(() => process.exit(0));
} else if (command === 'seed-admin') {
  seedAdmin().then(() => process.exit(0));
} else if (command === 'migrate') {
  runMigrations().then(() => process.exit(0));
} else {
  console.log(`
Coopvest Africa - Database Migration Tool

Usage:
  node migrate.js migrate        Run all pending migrations
  node migrate.js status         Check migration status
  node migrate.js seed-admin     Seed admin users

Environment:
  MONGODB_URI       MongoDB connection string (default: mongodb://localhost:27017/coopvest)
  ADMIN_DEFAULT_PASSWORD  Default password for admin users (default: Admin@123)
`);
  process.exit(command ? 1 : 0);
}

module.exports = {
  runMigrations,
  checkStatus,
  seedAdmin,
  migrations
};
