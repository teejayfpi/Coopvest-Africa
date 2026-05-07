const app = require('./app');
const supabase = require('./supabase');

const PORT = process.env.PORT || 8080;

async function checkDbTables() {
  const tables = ['users', 'otp_codes', 'refresh_tokens', 'kyc_submissions'];
  const missing = [];
  for (const table of tables) {
    const { error } = await supabase.from(table).select('id').limit(1);
    // PGRST205 = table not in schema cache (does not exist)
    if (error && (error.code === '42P01' || error.code === 'PGRST205')) {
      missing.push(table);
    }
  }
  return missing;
}

app.listen(PORT, '0.0.0.0', async () => {
  console.log(`Coopvest API server running on port ${PORT}`);
  console.log(`Health:  GET  /api/v1/healthz`);
  console.log(`Auth:    POST /api/v1/auth/{register,login,verify-email,...}`);

  const missing = await checkDbTables();
  if (missing.length > 0) {
    console.warn('');
    console.warn('⚠️  SETUP REQUIRED — missing Supabase tables:', missing.join(', '));
    console.warn('   Run supabase_schema.sql in the Supabase SQL Editor:');
    console.warn('   https://app.supabase.com/project/nyoauzqezpxeonmrxxgi/sql/new');
    console.warn('');
  } else {
    console.log('✓  Supabase tables verified — ready');
  }
});
