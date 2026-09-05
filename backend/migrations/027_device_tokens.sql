-- Migration 027: device_tokens table — FCM push delivery
-- The app registers its FCM token at login; notifyService.pushToProfile reads
-- this table to know which devices to send each push to. It never existed in
-- the live DB, so token registration silently no-op'd and push delivery was
-- impossible even with Firebase credentials configured.

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  device_name TEXT,
  platform TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_profile
  ON public.device_tokens(profile_id);