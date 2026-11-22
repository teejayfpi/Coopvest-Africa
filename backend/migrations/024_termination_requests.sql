-- Create the termination_requests table, which the member-facing
-- (/api/v1/termination) and admin (/api/admin/termination) routes depend on.
-- The table was referenced by migration 016 but never actually created, so
-- the admin Terminations page failed with "table does not exist".

CREATE TABLE IF NOT EXISTS public.termination_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT,
  bank_account_id UUID,
  confirmation_note TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by UUID,
  reviewed_at TIMESTAMPTZ,
  review_note TEXT,
  confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_termination_requests_profile ON public.termination_requests(profile_id);
CREATE INDEX IF NOT EXISTS idx_termination_requests_status ON public.termination_requests(status);
