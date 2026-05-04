/**
 * Creates the admin user directly in auth.users via SQL (Management API).
 * Used when the Supabase auth admin endpoint fails.
 */

require('dotenv').config();
const bcrypt = require('bcryptjs');

const projectRef = process.env.SUPABASE_URL.replace('https://', '').replace('.supabase.co', '');
const token = process.env.SUPABASE_ACCESS_TOKEN;

async function runSQL(query) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query }),
  });
  const data = await res.json();
  if (data.message) throw new Error(data.message);
  return data;
}

async function main() {
  const email = 'admin@coopvestafrica.org';
  const password = 'CoopVest@Admin2024!';
  const userId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  console.log('\n👤 Creating admin user...\n');

  // Check if already exists
  const existing = await runSQL(
    `SELECT id FROM auth.users WHERE email = '${email}' LIMIT 1`
  );
  if (existing.length > 0) {
    console.log('ℹ️  Admin user already exists (ID:', existing[0].id + ')');
    // Ensure profile is superadmin
    await runSQL(`UPDATE public.profiles SET role = 'superadmin', kyc_verified = true WHERE id = '${existing[0].id}'`);
    console.log('✅ Profile updated to superadmin');
    return;
  }

  // Generate bcrypt hash
  const hash = bcrypt.hashSync(password, 10);

  // Insert directly into auth.users
  const insertSQL = `
    INSERT INTO auth.users (
      id, instance_id, aud, role, email,
      encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token,
      email_change_token_new, email_change,
      is_sso_user, deleted_at
    ) VALUES (
      '${userId}',
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      '${email}',
      '${hash}',
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"name":"System Administrator","role":"superadmin","userId":"USR-ADMIN-001","phone":""}',
      now(), now(),
      '', '', '', '',
      false, null
    )
    ON CONFLICT (id) DO NOTHING;
  `;

  await runSQL(insertSQL);
  console.log('✅ Auth user inserted');

  // Insert profile
  await runSQL(`
    INSERT INTO public.profiles (id, user_id, email, name, phone, role, kyc_verified)
    VALUES (
      '${userId}',
      'USR-ADMIN-001',
      '${email}',
      'System Administrator',
      '',
      'superadmin',
      true
    )
    ON CONFLICT (id) DO UPDATE SET role = 'superadmin', kyc_verified = true;
  `);
  console.log('✅ Profile created (superadmin)');

  // Insert wallet, savings, settings
  await runSQL(`INSERT INTO public.wallets (profile_id) VALUES ('${userId}') ON CONFLICT (profile_id) DO NOTHING;`);
  await runSQL(`INSERT INTO public.savings (profile_id) VALUES ('${userId}') ON CONFLICT (profile_id) DO NOTHING;`);
  await runSQL(`INSERT INTO public.user_settings (profile_id) VALUES ('${userId}') ON CONFLICT (profile_id) DO NOTHING;`);
  console.log('✅ Wallet, savings, and settings created');

  console.log('\n🎉 Admin user ready!\n');
  console.log('──────────────────────────────────────────');
  console.log('  Email:    admin@coopvestafrica.org');
  console.log('  Password: CoopVest@Admin2024!');
  console.log('  Role:     superadmin');
  console.log('──────────────────────────────────────────\n');
}

main().catch(err => {
  console.error('\n❌ Error:', err.message);
  process.exit(1);
});
