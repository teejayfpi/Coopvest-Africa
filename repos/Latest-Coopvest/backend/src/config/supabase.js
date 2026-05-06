/**
 * Supabase Client Configuration
 */

const { createClient } = require('@supabase/supabase-js');
const logger = require('../utils/logger');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  logger.error('FATAL: Supabase URL or Key is missing in environment variables!');
}

const supabase = createClient(supabaseUrl, supabaseKey);

logger.info('✅ Supabase client initialized');

module.exports = supabase;
