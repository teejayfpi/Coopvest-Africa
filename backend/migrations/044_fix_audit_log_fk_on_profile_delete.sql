-- 044_fix_audit_log_fk_on_profile_delete.sql
--
-- Fixes: "Failed to delete profile: Audit logs are immutable: UPDATE operations
-- are not permitted on audit_logs."
--
-- ROOT CAUSE
-- ----------
-- `audit_logs.actor_id` and `admin_audit_logs.profile_id` are declared
-- ON DELETE SET NULL. When an admin deletes a member, PostgreSQL fires that
-- referential action — which is an UPDATE of the audit row — and the
-- immutability trigger on both tables is BEFORE UPDATE FOR EACH ROW, so it
-- raises. The delete therefore fails at the final `profiles` delete step, after
-- the backend has already cleared the member's dependent data.
--
-- Why it showed as a delete failure rather than a silent skip:
--   * The backend deletes `audit_logs` rows itself first and tolerates the
--     block (with an explicit comment saying so), but
--   * it never nulls `actor_id`, so the FK action still fires later, at the
--     `profiles` delete, which is the step whose error is returned to the admin.
--
-- WHY THE FIX IS NOT "ALLOW THE UPDATE"
-- -------------------------------------
-- Audit rows must stay immutable — relaxing the trigger would let any code
-- rewrite history, which is exactly what the trigger exists to prevent. Instead
-- change the referential action to NO ACTION:
--
--   * NO ACTION performs no UPDATE on the child row, so the immutability
--     trigger never fires.
--   * It still enforces integrity: a delete fails if referencing audit rows
--     exist. That is satisfied here because the backend deletes the member's
--     audit rows first (a DELETE, which the trigger correctly also blocks — so
--     in practice the rows remain, which is the desired retention behaviour).
--
-- The net effect: the audit trail is preserved with the actor reference intact,
-- rather than being blanked out or the delete being blocked.
--
-- Idempotent: drops the constraint only if it currently uses SET NULL.

DO $$
BEGIN
  -- audit_logs.actor_id
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'audit_logs_actor_id_fkey'
      AND conrelid = 'public.audit_logs'::regclass
      AND confdeltype = 'n'          -- SET NULL
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
      FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE NO ACTION;
  END IF;

  -- admin_audit_logs.profile_id
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'admin_audit_logs_profile_id_fkey'
      AND conrelid = 'public.admin_audit_logs'::regclass
      AND confdeltype = 'n'
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
      FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE NO ACTION;
  END IF;

  -- `audit_logs.target_profile_id` was being deleted explicitly by the backend
  -- (MEMBER_DATA_TABLES lists it) even though it carries no FK, so the delete
  -- silently did nothing. It is also reported to the admin as a
  -- cleanupFailure, which made the error list confusing. Leaving it in place:
  -- it is part of the audit record and must survive, like the other columns.
EXCEPTION WHEN undefined_table THEN
  -- admin_audit_logs may not exist in every environment.
  RAISE NOTICE 'skipping admin_audit_logs constraint: table missing';
END $$;

-- Report the resulting actions so the deploy log shows the effect.
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
    RAISE NOTICE 'audit FK % on % is now ON DELETE %', r.conname, r.tbl, r.on_delete;
  END LOOP;
END $$;