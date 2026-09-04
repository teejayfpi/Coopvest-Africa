-- Migration 026: align live schema with what the backend code writes.
--
-- The live database drifted from the migrations: several columns the code
-- writes were never created, which surfaced as PostgREST PGRST204 errors
-- ("Could not find the 'X' column of 'Y' in the schema cache") on the admin
-- KYC verification action and on Paystack deposits.

ALTER TABLE public.kyc
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verification_notes TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_verified_at TIMESTAMPTZ;

ALTER TABLE public.payment_proofs
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Referenced by kycAdmin.logMemberActivity; insert failures were previously
-- swallowed with a warn log, so the table was simply never noticed missing.
CREATE TABLE IF NOT EXISTS public.member_activity_timeline (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  description TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  actor_id UUID,
  actor_type TEXT,
  ip_address TEXT,
  device_info TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_member_activity_timeline_profile
  ON public.member_activity_timeline(profile_id, created_at DESC);
