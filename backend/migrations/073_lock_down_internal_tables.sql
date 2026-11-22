-- ---------------------------------------------------------------------------
-- 073  Lock down internal tables that were readable by anonymous clients
-- ---------------------------------------------------------------------------
-- Both tables were created outside the normal policy work and shipped with RLS
-- disabled while `anon` held a SELECT grant. The anon key is public by design
-- (it is compiled into the dashboard bundle), so "no RLS" here meant "the
-- internet can read this".
--
-- `phone_duplicate_reviews` was the serious one: it carries `phone_key`,
-- `email` and `profile_id` for every profile that shared a phone number when
-- the uniqueness index was introduced (migration 066). Confirmed readable with
-- the published anon key, no login required.
--
-- Neither table is read or written by application code: `phone_duplicate_reviews`
-- is written by migration 066 and resolved by an operator, and
-- `schema_migrations` is the runner's own ledger. The API uses the service-role
-- key, which bypasses RLS, so neither client is affected by this.
--
-- RLS with no policies is the intended end state: deny-all to anon and
-- authenticated, full access to service_role. Idempotent.

ALTER TABLE public.phone_duplicate_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.phone_duplicate_reviews FROM anon, authenticated;

ALTER TABLE public.schema_migrations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.schema_migrations FROM anon, authenticated;
