-- Migration 061: stop signed-in members writing money, KYC and admin tables
--
-- Audit of the live database (project nyoauzqezpxeonmrxxgi) confirmed the
-- exposure that migration 059 began to close, but only for `profiles`.
--
-- Supabase grants INSERT/UPDATE/DELETE on every table in `public` to `anon` and
-- `authenticated` by default. 96 tables still carry those grants. Combined with
-- permissive "own row" policies, that let a member write their own financial
-- records. Verified against the live database before this migration, running as
-- `authenticated` with a member JWT:
--
--   UPDATE public.wallets SET balance = 999999 ... -> succeeded
--   INSERT INTO public.transactions (amount 5000000, status 'completed') -> succeeded
--
-- The `wallets_self_modify` policy is FOR ALL with
-- `USING/WITH CHECK (profile_id = auth.uid())`, which is satisfied by a row that
-- belongs to the caller. Nothing stopped the caller from rewriting the money in
-- it, and no trigger guarded the columns (`set_updated_at` only stamps a time).
--
-- Why this is safe for the applications (each point checked in the source):
--   * the backend connects with the service role, which bypasses both grants
--     and RLS, so every write it performs is unaffected;
--   * the mobile app performs no direct table access at all - it calls
--     `supabase.auth` and the backend HTTP API only, and uses no `.rpc()`;
--   * the admin dashboard reads only `profiles` and writes only its own
--     name/phone/department, which is preserved;
--   * no client subscribes to the money tables over Realtime, so the SELECT
--     policies are the only ones that must stay;
--   * a new member's `profiles`, `wallets`, `savings` and `user_settings` rows
--     are created by the `on_auth_user_created` trigger, which is SECURITY
--     DEFINER, so no client INSERT is needed for signup.
--
-- Members keep write access to the tables that hold their own non-financial
-- data. Everything else becomes read-only to them, and a member's own rows stay
-- readable so the app can still display a balance.

-- ---------------------------------------------------------------------------
-- 1. Anonymous callers never write anything
-- ---------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- ---------------------------------------------------------------------------
-- 1b. Stop the next migration from recreating the problem
-- ---------------------------------------------------------------------------
-- `pg_default_acl` for `public` grants INSERT/UPDATE/DELETE to anon and
-- authenticated, so every table a future migration creates arrives client-
-- writable. Revoking the current grants without this would fix today's schema
-- and leave the next table exposed.
--
-- SELECT is deliberately left in the default: the app reads `profiles` through
-- the data API, and a new table that holds anything sensitive must still enable
-- RLS (a policy is what actually constrains rows).
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE USAGE, UPDATE ON SEQUENCES FROM anon, authenticated;

-- `postgres` does not own these defaults and cannot change them, so a table
-- created from the Supabase dashboard still arrives client-writable. Try, and
-- carry on if the role lacks the right — the assertion below still catches the
-- result.
DO $$
BEGIN
  ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
    REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM anon, authenticated;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE WARNING 'cannot change supabase_admin default privileges; tables created from the Supabase dashboard will still grant write access to anon/authenticated';
END $$;

-- ---------------------------------------------------------------------------
-- 2. Signed-in members write only user-owned, non-financial tables
-- ---------------------------------------------------------------------------
-- Tables kept writable for `authenticated`. Each policy on them is scoped to
-- the caller's own rows, and none of them holds a balance or a ledger entry.
DO $$
DECLARE
  preserve text[] := ARRAY[
    'profiles',                -- UPDATE only, column-limited by migration 059
    'device_tokens',
    'notifications',
    'user_settings',
    'watchlist',
    'tickets',
    'ticket_messages',
    'ticket_attachments',
    'ticket_status_history'
  ];
  t record;
BEGIN
  FOR t IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname <> ALL (preserve)
  LOOP
    EXECUTE format(
      'REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.%I FROM authenticated',
      t.relname
    );
  END LOOP;
END $$;

-- `profiles` keeps its column-limited UPDATE from 059, but signup is handled by
-- the SECURITY DEFINER trigger, so a client has no reason to INSERT or DELETE a
-- profile row. Allowing INSERT also let a caller create a profile row with an
-- arbitrary `role`, which is how `is_staff()` is decided.
REVOKE INSERT, DELETE, TRUNCATE ON public.profiles FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Drop the write policies that are now inert
-- ---------------------------------------------------------------------------
-- A revoked privilege already blocks the write, but leaving the policy in place
-- means a future `GRANT` silently reopens it. Remove them so the intent is
-- recorded in the schema itself. SELECT policies are untouched.
DO $$
DECLARE
  preserve text[] := ARRAY[
    'profiles',
    'device_tokens',
    'notifications',
    'user_settings',
    'watchlist',
    'tickets',
    'ticket_messages',
    'ticket_attachments',
    'ticket_status_history'
  ];
  p record;
BEGIN
  FOR p IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND cmd IN ('ALL', 'INSERT', 'UPDATE', 'DELETE')
      AND tablename <> ALL (preserve)
      AND (
        roles::text LIKE '%anon%'
        OR roles::text LIKE '%authenticated%'
        OR roles::text LIKE '%public%'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', p.policyname, p.tablename);
  END LOOP;
END $$;

-- The two `profiles` INSERT policies have no WITH CHECK, so they accepted a row
-- for any profile id. Only the INSERT ones are dropped; the UPDATE policies that
-- migration 059 relies on stay.
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND cmd = 'INSERT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', p.policyname);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 4. Assert the invariant, so a future migration cannot silently undo it
-- ---------------------------------------------------------------------------
-- The check is "no table is client-writable except the ones deliberately kept",
-- rather than a fixed list of sensitive tables. A new table added later would
-- otherwise pass the check simply by not being named in it.
DO $$
DECLARE
  preserve text[] := ARRAY[
    'profiles',
    'device_tokens',
    'notifications',
    'user_settings',
    'watchlist',
    'tickets',
    'ticket_messages',
    'ticket_attachments',
    'ticket_status_history'
  ];
  leaks text;
BEGIN
  SELECT string_agg(c.relname, ', ' ORDER BY c.relname)
  INTO leaks
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname <> ALL (preserve)
    AND (
      has_table_privilege('anon', c.oid, 'INSERT')
      OR has_table_privilege('anon', c.oid, 'UPDATE')
      OR has_table_privilege('anon', c.oid, 'DELETE')
      OR has_table_privilege('authenticated', c.oid, 'INSERT')
      OR has_table_privilege('authenticated', c.oid, 'UPDATE')
      OR has_table_privilege('authenticated', c.oid, 'DELETE')
    );

  IF leaks IS NOT NULL THEN
    RAISE EXCEPTION 'client write access still present on: %', leaks;
  END IF;
END $$;
