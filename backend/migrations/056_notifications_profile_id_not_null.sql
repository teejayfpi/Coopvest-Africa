-- 056_notifications_profile_id_not_null.sql
-- A notification is addressed to exactly one member.
--
-- `profile_id IS NULL` rows are global, not per-member: the RLS policy
-- (`profile_id = auth.uid() OR is_staff()`) makes them visible to every member,
-- and admin fan-out writes one row per recipient. So a row inserted without a
-- profile leaked a single message into every member's feed. The application now
-- filters member reads to their own profile_id; this enforces the invariant at
-- the database so a stray insert can never create a global row again.
--
-- Idempotent and self-guarding: it is a no-op once the column is NOT NULL, and
-- it only runs when no NULL rows remain (a NULL would make the ALTER fail, and
-- we would rather skip than abort the whole migration).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'notifications'
      AND column_name = 'profile_id'
      AND is_nullable = 'YES'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.notifications WHERE profile_id IS NULL
  ) THEN
    ALTER TABLE public.notifications ALTER COLUMN profile_id SET NOT NULL;
  END IF;
END $$;
