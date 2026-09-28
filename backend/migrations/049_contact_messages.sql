-- Migration 049: store website contact-form enquiries so admins can reply
--
-- WHY THIS EXISTS
-- ---------------
-- The marketing site's contact form (`coopvest-website`, api/contact.js) only
-- emailed the enquiry to a shared Gmail inbox. Nothing was recorded, so an
-- enquiry could not be seen, assigned or answered from the admin dashboard, and
-- if no mail provider was configured the handler answered 503 and the message
-- was lost entirely (verified: the live endpoint returned 503). Support tickets
-- raised from the mobile app already have a durable queue admins work from;
-- website enquiries had none.
--
-- This table is that queue. The site posts to the backend, the backend records
-- the enquiry here, and the admin dashboard reads and replies to it.
--
-- Unlike `tickets`, a `contact_messages` row has no `profile_id`: the enquirer
-- is usually not a signed-in member. They are identified by the name, email and
-- phone they typed. That is also why the reply is an email rather than an in-app
-- message — there is no app account to notify.
--
-- Additive and idempotent; safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. The enquiry queue
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.contact_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Human reference shown to the enquirer and used by an admin to look it up.
  reference TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  topic TEXT NOT NULL,
  message TEXT NOT NULL,
  -- The page the enquiry came from ('website'); kept so other surfaces (e.g. a
  -- partner landing page) can reuse this table without colliding.
  source TEXT NOT NULL DEFAULT 'website',
  status TEXT NOT NULL DEFAULT 'new'
    CHECK (status IN ('new', 'in_progress', 'replied', 'closed')),
  assigned_staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  -- The most recent reply. Replies are emailed, not threaded, so the body and
  -- the timestamp of the last one are what the dashboard needs to show.
  reply_body TEXT,
  replied_at TIMESTAMPTZ,
  replied_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  -- Request provenance for abuse review. The enquirer's IP is personal data,
  -- so the table is service-role only (see RLS below).
  ip_address TEXT,
  user_agent TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contact_messages_status
  ON public.contact_messages(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contact_messages_created
  ON public.contact_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contact_messages_email
  ON public.contact_messages(lower(email));

COMMENT ON TABLE public.contact_messages IS
  'Website contact-form enquiries. Written by the public /api/contact ingest endpoint and read/replied to by the admin dashboard. No profile_id: the enquirer is normally not a member.';

-- ---------------------------------------------------------------------------
-- 2. Row Level Security
-- ---------------------------------------------------------------------------
-- This table holds personal data (name, email, phone, IP) from people who have
-- no account, so it must never be readable through PostgREST with the public
-- anon key. RLS is enabled with no anon/authenticated policy at all: only the
-- backend's service-role key reaches it, exactly as migration 047 did for the
-- member tables. The explicit service_role policy makes that intent visible in
-- the schema instead of relying on the implicit service-role bypass.

ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS contact_messages_service ON public.contact_messages;
CREATE POLICY contact_messages_service ON public.contact_messages
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Refreshing the PostgREST schema cache is what makes the new table resolvable
-- by supabase-js; without it the API keeps answering "Could not find the table
-- 'public.contact_messages' in the schema cache" until the next restart.
NOTIFY pgrst, 'reload schema';
