/**
 * Coopvest Africa — Seed Script
 * Seeds: feature flags, system settings, investment pools, and an admin user.
 * Usage: node seed-data.js
 */

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const projectRef = process.env.SUPABASE_URL.replace('https://', '').replace('.supabase.co', '');
const token = process.env.SUPABASE_ACCESS_TOKEN;

async function runSQL(query) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const data = await res.json();
  if (data.message) throw new Error(data.message);
  return data;
}

async function seed() {
  console.log('\n🌱 Seeding Coopvest Africa database...\n');

  // ─── 1. Feature flags ──────────────────────────────────────────────────────
  console.log('1️⃣  Seeding feature flags...');
  const flags = [
    'loanModule', 'savingsModule', 'investmentModule', 'referralSystem',
    'walletTransfers', 'withdrawalRequests', 'memberRegistration',
    'statementDownloads', 'notifications', 'qrReferralSystem',
  ];
  for (const flag of flags) {
    const { error } = await supabase.from('system_settings').upsert({
      key: `feature_flag.${flag}`,
      value: true,
      description: `Feature flag: ${flag}`,
    }, { onConflict: 'key' });
    if (error) console.warn(`  ⚠️  Flag ${flag}:`, error.message);
    else console.log(`  ✅ feature_flag.${flag} = true`);
  }

  // ─── 2. System settings ────────────────────────────────────────────────────
  console.log('\n2️⃣  Seeding system settings...');
  const systemSettings = [
    {
      key: 'maintenance.enabled',
      value: { enabled: false, message: '' },
      description: 'Maintenance mode toggle',
    },
    {
      key: 'app.min_version',
      value: { ios: '1.0.0', android: '1.0.0', web: '1.0.0' },
      description: 'Minimum supported app version',
    },
    {
      key: 'referral.settings',
      value: {
        lockInDays: 30,
        minSavingsMonths: 3,
        minSavingsAmount: 5000,
        interestFloors: { quick: 5.0, flexi: 6.0, emergency: 7.0, business: 8.0 },
      },
      description: 'Referral system configuration',
    },
  ];
  for (const s of systemSettings) {
    const { error } = await supabase.from('system_settings').upsert(s, { onConflict: 'key' });
    if (error) console.warn(`  ⚠️  ${s.key}:`, error.message);
    else console.log(`  ✅ ${s.key}`);
  }

  // ─── 3. Investment pools ───────────────────────────────────────────────────
  console.log('\n3️⃣  Seeding investment pools...');
  const pools = [
    {
      pool_id: 'POOL-001',
      name: 'Cooperative Growth Fund',
      description: 'A diversified fund supporting cooperative member businesses across Nigeria.',
      category: 'cooperative',
      target_amount: 5000000,
      raised_amount: 2350000,
      expected_return_percent: 14.5,
      duration_months: 12,
      risk_level: 'low',
      status: 'open',
      opens_at: new Date().toISOString(),
      closes_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
    },
    {
      pool_id: 'POOL-002',
      name: 'SME Accelerator Fund',
      description: 'Financing small and medium enterprises in agriculture and manufacturing.',
      category: 'sme',
      target_amount: 10000000,
      raised_amount: 6800000,
      expected_return_percent: 18.0,
      duration_months: 18,
      risk_level: 'medium',
      status: 'open',
      opens_at: new Date().toISOString(),
      closes_at: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString(),
    },
    {
      pool_id: 'POOL-003',
      name: 'Real Estate Income Fund',
      description: 'Collective investment in residential real estate projects in Lagos and Abuja.',
      category: 'real_estate',
      target_amount: 20000000,
      raised_amount: 20000000,
      expected_return_percent: 22.0,
      duration_months: 24,
      risk_level: 'medium',
      status: 'funded',
      opens_at: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
      closes_at: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
    },
    {
      pool_id: 'POOL-004',
      name: 'Agro-Finance Fund',
      description: 'Supporting agricultural value chains: crop financing, processing, and export.',
      category: 'agriculture',
      target_amount: 8000000,
      raised_amount: 1200000,
      expected_return_percent: 16.0,
      duration_months: 9,
      risk_level: 'high',
      status: 'open',
      opens_at: new Date().toISOString(),
      closes_at: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString(),
    },
  ];
  for (const pool of pools) {
    const { error } = await supabase.from('investment_pools').upsert(pool, { onConflict: 'pool_id' });
    if (error) console.warn(`  ⚠️  ${pool.name}:`, error.message);
    else console.log(`  ✅ ${pool.name} (${pool.status})`);
  }

  // ─── 4. Admin user ─────────────────────────────────────────────────────────
  console.log('\n4️⃣  Creating admin user...');
  const adminEmail = 'admin@coopvestafrica.org';
  const adminPassword = 'CoopVest@Admin2024!';

  const { data: authData, error: authError } = await supabase.auth.admin.createUser({
    email: adminEmail,
    password: adminPassword,
    email_confirm: true,
    user_metadata: {
      name: 'System Administrator',
      role: 'superadmin',
      userId: 'USR-ADMIN-001',
    },
  });

  if (authError) {
    if (authError.message.includes('already been registered') || authError.message.includes('already exists')) {
      console.log('  ℹ️  Admin user already exists — skipping');
    } else {
      console.warn('  ⚠️  Admin user creation:', authError.message);
    }
  } else {
    // Update the profile to superadmin role (trigger creates it as 'member')
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ role: 'superadmin', kyc_verified: true })
      .eq('id', authData.user.id);
    if (profileError) console.warn('  ⚠️  Profile update:', profileError.message);
    else console.log(`  ✅ Admin user created: ${adminEmail}`);
  }

  console.log('\n🎉 Seed complete!\n');
  console.log('─────────────────────────────────────────');
  console.log('Admin login:');
  console.log('  Email:    admin@coopvestafrica.org');
  console.log('  Password: CoopVest@Admin2024!');
  console.log('─────────────────────────────────────────');
  console.log('Investment pools: 4 seeded');
  console.log('Feature flags:   10 enabled');
  console.log('System settings: 3 configured\n');
}

seed().catch((err) => {
  console.error('\n❌ Seed failed:', err.message);
  process.exit(1);
});
