-- Migration 066: one phone number, one member
--
-- A member registers with a phone number, and that number must not be usable to
-- register a second account. Nothing enforced that. `profiles.phone` was a plain
-- TEXT column with no constraint, and the app writes it through
-- `handle_new_user()` on every sign-up.
--
-- Why the raw column cannot carry the constraint
-- ----------------------------------------------
-- The live database already contains the counter-example this design has to
-- survive:
--
--   ayanlowo89@gmail.com        +2347038193753
--   coopvestafrica@gmail.com    07038193753
--
-- Same Nigerian line, two notations. A UNIQUE index on `phone` would call those
-- two rows distinct and report the rule satisfied. So the constraint lives on a
-- derived key: `phone_normalized`, the number reduced to its ten-digit national
-- significant number by `normalize_phone_key()`.
--
-- The key is derived by trigger, not by the application. Three different code
-- paths write `profiles.phone` (POST /auth/register, POST /auth/sync,
-- PUT /user/profile) and the admin dashboard writes it directly through
-- PostgREST. A rule that only the API remembers is a rule with three holes in
-- it. A BEFORE INSERT OR UPDATE trigger covers all of them, including a direct
-- SQL edit.
--
-- Pre-existing duplicates
-- -----------------------
-- The index cannot be created while two rows share a key, and deleting a
-- member's account to satisfy a new constraint is not an option. Collisions are
-- therefore recorded in `phone_duplicate_reviews` for an operator to resolve,
-- the oldest account keeps the key (it is the original holder of the number),
-- and later rows are left with a NULL key. NULL keys are outside the index, so
-- a legacy duplicate keeps working while every NEW registration is refused.
--
-- Idempotent: safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. The normalisation function
-- ---------------------------------------------------------------------------
-- Mirrors backend/src/lib/phoneNumber.js. Both must agree, because the API
-- pre-checks with the JS version and the index enforces with this one.
CREATE OR REPLACE FUNCTION public.normalize_phone_key(raw TEXT)
RETURNS TEXT AS $$
DECLARE
  digits TEXT;
BEGIN
  IF raw IS NULL THEN
    RETURN NULL;
  END IF;

  digits := regexp_replace(raw, '[^0-9]', '', 'g');

  IF digits = '' THEN
    RETURN NULL;
  END IF;

  -- +234XXXXXXXXXX
  IF length(digits) = 13 AND left(digits, 3) = '234' THEN
    RETURN substr(digits, 4);
  END IF;

  -- 0XXXXXXXXXX
  IF length(digits) = 11 AND left(digits, 1) = '0' THEN
    RETURN substr(digits, 2);
  END IF;

  -- Already the national significant number.
  IF length(digits) = 10 THEN
    RETURN digits;
  END IF;

  -- Unrecognised shape: compare on the digits as given rather than inventing a
  -- country code. The API rejects these before they get here.
  RETURN digits;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ---------------------------------------------------------------------------
-- 2. The derived column
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_normalized TEXT;

COMMENT ON COLUMN public.profiles.phone_normalized IS
  'normalize_phone_key(phone); the uniqueness key for phone numbers. Maintained by trigger, never written by clients.';

-- ---------------------------------------------------------------------------
-- 3. Backfill, oldest profile first
-- ---------------------------------------------------------------------------
-- Only the earliest profile for each key is given a value. Writing every key
-- first and clearing the losers afterwards would work once, but on a re-run the
-- backfill would try to restore a key that is already held and fail on the
-- unique index. Ranking here means the statement is correct on every run.
WITH ranked AS (
  SELECT id,
         public.normalize_phone_key(phone) AS key,
         ROW_NUMBER() OVER (
           PARTITION BY public.normalize_phone_key(phone)
           ORDER BY created_at ASC NULLS LAST, id ASC
         ) AS rn
    FROM public.profiles
   WHERE phone IS NOT NULL
)
UPDATE public.profiles p
   SET phone_normalized = r.key
  FROM ranked r
 WHERE p.id = r.id
   AND r.rn = 1
   AND r.key IS NOT NULL
   AND p.phone_normalized IS DISTINCT FROM r.key;

