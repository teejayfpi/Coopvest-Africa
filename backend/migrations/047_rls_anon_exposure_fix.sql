-- Migration 047: close the anonymous read exposure on member and organisation data
--
-- Why this exists
-- ---------------
-- The Supabase anon key is embedded in the mobile app bundle and in the admin
-- dashboard's shipped JavaScript, so it is effectively public. With that key
-- alone, and no login at all, the following were readable directly through
-- PostgREST — bypassing the app and the API:
--
--   device_tokens    13 rows   FCM push tokens
--   profiles          7 rows   BVN, NIN, bank account number, phone
--   contributions     5 rows   member money records
--   member_fees       2 rows   member fee obligations
--   organizations   411 rows   remittance bank account numbers
--
-- The push tokens were the worst of these: the token value alone is enough to
-- send a push notification to that member's device through FCM.
--
-- Root causes, established by probing the live project rather than by reading
-- the schema:
--
--   * `device_tokens`, `contributions` and `member_fees` had RLS DISABLED
--     entirely (relrowsecurity = false), so every row was world-readable.
--   * `profiles` had three permissive `USING (true)` SELECT policies. Postgres
--     ORs permissive policies together, so one such policy defeats every
--     restrictive one beside it.
--   * `organizations` had a single `FOR ALL USING (true)` policy.
--
-- Why the backend is unaffected: the API connects with the service-role key,
-- which bypasses RLS. Only direct PostgREST access with the anon key was
-- exposed. Verified after applying: service role still reads all tables, push
-- delivery still returns status=sent, and a member reading another member's
-- rows returns zero.
--
-- Additive and idempotent. No data is modified or dropped.

-- ---------------------------------------------------------------------------
-- 1. device_tokens
-- ---------------------------------------------------------------------------
-- Members may manage their own device tokens (the app registers its token at
-- login and deactivates it on logout). Nobody may enumerate them.

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS device_tokens_self ON public.device_tokens;
CREATE POLICY device_tokens_self ON public.device_tokens
  FOR ALL TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

-- Explicit service-role policy, so the intent is visible in the schema rather
-- than relying on the implicit bypass.
DROP POLICY IF EXISTS device_tokens_service ON public.device_tokens;
CREATE POLICY device_tokens_service ON public.device_tokens
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 2. contributions and member_fees
-- ---------------------------------------------------------------------------
-- Both tables held every member's money records with RLS off. A member may see
-- their own; the API (service role) sees all.

ALTER TABLE public.contributions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS contributions_own_rows ON public.contributions;
CREATE POLICY contributions_own_rows ON public.contributions
  FOR SELECT TO authenticated USING (profile_id = auth.uid());
DROP POLICY IF EXISTS contributions_service ON public.contributions;
CREATE POLICY contributions_service ON public.contributions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

ALTER TABLE public.member_fees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS member_fees_own_rows ON public.member_fees;
CREATE POLICY member_fees_own_rows ON public.member_fees
  FOR SELECT TO authenticated USING (profile_id = auth.uid());
DROP POLICY IF EXISTS member_fees_service ON public.member_fees;
CREATE POLICY member_fees_service ON public.member_fees
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 3. profiles — remove the world-readable policies
-- ---------------------------------------------------------------------------
-- Three permissive `USING (true)` policies made every member's PII readable.
-- The self-access and service-role policies already existed and are kept; the
-- `is_staff()` UPDATE policy is untouched.

DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS profiles_public_select ON public.profiles;
DROP POLICY IF EXISTS service_role_all_profiles_mobile ON public.profiles;

DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
CREATE POLICY profiles_self_select ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS profiles_service_all ON public.profiles;
CREATE POLICY profiles_service_all ON public.profiles
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 4. organizations — keep the picker, drop the banking details
-- ---------------------------------------------------------------------------
-- The member app needs the employer list to choose from, but not the
-- remittance bank account numbers that were also exposed. The table is locked
-- to authenticated + service role; a deliberately narrow view covers the picker.

DROP POLICY IF EXISTS "Allow all for service role" ON public.organizations;

DROP POLICY IF EXISTS organizations_read ON public.organizations;
CREATE POLICY organizations_read ON public.organizations
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS organizations_service ON public.organizations;
CREATE POLICY organizations_service ON public.organizations
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Safe projection: no remittance_* / contact_* columns.
CREATE OR REPLACE VIEW public.organizations_public AS
  SELECT id, name, code, type, status, is_active, deduction_enabled, member_count
    FROM public.organizations
   WHERE is_active = TRUE;

GRANT SELECT ON public.organizations_public TO anon, authenticated;

COMMENT ON VIEW public.organizations_public IS
  'Employer picker source. Deliberately excludes remittance banking and contact columns so the anon key can list institutions without exposing where money is sent.';
