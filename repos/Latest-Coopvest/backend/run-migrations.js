/**
 * Coopvest Africa - Supabase Schema Migration Runner
 *
 * Connects directly to Supabase PostgreSQL and runs supabase_schema.sql
 * Usage: node run-migrations.js
 */

require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const supabaseUrl = process.env.SUPABASE_URL;
const dbPassword = process.env.SUPABASE_DB_PASSWORD;

if (!supabaseUrl || !dbPassword) {
  console.error('❌  Missing SUPABASE_URL or SUPABASE_DB_PASSWORD');
  process.exit(1);
}

// Derive pg host from SUPABASE_URL: https://xyz.supabase.co -> db.xyz.supabase.co
const projectRef = supabaseUrl.replace('https://', '').replace('.supabase.co', '').split('.')[0];
const host = `db.${projectRef}.supabase.co`;

const client = new Client({
  host,
  port: 5432,
  user: 'postgres',
  password: dbPassword,
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

async function run() {
  console.log(`\n🔌 Connecting to Supabase PostgreSQL at ${host}...\n`);

  await client.connect();
  console.log('✅ Connected\n');

  const sqlPath = path.join(__dirname, 'supabase_schema.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  console.log('📄 Running schema migrations from supabase_schema.sql...\n');

  // Execute the entire file as one transaction
  await client.query('BEGIN');
  try {
    await client.query(sql);
    await client.query('COMMIT');
    console.log('✅ All migrations applied successfully!\n');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed — rolled back.');
    console.error(err.message);
    process.exit(1);
  } finally {
    await client.end();
  }

  console.log('🎉 Done! Your Supabase database is ready.\n');
  console.log('Tables created:');
  console.log('  profiles, kyc, kyc_documents, savings, savings_goals');
  console.log('  referrals, referral_events, wallets, transactions');
  console.log('  bank_accounts, loans, loan_qrs, loan_guarantors, rollovers');
  console.log('  investment_pools, investment_participations, notifications');
  console.log('  tickets, ticket_messages, ticket_attachments, ticket_status_history');
  console.log('  audit_logs, user_settings, system_settings, watchlist');
  console.log('  loan_repayments, scheduled_notifications, backup_snapshots');
  console.log('\nRLS policies, triggers, and functions are also configured.\n');
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
