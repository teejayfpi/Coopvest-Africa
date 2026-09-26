-- Migration 048: salary-deduction members pick their employer at sign-up
--
-- WHY THIS EXISTS
-- ---------------
-- The registration-fee exemption for salary-deduction members (migration 035)
-- requires an employer on file, because that is the mechanism the fee is
-- recovered through. The shortened sign-up path never collected one: the
-- member picked "Salary Deduction" on the contribution screen, the app posted
-- to /kyc/contribution-type WITHOUT employment details, the endpoint answered
-- 422, and the app swallowed the error. So `contribution_method` and
-- `organization_id` were both NULL when the member reached the payment screen,
-- the derived exemption could not fire, and a member whose fee was going to be
-- deducted from salary was asked to pay it in-app anyway.
--
-- The fix collects the employer immediately after the contribution choice, so
-- the member arrives at payment with an employer recorded. This migration is
-- the schema and rule half of that.
--
-- WHAT CHANGES
-- ------------
--   1. `profiles.contribution_method` / `contribution_type` are created if
--      absent. The gate, the middleware and several routes have always READ
--      these columns, but no migration ever created them — they exist in
--      production by hand. A fresh environment built from these migrations
--      would fail the gate query outright.
--   2. The exemption accepts an employer that is LINKED (organization_id) or
--      REQUESTED (pending_organization_name). A member whose employer is not
--      enrolled yet has still committed to payroll deduction and named the
--      employer; the fee is recovered when that employer is enrolled and the
--      next payroll run posts it. Withholding the exemption until an admin
--      approves the request would lock the member out of the app over admin
--      latency — the same failure mode the KYC-approval gate was fixed for.
--      The pending request is recorded and visible to admins, so this is
--      reviewable, not a silent write-off.
--
-- Additive and idempotent; safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. Contribution channel columns on profiles
-- ---------------------------------------------------------------------------
-- `contribution_method` is written by the settings screen ('manual'/'payroll');
-- `contribution_type` by the KYC/contribution screens ('direct_deposit'/
-- 'salary_deduction'). Both are read as one channel via COALESCE.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS contribution_method TEXT,
  ADD COLUMN IF NOT EXISTS contribution_type TEXT;

COMMENT ON COLUMN public.profiles.contribution_method IS
  'Contribution channel: manual (self-paid) or payroll (employer deducts at source). Written by the settings screen and by the sign-up contribution step.';
COMMENT ON COLUMN public.profiles.contribution_type IS
  'Contribution channel as chosen at sign-up: direct_deposit or salary_deduction. Read alongside contribution_method via COALESCE.';

-- Backfill the channel from the KYC record, which is where the choice was
-- actually persisted before this migration. Without it, members who already
-- chose salary deduction keep a NULL channel on their profile and stay
-- wrongly gated. Only fills blanks, so a member who has since changed their
-- channel from settings is never overwritten.
UPDATE public.profiles p
SET contribution_type = k.personal_info->>'contribution_type',
    updated_at = NOW()
FROM public.kyc k
WHERE k.profile_id = p.id
  AND p.contribution_type IS NULL
  AND k.personal_info->>'contribution_type' IN ('direct_deposit', 'salary_deduction');

-- ---------------------------------------------------------------------------
-- 2. Exemption accepts a linked OR requested employer
-- ---------------------------------------------------------------------------
-- Mirrors `isRegistrationFeeSettled` in backend/src/lib/activationGate.js.
-- Keep the two in step — the JS helper is what the API enforces, this function
-- is what any SQL-side gate reads.

CREATE OR REPLACE FUNCTION public.member_registration_fee_settled(p public.profiles)
RETURNS BOOLEAN AS $$
  SELECT p.registration_fee_paid = TRUE
      OR (
        -- The app writes 'payroll' (settings screen) or 'salary_deduction'
        -- (sign-up/KYC screen) depending on which flow the member came
        -- through; both mean the employer deducts at source.
        COALESCE(p.contribution_method, p.contribution_type) IN ('payroll', 'salary_deduction')
        -- An employer must be on file: linked to a real organisation, or
        -- recorded as a pending enrolment request. Either way payroll has
        -- somewhere to recover the fee from.
        AND (
          p.organization_id IS NOT NULL
          OR p.pending_organization_name IS NOT NULL
        )
      );
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION public.member_registration_fee_settled(public.profiles) IS
  'True when the registration fee is settled, or when a salary-deduction member has an employer on file (linked or requested) so the fee is recovered via payroll remittance. Used by the account-activation gate.';
