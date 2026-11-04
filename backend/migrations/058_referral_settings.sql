-- Migration 058: referral_settings (single-row program configuration)
--
-- Why this exists
-- ---------------
-- `GET /api/admin/referrals` and `PUT /api/admin/referrals/settings` in
-- `src/routes/adminApi.js` already read and write `referral_settings`, but the
-- table was never created in `supabase_schema.sql` or any migration. The GET
-- returned nothing and the PUT failed, so the Admin Dashboard's Referral
-- Program page could not load or save its settings.
--
-- This table is the single source of truth for whether the program is enabled
-- and what notional cash value a confirmed referral is worth for reporting.
-- The member reward itself is a tiered interest discount (see REFERRAL.md);
-- `bonus_per_referral` does not credit any wallet.
--
-- Additive and idempotent. No data is modified or dropped.

CREATE TABLE IF NOT EXISTS public.referral_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enabled BOOLEAN NOT NULL DEFAULT true,
  bonus_per_referral DECIMAL(18, 2) NOT NULL DEFAULT 0,
  max_referrals_per_user INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed the single row the admin endpoints expect, without duplicating it on
-- re-run. The API treats an absent row as "enabled, no bonus" anyway.
INSERT INTO public.referral_settings (enabled, bonus_per_referral, max_referrals_per_user)
SELECT true, 0, 0
WHERE NOT EXISTS (SELECT 1 FROM public.referral_settings);

ALTER TABLE public.referral_settings ENABLE ROW LEVEL SECURITY;

-- Only the API (service role) reads or writes this. The anon key ships inside
-- the mobile app and dashboard JS, so no policy is granted to it.
DROP POLICY IF EXISTS referral_settings_no_public ON public.referral_settings;
