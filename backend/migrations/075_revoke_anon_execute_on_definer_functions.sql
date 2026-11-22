-- ---------------------------------------------------------------------------
-- 075  Revoke EXECUTE on SECURITY DEFINER functions from anon/authenticated
-- ---------------------------------------------------------------------------
-- Postgres grants EXECUTE on a new function to PUBLIC by default. Because
-- Supabase's `anon` and `authenticated` roles inherit from PUBLIC, every
-- SECURITY DEFINER function in this schema was callable by anyone holding the
-- anon key - which is public by design, since it ships in the dashboard bundle.
--
-- For a SECURITY DEFINER function that is worse than a missing grant: the
-- function body runs as its owner (postgres) with RLS bypassed, so the caller
-- inherits full table access. Twelve functions were exposed this way,
-- including:
--
--   admin_adjust_wallet_balance  credits or debits an arbitrary wallet.
--                                Takes p_admin_id as a parameter and never
--                                checks the caller against it, so any caller
--                                can move money and attribute it to any admin.
--   admin_set_wallet_status      freezes or unfreezes any wallet.
--   loan_disburse                disburses a loan.
--   loan_settle_from_savings     settles a loan from savings.
--   handle_new_user              runs on signup.
--
-- Confirmed exploitable before this fix: an unauthenticated RPC call to
-- admin_adjust_wallet_balance with a bogus wallet id returned
-- "23503 Wallet not found" - i.e. the function body executed. Had the wallet
-- existed, the balance would have changed.
--
-- The API calls these through supabase.rpc() with the service-role key, so
-- service_role keeps EXECUTE. Nothing else needs it.
--
-- EXCEPTION: is_staff() is referenced by RLS policies. Policies are evaluated
-- as the querying role, so `authenticated` (and `anon`) must retain EXECUTE on
-- it or every staff-scoped policy raises "permission denied for function".
-- is_staff() only reads the caller's own profile row and returns a boolean, so
-- exposing it leaks nothing. Idempotent.

DO $$
DECLARE
  f RECORD;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig
      FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace
       AND p.prosecdef
       AND p.proname NOT IN ('is_staff')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f.sig);
  END LOOP;
END $$;

-- Policy helper: must stay callable by the roles policies are evaluated as.
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated, anon;
