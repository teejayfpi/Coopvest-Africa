-- Migration 005: Add onboarding columns to kyc table and align schema
-- Required by POST /api/v1/auth/complete-registration endpoint
-- which stores personal and employment data collected during registration onboarding.

-- KYC onboarding columns
ALTER TABLE public.kyc
  ADD COLUMN IF NOT EXISTS personal_info jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS employment_info jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS verification_level INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS contact_info jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS bank_info jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS selfie jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz;

-- Unique constraint on profile_id is required for Supabase upsert
-- (onConflict: 'profile_id') used by the complete-registration endpoint.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'kyc_profile_id_unique'
  ) THEN
    ALTER TABLE public.kyc ADD CONSTRAINT kyc_profile_id_unique UNIQUE (profile_id);
  END IF;
END $$;

-- Savings table: add updated_at if missing
ALTER TABLE public.savings
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
