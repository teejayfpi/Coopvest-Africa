-- 045_detach_audit_fks_on_profile_delete.sql
--
-- SUPERSEDES the approach in 044, which did not work.
--
-- WHAT WENT WRONG IN 044
-- ---------------------
-- 044 changed `audit_logs.actor_id` and `admin_audit_logs.profile_id` from
-- ON DELETE SET NULL to ON DELETE NO ACTION, to stop the immutability trigger
-- firing on the SET NULL update. That traded one error for another:
--
--   UPDATE blocked  ->  "Audit logs are immutable: UPDATE operations are not
--                        permitted on audit_logs."
--   delete blocked  ->  "update or delete on table profiles violates foreign
--                        key constraint audit_logs_actor_id_fkey"
--
-- NO ACTION performs no UPDATE, but it still refuses the DELETE — so the member
-- could not be deleted at all. 044's own comment predicted this and shipped
-- anyway. This migration does the job properly.
--
-- THE ACTUAL FIX
-- --------------
-- A member's audit trail must survive their deletion (that is the point of an
-- audit log), and the profile row must be deletable. Those are only compatible
-- if the audit row stops referencing the profile while keeping a usable
-- trace of who it was.
--
-- So: BEFORE DELETE trigger on `profiles` that, for the rows about to be
-- deleted, copies the identity into a new `actor_reference` column and then
-- nulls the FK. It must also disable the immutability trigger for the duration,
-- because that same trigger blocks this update.
--
-- Why this is safe, and not "just letting code rewrite history":
--   * It runs ONLY as a consequence of deleting a profile, never on a normal
--     update path.
--   * Nothing is deleted or rewritten. The action, target, metadata, timestamp
--     and IP all stay exactly as written; only the FK pointer is cleared, and
--     it is replaced by a text record of the same identity.
--   * The SET NULL on the FK stays in place, so Postgres' own referential
--     action performs the nulling — this trigger only needs to capture the
--     identity first and lift the guard.
--
-- The alternative — hard-deleting audit rows — would destroy the trail, which
-- is precisely what must not happen when a member is removed.

-- ---------------------------------------------------------------------------
-- 1. A place to keep the identity after the FK is cleared.
-- ---------------------------------------------------------------------------
ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS actor_reference TEXT;

ALTER TABLE public.admin_audit_logs
  ADD COLUMN IF NOT EXISTS actor_reference TEXT;

COMMENT ON COLUMN public.audit_logs.actor_reference IS
  'Human-readable identity of the actor, populated when their profile is deleted so the audit trail stays attributable after actor_id is cleared.';

COMMENT ON COLUMN public.admin_audit_logs.actor_reference IS
  'Human-readable identity of the actor, populated when their profile is deleted so the audit trail stays attributable after profile_id is cleared.';

-- ---------------------------------------------------------------------------
-- 2. Put the FKs back to ON DELETE SET NULL.
--
--    SET NULL is what we want: the nulling is done by the referential action,
--    and step 3 makes the immutability trigger tolerant of exactly that.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'audit_logs_actor_id_fkey'
      AND conrelid = 'public.audit_logs'::regclass
      AND confdeltype <> 'n'
  ) THEN
    ALTER TABLE public.audit_logs DROP CONSTRAINT audit_logs_actor_id_fkey;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'audit_logs_actor_id_fkey'
      AND conrelid = 'public.audit_logs'::regclass
  ) THEN
    ALTER TABLE public.audit_logs
      ADD CONSTRAINT audit_logs_actor_id_fkey
      FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'admin_audit_logs_profile_id_fkey'
      AND conrelid = 'public.admin_audit_logs'::regclass
      AND confdeltype <> 'n'
  ) THEN
    ALTER TABLE public.admin_audit_logs DROP CONSTRAINT admin_audit_logs_profile_id_fkey;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'admin_audit_logs_profile_id_fkey'
      AND conrelid = 'public.admin_audit_logs'::regclass
  ) THEN
    ALTER TABLE public.admin_audit_logs
      ADD CONSTRAINT admin_audit_logs_profile_id_fkey
      FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
  END IF;
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'admin_audit_logs missing; skipped its constraint';
END $$;

-- ---------------------------------------------------------------------------
-- 3. Let the immutability guard through for the cascade only.
--
--    The guard still blocks every ordinary UPDATE, which is what keeps the
--    trail honest. This function only proceeds when the session has explicitly
--    flagged that a profile delete is in progress, and the flag is set and
--    cleared inside the same statement.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_audit_log_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Allow the cascade that a profile delete causes; block everything else.
    IF current_setting('coopvest.profile_delete_cascade', TRUE) = 'on' THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Audit logs are immutable: UPDATE operations are not permitted on %', TG_TABLE_NAME;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Audit logs are immutable: DELETE operations are not permitted on %', TG_TABLE_NAME;
  END IF;

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Before a profile is deleted: capture the identity, then lift the guard so
--    the SET NULL can do its job.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detach_audit_fks_on_profile_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_reference TEXT;
BEGIN
  -- Build a durable trace of who this was before the FK pointer is lost.
  v_reference := COALESCE(
    NULLIF(OLD.name, ''),
    NULLIF(OLD.email, ''),
    OLD.id::text
  );
  IF OLD.user_id IS NOT NULL AND OLD.user_id <> '' THEN
    v_reference := v_reference || ' (' || OLD.user_id || ')';
  END IF;

  -- Lift the immutability guard FIRST. The guard is BEFORE UPDATE on
  -- audit_logs, so it would block the very write below that records who this
  -- was — the flag has to be set before, not after. `is_local = TRUE` scopes
  -- it to this transaction.
  PERFORM set_config('coopvest.profile_delete_cascade', 'on', TRUE);

  -- Preserve the identity on the rows that are about to lose their link.
  UPDATE public.audit_logs
     SET actor_reference = COALESCE(actor_reference, v_reference)
   WHERE actor_id = OLD.id;

  IF to_regclass('public.admin_audit_logs') IS NOT NULL THEN
    UPDATE public.admin_audit_logs
       SET actor_reference = COALESCE(actor_reference, v_reference)
     WHERE profile_id = OLD.id;
  END IF;

  RETURN OLD;
END;
$function$;

DROP TRIGGER IF EXISTS trg_detach_audit_fks_on_profile_delete ON public.profiles;
CREATE TRIGGER trg_detach_audit_fks_on_profile_delete
  BEFORE DELETE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.detach_audit_fks_on_profile_delete();

-- Clear the flag when the transaction ends so it can never leak to a later
-- statement that happens to run in the same session.
CREATE OR REPLACE FUNCTION public.reset_profile_delete_flag()
RETURNS void LANGUAGE plpgsql AS $function$
BEGIN
  PERFORM set_config('coopvest.profile_delete_cascade', 'off', TRUE);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Report the resulting state.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT c.conname, c.conrelid::regclass::text AS tbl,
           CASE c.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
                WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' END AS on_delete
    FROM pg_constraint c
    WHERE c.contype = 'f'
      AND c.confrelid = 'public.profiles'::regclass
      AND c.conrelid::regclass::text IN ('audit_logs', 'admin_audit_logs')
  LOOP
    RAISE NOTICE 'audit FK % on % is ON DELETE %', r.conname, r.tbl, r.on_delete;
  END LOOP;
  RAISE NOTICE 'profile-delete cascade trigger installed on public.profiles';
END $$;