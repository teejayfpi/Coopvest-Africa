-- Migration 051: backfill the contribution channel for members who signed up
-- through the full wizard
--
-- WHY THIS EXISTS
-- ---------------
-- The contribution channel (profiles.contribution_method / contribution_type)
-- drives two rules: the registration-fee exemption (migration 048) and
-- guarantor eligibility (backend/src/lib/guarantorEligibility.js). Two sign-up
-- routes can record it, and until now only the shortened path
-- (POST /kyc/contribution-type) wrote it to the profile. The full wizard posts
-- everything to POST /auth/complete-registration, which wrote only `department`
-- and the completion flags — the channel stayed NULL.
--
-- The code fix now makes both routes write the profile. This migration repairs
-- the members who registered before that fix and are therefore still
-- mis-classified: a salary-deduction member reads as direct deposit, so the fee
-- exemption does not fire and they are asked to pay in-app, and guarantors are
-- matched against the wrong channel.
--
-- Only fills blanks, so a member who has since changed their channel from
-- settings is never overwritten — same guard as migration 048.
--
-- Additive and idempotent; safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. Channel + method from the KYC record
-- ---------------------------------------------------------------------------
-- `contribution_method` is the settings spelling ('manual'/'payroll');
-- `contribution_type` is the sign-up spelling ('direct_deposit'/
-- 'salary_deduction'). Both are written here, matching what
-- /kyc/contribution-type records, so either reader (activationGate.js,
-- guarantorEligibility.js) resolves the same channel.
UPDATE public.profiles p
SET contribution_method = CASE k.personal_info->>'contribution_type'
      WHEN 'salary_deduction' THEN 'payroll'
      ELSE 'manual'
    END,
    contribution_type = k.personal_info->>'contribution_type',
    updated_at = NOW()
FROM public.kyc k
WHERE k.profile_id = p.id
  AND p.contribution_type IS NULL
  AND k.personal_info->>'contribution_type' IN ('direct_deposit', 'salary_deduction');

-- ---------------------------------------------------------------------------
-- 2. Employer on file for salary-deduction members
-- ---------------------------------------------------------------------------
-- The fee exemption needs an employer on file, not only the channel. The wizard
-- collected the employer into kyc.employment_info.employer_name and mirrored it
-- to profiles.department, never to organization_id/pending_organization_name.
-- Record it as a pending request, exactly as the code now does for an employer
-- whose organisation is not enrolled. Guarded so an already-linked organisation
-- is never overwritten.
UPDATE public.profiles p
SET pending_organization_name = k.employment_info->>'employer_name',
    updated_at = NOW()
FROM public.kyc k
WHERE k.profile_id = p.id
  AND p.contribution_type = 'salary_deduction'
  AND p.organization_id IS NULL
  AND p.pending_organization_name IS NULL
  AND NULLIF(BTRIM(k.employment_info->>'employer_name'), '') IS NOT NULL;
