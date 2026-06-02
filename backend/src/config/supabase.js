/**
 * Supabase Client Configuration
 */

const { createClient } = require('@supabase/supabase-js');
const logger = require('../utils/logger');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  logger.error('FATAL: Supabase URL or SERVICE_ROLE_KEY is missing in environment variables!');
  // Allow server to start in development without crashing, but fail in production
  if (process.env.NODE_ENV === 'production') {
    process.exit(1);
  }
}

const supabase = createClient(supabaseUrl || 'http://localhost:54321', supabaseKey || 'placeholder');

logger.info('✅ Supabase client initialized');

module.exports = supabase;
