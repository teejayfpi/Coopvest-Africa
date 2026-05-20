-- Migration 005: Add onboarding columns to kyc table
-- Required by POST /api/v1/auth/complete-registration endpoint
-- which stores personal and employment data collected during registration onboarding.

ALTER TABLE public.kyc
  ADD COLUMN IF NOT EXISTS personal_info jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS employment_info jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Unique constraint on profile_id is required for Supabase upsert
-- (onConflict: 'profile_id') used by the complete-registration endpoint.
ALTER TABLE public.kyc
  ADD CONSTRAINT kyc_profile_id_unique UNIQUE (profile_id);
