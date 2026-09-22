-- Migration 046: announcement display modes, targeting and direct messages
--
-- Why this exists
-- ---------------
-- The `announcements` table already existed with read-tracking
-- (`announcement_reads`) and five member-facing endpoints, but nothing could
-- write to it: the admin "Announcement Editor" saved to React state only and
-- showed a success toast, so no announcement has ever reached a device.
--
-- The Flutter model also reads fields the API never returned (`content`,
-- `type`, `isPinned`, camelCase dates), so even had a row existed the client
-- would have rendered blank. The backend now returns the client's shape; these
-- columns give the admin the controls the business asked for.
--
-- Additive and idempotent. Nothing here rewrites or drops existing data.
--
-- Display modes the admin can choose:
--   'banner'  — a card in the announcements list (the pre-existing behaviour)
--   'popup'   — a dialog the member must dismiss; "users see it pop up"
--   'marquee' — a scrolling ticker across the app; "news like a marquee"
--   'all'     — banner + popup + marquee
--
-- Targeting:
--   audience 'all'      — every member
--   audience 'specific' — only the profile ids in target_profile_ids
--   audience 'organization' — only members of target_organization_id

-- ---------------------------------------------------------------------------
-- 1. Schema
-- ---------------------------------------------------------------------------

ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS display_mode TEXT NOT NULL DEFAULT 'banner',
  ADD COLUMN IF NOT EXISTS target_profile_ids UUID[],
  ADD COLUMN IF NOT EXISTS target_organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS action_label TEXT,
  ADD COLUMN IF NOT EXISTS action_url TEXT,
  ADD COLUMN IF NOT EXISTS published_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  -- A popup must be dismissible or it traps the user; a critical one may not be.
  ADD COLUMN IF NOT EXISTS dismissible BOOLEAN NOT NULL DEFAULT TRUE,
  -- Marquee decoration
  ADD COLUMN IF NOT EXISTS link_url TEXT;

-- `audience` already exists on this table (default 'all'); confirm the value
-- space rather than adding it, so the migration is a true no-op on re-run.
COMMENT ON COLUMN public.announcements.audience IS
  'all | specific (target_profile_ids) | organization (target_organization_id).';

-- Publication window: the table uses `published_at`, so the migration reuses it
-- instead of introducing a competing `starts_at` column.
COMMENT ON COLUMN public.announcements.published_at IS
  'When the announcement becomes visible. NULL or <= now() means live.';

-- ---------------------------------------------------------------------------
-- 2. Constraints
-- ---------------------------------------------------------------------------
-- Kept as separate guarded blocks so a re-run does not fail on an existing
-- constraint (Postgres has no ADD CONSTRAINT IF NOT EXISTS).

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'announcements_display_mode_check') THEN
    ALTER TABLE public.announcements
      ADD CONSTRAINT announcements_display_mode_check
      CHECK (display_mode IN ('banner', 'popup', 'marquee', 'all'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'announcements_audience_check') THEN
    ALTER TABLE public.announcements
      ADD CONSTRAINT announcements_audience_check
      CHECK (audience IN ('all', 'specific', 'organization'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'announcements_priority_check') THEN
    ALTER TABLE public.announcements
      ADD CONSTRAINT announcements_priority_check
      CHECK (priority IN ('low', 'normal', 'high', 'critical'));
  END IF;
END $$;

-- A 'specific' audience must name someone, and an 'organization' audience must
-- name an organization. Without this a mis-targeted announcement is silently
-- delivered to nobody, which looks like a publish failure.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'announcements_target_present_check') THEN
    ALTER TABLE public.announcements
      ADD CONSTRAINT announcements_target_present_check
      CHECK (
        (audience = 'all')
        OR (audience = 'specific' AND target_profile_ids IS NOT NULL AND array_length(target_profile_ids, 1) > 0)
        OR (audience = 'organization' AND target_organization_id IS NOT NULL)
      );
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Indexes
-- ---------------------------------------------------------------------------
-- Member-facing reads filter on is_active + expiry and sort by pinned/recency.
CREATE INDEX IF NOT EXISTS idx_announcements_active_created
  ON public.announcements (is_active, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_announcements_display_mode
  ON public.announcements (display_mode)
  WHERE is_active = TRUE;

-- Direct messages to named members are looked up by membership.
CREATE INDEX IF NOT EXISTS idx_announcements_target_profiles
  ON public.announcements USING GIN (target_profile_ids);

CREATE INDEX IF NOT EXISTS idx_announcements_target_org
  ON public.announcements (target_organization_id)
  WHERE target_organization_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. Notifications: allow the direct-message type
-- ---------------------------------------------------------------------------
-- A direct message is stored as a notification row. The existing type CHECK
-- predates the feature, so inserting one would raise 23514 and the send would
-- fail silently — the same class of bug that made broadcasts appear to work.
-- Recreated with the one extra value; every existing value is preserved.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notifications_type_check') THEN
    ALTER TABLE public.notifications DROP CONSTRAINT notifications_type_check;
  END IF;

  ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type = ANY (ARRAY[
      'transaction', 'savings', 'investment', 'loan', 'referral', 'kyc',
      'system', 'promotion', 'security', 'reminder',
      'payment_proof_approved',
      'direct_message', 'announcement'
    ]));
END $$;

-- ---------------------------------------------------------------------------
-- 5. Row-Level Security
-- ---------------------------------------------------------------------------
-- The API reaches these tables with the service role, which bypasses RLS. RLS
-- exists so a member holding an anon/user token cannot read another member's
-- targeting list or mark someone else's announcement read.

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- The pre-existing `announcements_read_all` policy grants every reader
-- `is_active = true`, and Postgres ORs permissive policies together — so it
-- silently defeated the targeted policy below and let any member read an
-- announcement addressed to somebody else. Verified by test: an excluded member
-- could read a targeted row directly. The targeted policy already covers the
-- `audience = 'all'` case, so dropping the broad one loses nothing.
DROP POLICY IF EXISTS announcements_read_all ON public.announcements;

DROP POLICY IF EXISTS announcements_read_active ON public.announcements;
CREATE POLICY announcements_read_active ON public.announcements
  FOR SELECT
  USING (
    is_active = TRUE
    AND (published_at IS NULL OR published_at <= now())
    AND (expires_at IS NULL OR expires_at > now())
    AND (
      audience = 'all'
      OR (audience = 'specific' AND auth.uid() = ANY(target_profile_ids))
      OR (
        audience = 'organization'
        AND target_organization_id IS NOT NULL
        AND target_organization_id = (
          SELECT p.organization_id FROM public.profiles p WHERE p.id = auth.uid()
        )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Trace the migration
-- ---------------------------------------------------------------------------
COMMENT ON COLUMN public.announcements.display_mode IS
  'How the member app surfaces it: banner | popup | marquee | all.';
COMMENT ON COLUMN public.announcements.audience IS
  'all | specific (target_profile_ids) | organization (target_organization_id).';
COMMENT ON COLUMN public.announcements.dismissible IS
  'FALSE forces a popup the member cannot dismiss (critical notices only).';
