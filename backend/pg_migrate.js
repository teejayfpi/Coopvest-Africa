const { Client } = require('pg');

// Supabase connection using service role key as password
const client = new Client({
  connectionString: 'postgresql://postgres.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55b2F1enFlenB4ZW9ubXJ4eGdpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDI4MjczNSwiZXhwIjoyMDg5ODU4NzM1fQ.zCX5ZMW42kwjszRmT6HREZOCjTs5z7ZlXidK4BM-coM@aws-0-us-east-1-975937489815.pooler.supabase.com:6543/postgres',
  ssl: { rejectUnauthorized: false }
});

const createTableSQL = `
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

CREATE INDEX IF NOT EXISTS idx_deposit_requests_profile ON public.deposit_requests(profile_id);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_status ON public.deposit_requests(status);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_created ON public.deposit_requests(created_at DESC);

ALTER TABLE public.deposit_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS deposit_requests_self_select ON public.deposit_requests;
DROP POLICY IF EXISTS deposit_requests_self_modify ON public.deposit_requests;
CREATE POLICY deposit_requests_self_select ON public.deposit_requests FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
CREATE POLICY deposit_requests_self_modify ON public.deposit_requests FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- Fix is_staff() function to include 'super_admin' role
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

DROP TRIGGER IF EXISTS set_updated_at ON public.deposit_requests;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.deposit_requests FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
`;

async function migrate() {
  console.log('🔄 Attempting to connect to Supabase database...\n');
  
  try {
    await client.connect();
    console.log('✅ Connected to Supabase!');
    
    // Check if table exists
    const check = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'deposit_requests'
      ) as exists
    `);
    
    if (check.rows[0].exists) {
      console.log('ℹ️  Table deposit_requests already exists');
    } else {
      console.log('📦 Creating deposit_requests table...');
      await client.query(createTableSQL);
      console.log('✅ Table created successfully!');
    }
    
    await client.end();
    console.log('\n✨ Migration complete!');
    
  } catch (e) {
    console.log('❌ Error:', e.message);
    process.exit(1);
  }
}

migrate();
