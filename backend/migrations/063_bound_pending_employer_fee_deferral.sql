-- Migration 063: bound the salary-deduction fee deferral, and stop clients
-- writing the columns it is derived from
--
-- WHY THIS EXISTS
-- ---------------
-- The registration-fee exemption (migration 048) and the monthly
-- administrative-fee exemption both treat a *self-declared* employer name
-- (`profiles.pending_organization_name`) as an employer on file. Nothing
-- verified that the employer existed, was ever enrolled, or would ever run
-- payroll, and nothing ever expired the claim. A member could therefore:
--
--   1. register, choose "salary deduction", and type any employer name;
--   2. be exempt from the ₦5,000 registration fee immediately (no payment), and
--   3. stay exempt from the ₦1,500 monthly administrative fee indefinitely,
--
-- while no payroll batch could ever recover either, because the named employer
-- was never enrolled. The only conversion to `registration_fee_paid = TRUE` is
-- a posted payroll batch (migration 035), which cannot happen for an employer
-- that does not exist.
--
-- The exemption is still wanted for the honest case: a member whose employer is
-- genuinely being enrolled must not be locked out of the app over admin latency.
-- So the fix bounds the *self-declared* case instead of removing it:
--
--   * a LINKED employer (`organization_id`) is admin-approved and exempts
--     indefinitely — unchanged;
--   * a NAMED employer (`pending_organization_name`) defers the fee only for
--     `PENDING_EMPLOYER_FEE_GRACE_DAYS` (default 45) counted from
--     `pending_organization_requested_at`. After that the fee is payable in the
--     app again.
--
-- Mirrors `isRegistrationFeeSettled` / `isAdministrativeFeeExempt` in
-- backend/src/lib/activationGate.js. Keep the two in step — the JS helper is
-- what the API enforces, this function is what any SQL-side gate reads.
--
-- Additive and idempotent; safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. The grace window, in one place
-- ---------------------------------------------------------------------------
-- Defined before the gate function below, because a SQL-language body is
-- validated at creation time and the reference must already resolve.
--
-- A function rather than a literal so the JS default
-- (DEFAULT_PENDING_EMPLOYER_GRACE_DAYS in lib/activationGate.js) and the SQL
-- gate can be changed together and reviewed as a pair.
CREATE OR REPLACE FUNCTION public.pending_employer_fee_grace_days()
RETURNS INTEGER AS $$
  SELECT 45;
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION public.pending_employer_fee_grace_days() IS
  'Days a self-declared (not yet enrolled) employer defers the registration fee. Mirrors DEFAULT_PENDING_EMPLOYER_GRACE_DAYS in backend/src/lib/activationGate.js.';

-- ---------------------------------------------------------------------------
-- 2. Bound the deferral on the SQL twin
-- ---------------------------------------------------------------------------
-- STABLE, not IMMUTABLE: the age is evaluated against NOW(). It is not used in
-- an index or a generated column, so STABLE is the correct and sufficient mark.
CREATE OR REPLACE FUNCTION public.member_registration_fee_settled(p public.profiles)
RETURNS BOOLEAN AS $$
  SELECT p.registration_fee_paid = TRUE
      OR (
        -- The app writes 'payroll' (settings screen) or 'salary_deduction'
        -- (sign-up/KYC screen) depending on which flow the member came
        -- through; both mean the employer deducts at source.
        COALESCE(p.contribution_method, p.contribution_type) IN ('payroll', 'salary_deduction')
        AND (
          -- A linked organisation is admin-approved: exempt indefinitely.
          p.organization_id IS NOT NULL
          -- A named employer is self-declared and unverified: it defers the fee
          -- only inside the bounded window anchored on the first request. A
          -- missing anchor does not defer anything, so an unverifiable claim
          -- can never grant the exemption.
          OR (
            p.pending_organization_name IS NOT NULL
            AND p.pending_organization_requested_at IS NOT NULL
            -- An anchor in the future must not count: the elapsed time would be
            -- negative, pass the window check, and defer the fee permanently.
            AND p.pending_organization_requested_at <= NOW() + INTERVAL '5 minutes'
            AND p.pending_organization_requested_at
                > NOW() - make_interval(days => public.pending_employer_fee_grace_days())
          )
        )
      );
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION public.member_registration_fee_settled(public.profiles) IS
  'True when the registration fee is settled, or when a salary-deduction member has an employer on file. A linked organisation exempts indefinitely; a self-declared (pending) employer defers the fee only for the bounded grace window. Used by the account-activation gate.';

-- ---------------------------------------------------------------------------
-- 3. Backfill the anchor for members already waiting
-- ---------------------------------------------------------------------------
-- Members who named an employer through the shortened sign-up path have a NULL
-- anchor (only /organizations/request-approval stamped one). The new rule treats
-- a missing anchor as "no deferral", which would charge every one of them the
-- fee at deploy, including the ones whose employer really is being enrolled.
-- Stamp them from NOW() so their window starts when this ships.
--
-- Only fills blanks, so a member who already has an anchor is never moved.
-- NOTE: a member whose anchor is already older than the grace window loses the
-- deferral as soon as this migration runs. That is the intended tightening, but
-- it can surface as a deploy-day cliff for a long-waiting honest member, so
-- clear the admin pending-requests queue (GET /organizations/pending-requests)
-- around the same time. `PENDING_EMPLOYER_FEE_GRACE_DAYS` can be raised for the
-- transition without a code change.
UPDATE public.profiles
SET pending_organization_requested_at = NOW()
WHERE pending_organization_name IS NOT NULL
  AND organization_id IS NULL
  AND pending_organization_requested_at IS NULL;

-- ---------------------------------------------------------------------------
-- 4. Stop clients writing the columns the exemption is derived from
-- ---------------------------------------------------------------------------
-- Migration 059 granted UPDATE on these columns to `authenticated` so the
-- mobile app could write them through the Supabase data API. It does not: the
-- app performs no direct table access (it calls the backend HTTP API), and the
-- backend connects with the service role, which bypasses both grants and RLS.
-- So the grants are unused by every application, while they let any signed-in
-- member set `contribution_method = 'payroll'` and
-- `pending_organization_name = 'anything'` on their own row directly, with the
-- Supabase anon key that ships inside the app — bypassing the endpoint
-- validation (the active-organisation check in /kyc/contribution-type) and
-- reopening the exemption this migration closes.
--
-- Revoking the columns is safe for the admin dashboard too: it writes only its
-- own name/phone/department (see migration 059), none of which is touched here.
REVOKE UPDATE (
  contribution_method,
  contribution_type,
  pending_organization_name,
  pending_organization_requested_at
) ON public.profiles FROM authenticated, anon;

-- ---------------------------------------------------------------------------
-- 5. Assert the invariant, so a future migration cannot silently undo it
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  leaked text;
BEGIN
  SELECT string_agg(column_name, ', ' ORDER BY column_name)
  INTO leaked
  FROM information_schema.column_privileges
  WHERE table_schema = 'public'
    AND table_name = 'profiles'
    AND privilege_type = 'UPDATE'
    AND grantee IN ('anon', 'authenticated')
    AND column_name IN (
      'contribution_method',
      'contribution_type',
      'pending_organization_name',
      'pending_organization_requested_at'
    );

  IF leaked IS NOT NULL THEN
    RAISE EXCEPTION 'exemption columns are still client-writable: %', leaked;
  END IF;
END $$;
