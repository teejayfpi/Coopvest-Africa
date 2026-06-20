const { Client } = require('pg');

// User's Supabase connection string
const client = new Client({
  connectionString: 'postgresql://postgres:Temiloluwa@1963@db.nyoauzqezpxeonmrxxgi.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const statements = [
  // Step 1: Create table
  `CREATE TABLE IF NOT EXISTS public.deposit_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
    amount DECIMAL(18, 2) NOT NULL,
    currency TEXT DEFAULT 'NGN',
    status TEXT DEFAULT 'pending',
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
  )`,

  // Step 2: Create indexes
  `CREATE INDEX idx_deposit_requests_profile ON public.deposit_requests(profile_id)`,
  `CREATE INDEX idx_deposit_requests_status ON public.deposit_requests(status)`,
  `CREATE INDEX idx_deposit_requests_created ON public.deposit_requests(created_at DESC)`,

  // Step 3: Enable RLS
  `ALTER TABLE public.deposit_requests ENABLE ROW LEVEL SECURITY`,

  // Step 4: Create policies
  `CREATE POLICY deposit_requests_self_select ON public.deposit_requests FOR SELECT USING (profile_id = auth.uid() OR public.is_staff())`,
  `CREATE POLICY deposit_requests_self_modify ON public.deposit_requests FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff())`
];

async function migrate() {
  console.log('🔄 Running database migration...\n');
  
  try {
    await client.connect();
    console.log('✅ Connected to Supabase!');
    
    for (let i = 0; i < statements.length; i++) {
      const sql = statements[i];
      const step = i + 1;
      
      try {
        await client.query(sql);
        console.log(`✅ Step ${step}: Success`);
      } catch (err) {
        // Ignore "already exists" errors
        if (err.code === '42P07' || err.code === '42710' || err.message.includes('already exists')) {
          console.log(`ℹ️  Step ${step}: Already exists (skipped)`);
        } else {
          console.log(`❌ Step ${step} Error: ${err.message}`);
        }
      }
    }
    
    console.log('\n✨ Migration complete!');
    
  } catch (e) {
    console.log('❌ Connection Error:', e.message);
  } finally {
    await client.end();
  }
}

migrate();
