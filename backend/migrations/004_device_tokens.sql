-- Migration: device_tokens
-- Stores FCM device registration tokens for each user profile.
-- Used by notifyService.js to deliver targeted push notifications.

CREATE TABLE IF NOT EXISTS device_tokens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token         text NOT NULL UNIQUE,
  active        boolean NOT NULL DEFAULT true,
  platform      text,               -- 'android' | 'ios' | null
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Index for fast look-ups by profile (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_device_tokens_profile_active
  ON device_tokens (profile_id, active);

-- Automatically keep updated_at current
CREATE OR REPLACE FUNCTION update_device_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_device_tokens_updated_at ON device_tokens;
CREATE TRIGGER trg_device_tokens_updated_at
  BEFORE UPDATE ON device_tokens
  FOR EACH ROW EXECUTE FUNCTION update_device_tokens_updated_at();

-- Row-Level Security: users can only read/modify their own tokens.
-- The service-role key (used by the backend) bypasses RLS automatically.
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS device_tokens_self ON device_tokens;
CREATE POLICY device_tokens_self ON device_tokens
  USING (profile_id = auth.uid());