-- ---------------------------------------------------------------------------
-- 4. Record pre-existing collisions, then step out of the index's way
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.phone_duplicate_reviews (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_key     TEXT NOT NULL,
  profile_id    UUID,
  email         TEXT,
  kept_profile_id UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at   TIMESTAMPTZ,
  note          TEXT
);

COMMENT ON TABLE public.phone_duplicate_reviews IS
  'Phone numbers that were already shared by more than one profile when uniqueness was introduced (migration 066). The oldest profile keeps the key; the rest are listed here for an operator to resolve.';

-- The earliest profile for each number is the original holder of it.
WITH ranked AS (
  SELECT id,
         public.normalize_phone_key(phone) AS key,
         ROW_NUMBER() OVER (
           PARTITION BY public.normalize_phone_key(phone)
           ORDER BY created_at ASC NULLS LAST, id ASC
         ) AS rn,
         FIRST_VALUE(id) OVER (
           PARTITION BY public.normalize_phone_key(phone)
           ORDER BY created_at ASC NULLS LAST, id ASC
         ) AS keeper
    FROM public.profiles
   WHERE phone IS NOT NULL
     AND public.normalize_phone_key(phone) IS NOT NULL
),
losers AS (
  SELECT r.id, r.key, r.keeper
    FROM ranked r
   WHERE r.rn > 1
)
INSERT INTO public.phone_duplicate_reviews (phone_key, profile_id, email, kept_profile_id, note)
SELECT l.key,
       l.id,
       p.email,
       l.keeper,
       'Pre-existing duplicate at migration 066; key cleared so the unique index could be created.'
  FROM losers l
  LEFT JOIN public.profiles p ON p.id = l.id
 WHERE NOT EXISTS (
   SELECT 1 FROM public.phone_duplicate_reviews d
    WHERE d.profile_id = l.id AND d.phone_key = l.key
 );

-- Clearing the key (rather than deleting the row) keeps the account usable:
-- NULL keys are outside the partial unique index, so a legacy duplicate can
-- still sign in, while every new registration for that number is refused.
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY public.normalize_phone_key(phone)
           ORDER BY created_at ASC NULLS LAST, id ASC
         ) AS rn
    FROM public.profiles
   WHERE phone IS NOT NULL
     AND public.normalize_phone_key(phone) IS NOT NULL
)
UPDATE public.profiles p
   SET phone_normalized = NULL
  FROM ranked r
 WHERE p.id = r.id
   AND r.rn > 1
   AND p.phone_normalized IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 5. Keep the key in step with the column, for every writer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_profile_phone_normalized()
RETURNS trigger AS $$
BEGIN
  -- A save that re-sends the same number must not re-derive the key. A legacy
  -- duplicate (see section 4) has a NULL key on purpose, and recomputing it
  -- here would collide with the profile that kept the number, failing a save
  -- the member did not change anything in.
  IF TG_OP = 'UPDATE' AND NEW.phone IS NOT DISTINCT FROM OLD.phone THEN
    RETURN NEW;
  END IF;

  NEW.phone_normalized := public.normalize_phone_key(NEW.phone);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_profile_phone_normalized ON public.profiles;
CREATE TRIGGER trg_sync_profile_phone_normalized
  BEFORE INSERT OR UPDATE OF phone ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_phone_normalized();

-- ---------------------------------------------------------------------------
-- 6. The constraint
-- ---------------------------------------------------------------------------
-- Partial: a profile without a phone (or a legacy duplicate whose key was
-- cleared above) is not constrained.
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_phone_normalized_unique
  ON public.profiles (phone_normalized)
  WHERE phone_normalized IS NOT NULL;

-- Supports the API's availability pre-check, which looks up a key before an
-- account exists.
CREATE INDEX IF NOT EXISTS idx_profiles_phone_normalized
  ON public.profiles (phone_normalized);
