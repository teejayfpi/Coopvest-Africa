# Supabase Edge Functions Setup

## Overview

These Edge Functions enable push notifications for contribution reminders, even when the app is closed.

## Functions

### 1. `process-contribution-reminders`
- **Purpose**: Cron job that runs daily to check and send push notifications
- **Trigger**: Scheduled daily at 9:00 AM (configure in Supabase Dashboard)
- **Logic**: 
  - Queries all users with manual contribution method
  - Checks if contribution is due/overdue
  - Sends FCM push notification

### 2. `send-contribution-reminder`
- **Purpose**: Send FCM push notifications on-demand
- **Trigger**: Called by the mobile app or other services
- **Input**: Array of reminder data (userId, fcmToken, title, body, type)

## Setup Instructions

### Step 1: Get Firebase Cloud Messaging Server Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** → **Cloud Messaging**
4. Copy the **Server key** (or migrate to FCM v1 API for better security)

### Step 2: Deploy Edge Functions

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy functions
supabase functions deploy process-contribution-reminders
supabase functions deploy send-contribution-reminder
```

### Step 3: Set Environment Variables

In Supabase Dashboard → Edge Functions → Secrets:

```
FCM_SERVER_KEY=your_firebase_server_key_here
```

### Step 4: Set Up Cron Job

In Supabase Dashboard:

1. Go to **Database** → **Extensions**
2. Enable `pg_cron` extension

3. Create a cron job to trigger the function daily:

```sql
SELECT cron.schedule(
  'contribution-reminder-cron',
  '0 9 * * *', -- Every day at 9 AM
  $$
  SELECT net.http_post(
    url => 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-contribution-reminders',
    headers => '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'
  );
  $$
);
```

### Step 5: Update Database Schema (if needed)

The Edge Function expects a `user_settings` table with these columns:

```sql
CREATE TABLE user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  fcm_token TEXT,
  contribution_method TEXT DEFAULT 'manual',
  preferred_day INTEGER DEFAULT 5,
  monthly_amount NUMERIC DEFAULT 5000,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Policy for users to update their own settings
CREATE POLICY "Users can update own settings" ON user_settings
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy for service role to read all
CREATE POLICY "Service role can read all" ON user_settings
  FOR SELECT USING (true);
```

### Step 6: Create FCM Token Storage Table

```sql
CREATE TABLE fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  device_info TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, token)
);

-- RLS
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own tokens" ON fcm_tokens
  FOR ALL USING (auth.uid() = user_id);
```

## Testing

### Test locally:
```bash
supabase functions serve process-contribution-reminders
```

### Test in production:
```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/process-contribution-reminders" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Notification Types

| Type | Trigger | Title |
|------|---------|-------|
| `contribution_reminder` | 3 days before due | "Contribution Reminder" |
| `contribution_due_today` | On due date | "Contribution Due Today" |
| `contribution_overdue` | After due date | "Contribution Overdue" |

## Troubleshooting

### Notifications not sending?
1. Check FCM_SERVER_KEY is set correctly
2. Verify user has valid FCM token
3. Check Supabase Edge Function logs
4. Ensure `net.http_post` extension is enabled
