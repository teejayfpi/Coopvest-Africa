-- Migration 058: referral_settings (single-row program configuration)
--
-- Why this exists
-- ---------------
-- `GET /api/admin/referrals` and `PUT /api/admin/referrals/settings` in
-- `src/routes/adminApi.js` read and write `referral_settings`. On the live
-- database the table already exists and uses `program_enabled`, not `enabled`.
-- The API was writing `enabled`, which raised "column does not exist", so the
-- Admin Dashboard's Referral Program page could not save its settings. The
-- code now targets `program_enabled` (accepting `enabled` as a fallback); this
-- migration makes a fresh database match production so the two never drift.
--
-- The member reward is a tiered interest discount (see REFERRAL.md).
-- `bonus_per_referral` does not credit any wallet; it is a notional reporting
-- value only.
--
-- Additive and idempotent. No data is modified or dropped.

CREATE TABLE IF NOT EXISTS public.referral_settings (
  id INTEGER PRIMARY KEY DEFAULT 1,
  program_enabled BOOLEAN DEFAULT true,
  bonus_per_referral DECIMAL(18, 2) DEFAULT 2000,
  max_referrals_per_user INTEGER DEFAULT 50,
  minimum_deposit_for_bonus DECIMAL(18, 2) DEFAULT 5000,
  bonus_payout_delay_days INTEGER DEFAULT 7,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT referral_settings_single_row CHECK (id = 1)
);

-- Seed the single row the admin endpoints expect, without duplicating it on
-- re-run. The API treats an absent row as "enabled, no bonus" anyway.
INSERT INTO public.referral_settings (id, program_enabled, bonus_per_referral, max_referrals_per_user)
SELECT 1, true, 0, 0
WHERE NOT EXISTS (SELECT 1 FROM public.referral_settings);

ALTER TABLE public.referral_settings ENABLE ROW LEVEL SECURITY;
