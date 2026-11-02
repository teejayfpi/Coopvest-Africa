-- Migration 057: make contributions and member_fees read-only to members
--
-- Why this exists
-- ---------------
-- Migration 047 closed the anonymous *read* exposure on these tables by giving
-- them a self-row policy. The policy it wrote was `FOR ALL TO authenticated
-- USING (profile_id = auth.uid())`, and FOR ALL includes INSERT and UPDATE.
--
-- The anon key is embedded in the shipped mobile app and the dashboard JS, so
-- it is public. With it, a signed-in member can talk to PostgREST directly and
-- INSERT or UPDATE their own contributions / member_fees rows — bypassing the
-- API, which is the only place that records a ledger entry and checks that a
-- deposit actually settled. The API itself connects with the service-role key
-- and is unaffected by RLS, so this changes nothing for normal operation.
--
-- These are member money records: a member may read their own, and may never
-- write them. Any correction must go through the API (service role), which
-- writes the matching ledger entry.
--
-- Additive and idempotent. No data is modified or dropped.

-- ---------------------------------------------------------------------------
-- contributions — SELECT own rows only
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS contributions_own_rows ON public.contributions;
CREATE POLICY contributions_own_rows ON public.contributions
  FOR SELECT TO authenticated USING (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- member_fees — SELECT own rows only
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS member_fees_own_rows ON public.member_fees;
CREATE POLICY member_fees_own_rows ON public.member_fees
  FOR SELECT TO authenticated USING (profile_id = auth.uid());

-- The *_service policies written by migration 047 are FOR ALL TO service_role
-- and are left in place: the API keeps full read/write through the service key.
