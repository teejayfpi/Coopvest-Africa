/**
 * Direct Database Migration Script
 * 
 * This script uses Supabase's REST API to create the deposit_requests table.
 * Note: Supabase's REST API doesn't allow raw SQL execution for security reasons.
 * 
 * To run this migration, you need to:
 * 1. Get your Supabase connection string from the dashboard:
 *    - Go to: https://supabase.com/dashboard/project/nyoauzqezpxeonmrxxgi/settings/database
 *    - Copy the "Connection string" (URI format)
 * 
 * 2. Set the DATABASE_URL environment variable:
 *    export DATABASE_URL="postgresql://postgres.[password]@aws-0-[region].pooler.supabase.com:6543/postgres"
 * 
 * 3. Run: node run-migration.js
 */

const { Client } = require('pg');

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.log('❌ DATABASE_URL not set');
  console.log('\nTo run this migration:');
  console.log('1. Go to: https://supabase.com/dashboard/project/nyoauzqezpxeonmrxxgi/settings/database');
  console.log('2. Copy the "Connection string" URI');
  console.log('3. Run: export DATABASE_URL="your-connection-string" && node run-migration.js');
  process.exit(1);
}

const sql = `
-- Create deposit_requests table
CREATE TABLE IF NOT EXISTS public.deposit_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  amount DECIMAL(18, 2) NOT NULL,
  currency TEXT DEFAULT 'NGN',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','verified','rejected','cancelled')),
  payment_proof_url TEXT,
  payment_reference TEXT,
  payment_date TIMESTAMPTZ,
  bank_name TEXT,
  sender_account_name TEXT,
  sender_account_number TEXT,
  admin_notes TEXT,
  verified_by UUID REFERENCES public.profiles(id),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_deposit_requests_profile ON public.deposit_requests(profile_id);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_status ON public.deposit_requests(status);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_created ON public.deposit_requests(created_at DESC);

-- Enable RLS
ALTER TABLE public.deposit_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS deposit_requests_self_select ON public.deposit_requests;
DROP POLICY IF EXISTS deposit_requests_self_modify ON public.deposit_requests;
CREATE POLICY deposit_requests_self_select ON public.deposit_requests FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
CREATE POLICY deposit_requests_self_modify ON public.deposit_requests FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- Add is_staff() helper function (fixed: Added 'super_admin' role with underscore)
DROP FUNCTION IF EXISTS public.is_staff();
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin','super_admin','superadmin','staff','operator','viewer')
  )
$$;

-- Add auto-update trigger
DROP TRIGGER IF EXISTS set_updated_at ON public.deposit_requests;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.deposit_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
`;

async function runMigration() {
  console.log('🔄 Running migration...\n');
  
  const client = new Client({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('✅ Connected to Supabase database');
    
    await client.query(sql);
    console.log('✅ Migration completed successfully!');
    console.log('\n📋 Created: deposit_requests table with indexes and RLS policies');
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

runMigration();
