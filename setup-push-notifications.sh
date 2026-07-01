#!/bin/bash
# Coopvest Push Notifications Setup Script
# Run this on your local machine with Supabase CLI installed

set -e

echo "🚀 Coopvest Push Notifications Setup"
echo "===================================="
echo ""

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install it first:"
    echo "   npm install -g supabase"
    echo ""
    echo "   Or on macOS:"
    echo "   brew install supabase/tap/supabase"
    exit 1
fi

echo "✅ Supabase CLI found"
echo ""

# Get Supabase Project Ref from user
read -p "Enter your Supabase Project Reference (found in Settings > API): " PROJECT_REF

if [ -z "$PROJECT_REF" ]; then
    echo "❌ Project reference is required"
    exit 1
fi

# Get FCM Server Key from user
echo ""
echo "To get your FCM Server Key:"
echo "1. Go to https://console.firebase.google.com/"
echo "2. Select your Firebase project"
echo "3. Go to Project Settings > Cloud Messaging"
echo "4. Copy the Server Key"
echo ""
read -p "Enter your FCM Server Key: " FCM_SERVER_KEY

if [ -z "$FCM_SERVER_KEY" ]; then
    echo "❌ FCM Server Key is required"
    exit 1
fi

echo ""
echo "📦 Deploying Edge Functions..."
echo ""

# Link to project
supabase link --project-ref $PROJECT_REF

# Deploy functions
supabase functions deploy process-contribution-reminders
supabase functions deploy send-contribution-reminder

echo ""
echo "🔐 Setting environment variables..."

# Set FCM Server Key as secret
supabase secrets set FCM_SERVER_KEY="$FCM_SERVER_KEY"

echo ""
echo "📊 Setting up database schema..."
echo ""

# Create required tables
supabase db execute << 'EOF'
-- User settings table for contribution preferences
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT,
  contribution_method TEXT DEFAULT 'manual',
  preferred_day INTEGER DEFAULT 5,
  monthly_amount NUMERIC DEFAULT 5000,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Policy for users to update own settings
DROP POLICY IF EXISTS "Users can update own settings" ON user_settings;
CREATE POLICY "Users can update own settings" ON user_settings
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy for users to insert own settings
DROP POLICY IF EXISTS "Users can insert own settings" ON user_settings;
CREATE POLICY "Users can insert own settings" ON user_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy for service role to read all (for edge functions)
DROP POLICY IF EXISTS "Service role can read all" ON user_settings;
CREATE POLICY "Service role can read all" ON user_settings
  FOR SELECT USING (true);

-- FCM tokens table
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  device_info TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, token)
);

-- Enable RLS
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy for users to manage own tokens
DROP POLICY IF EXISTS "Users can manage own tokens" ON fcm_tokens;
CREATE POLICY "Users can manage own tokens" ON fcm_tokens
  FOR ALL USING (auth.uid() = user_id);

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create cron job for daily reminders (runs at 9 AM)
SELECT cron.schedule(
  'daily-contribution-reminder',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url => 'https://$PROJECT_REF.supabase.co/functions/v1/process-contribution-reminders',
    headers => '{"Content-Type": "application/json"}'
  );
  $$
);
EOF

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📋 Summary:"
echo "   - Edge Functions deployed ✓"
echo "   - FCM Server Key configured ✓"
echo "   - Database tables created ✓"
echo "   - Cron job scheduled for 9 AM daily ✓"
echo ""
echo "📱 Users will now receive push notifications for:"
echo "   - Contribution reminders (3 days before)"
echo "   - Due today notifications"
echo "   - Overdue reminders"
echo ""
