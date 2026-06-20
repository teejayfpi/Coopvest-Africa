/**
 * Migration Script: Create deposit_requests table
 * Run: node apply-migration.js
 */
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runMigration() {
  console.log('Starting migration: Create deposit_requests table...\n');

  // Check if table exists
  const { data: tableCheck, error: checkError } = await supabase
    .from('information_schema.tables')
    .select('table_name')
    .eq('table_schema', 'public')
    .eq('table_name', 'deposit_requests')
    .single();

  if (tableCheck) {
    console.log('✓ Table deposit_requests already exists');
  } else {
    console.log('✗ Table deposit_requests does not exist');
    console.log('\nTo create the table, you need to:');
    console.log('1. Go to your Supabase Dashboard: https://supabase.com/dashboard');
    console.log('2. Navigate to your project: nyoauzqezpxeonmrxxgi');
    console.log('3. Go to SQL Editor');
    console.log('4. Run the SQL from backend/supabase_schema.sql (lines 220-251)');
  }

  // Check existing tables
  console.log('\nExisting tables in public schema:');
  const { data: tables, error } = await supabase
    .from('information_schema.tables')
    .select('table_name')
    .eq('table_schema', 'public');
  
  if (error) {
    console.error('Error fetching tables:', error.message);
  } else {
    tables.forEach(t => console.log('  - ' + t.table_name));
  }

  console.log('\nMigration check complete!');
}

runMigration();
