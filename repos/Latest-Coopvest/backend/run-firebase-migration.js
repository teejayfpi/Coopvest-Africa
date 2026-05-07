/**
 * Firebase Auth Migration Runner
 *
 * Runs the SQL migration to prepare the Supabase database for Firebase Auth:
 *   1. Adds firebase_uid column to profiles
 *   2. Drops the FK constraint from profiles.id → auth.users
 *      (Firebase users are not in auth.users, so this constraint blocks inserts)
 *   3. Adds gen_random_uuid() default so profiles can be created without a Supabase Auth UID
 *   4. Creates indexes for fast firebase_uid lookups
 *
 * USAGE:
 *   1. Get your Supabase database connection string from:
 *      Supabase Dashboard → Project Settings → Database → Connection string (URI)
 *      It looks like: postgresql://postgres:[YOUR-PASSWORD]@db.xxx.supabase.co:5432/postgres
 *
 *   2. Set the DATABASE_URL env var:
 *      DATABASE_URL="postgresql://postgres:yourpassword@db.nyoauzqezpxeonmrxxgi.supabase.co:5432/postgres" \
 *      node run-firebase-migration.js
 *
 *      OR add it to your .env file and just run:
 *      node run-firebase-migration.js
 */

require('dotenv').config();
const { Client } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.error('\n❌ DATABASE_URL is not set.\n');
  console.error('Get it from: Supabase Dashboard → Project Settings → Database → URI\n');
  console.error('Then run:');
  console.error('  DATABASE_URL="postgresql://postgres:PASSWORD@db.nyoauzqezpxeonmrxxgi.supabase.co:5432/postgres" node run-firebase-migration.js\n');
  process.exit(1);
}

const MIGRATION_SQL = [
  {
    description: 'Add firebase_uid column to profiles',
    sql: `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS firebase_uid TEXT;`
  },
  {
    description: 'Create unique index on firebase_uid (non-null only)',
    sql: `
      CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_firebase_uid
        ON public.profiles (firebase_uid)
        WHERE firebase_uid IS NOT NULL;
    `
  },
  {
    description: 'Create lookup index on firebase_uid',
    sql: `
      CREATE INDEX IF NOT EXISTS idx_profiles_firebase_uid_lookup
        ON public.profiles (firebase_uid);
    `
  },
  {
    description: 'Drop FK constraint profiles.id → auth.users (blocks Firebase-only user inserts)',
    sql: `ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;`
  },
  {
    description: 'Add gen_random_uuid() default to profiles.id so new rows get a UUID automatically',
    sql: `ALTER TABLE public.profiles ALTER COLUMN id SET DEFAULT gen_random_uuid();`
  },
  {
    description: 'Add firebase_uid lookup index on profiles (idempotent)',
    sql: `
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE tablename = 'profiles' AND indexname = 'idx_profiles_firebase_uid_lookup'
        ) THEN
          CREATE INDEX idx_profiles_firebase_uid_lookup ON public.profiles (firebase_uid);
        END IF;
      END$$;
    `
  },
];

async function run() {
  const client = new Client({ connectionString: DATABASE_URL, ssl: { rejectUnauthorized: false } });

  try {
    await client.connect();
    console.log('✅ Connected to Supabase PostgreSQL\n');

    for (const step of MIGRATION_SQL) {
      process.stdout.write(`⏳ ${step.description}...`);
      try {
        await client.query(step.sql);
        console.log(' ✅');
      } catch (err) {
        if (err.message.includes('already exists') || err.message.includes('does not exist')) {
          console.log(` ⚠️  Skipped (${err.message.split('\n')[0]})`);
        } else {
          console.log(` ❌\n   ${err.message}`);
        }
      }
    }

    console.log('\n🎉 Migration complete! Your Supabase database is ready for Firebase Auth.\n');
  } catch (err) {
    console.error('\n❌ Connection failed:', err.message);
    console.error('\nMake sure DATABASE_URL is correct. Format:');
    console.error('  postgresql://postgres:PASSWORD@db.nyoauzqezpxeonmrxxgi.supabase.co:5432/postgres\n');
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
