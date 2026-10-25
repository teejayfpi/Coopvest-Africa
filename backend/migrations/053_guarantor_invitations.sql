-- Migration 053: named guarantor invitations with a remind/expire lifecycle
--
-- The loan flow lets a borrower share a QR that any eligible member can scan,
-- and a `loan_guarantors` row is only written when someone consents. That works,
-- but there is nothing to notify, remind, or expire: a borrower cannot name the
-- three people they have in mind, and a guarantee that is never answered just
-- sits there.
--
-- These columns let a borrower *invite* a named guarantor. An invited row is
-- `pending` with a `consent_deadline`; a worker reminds before the deadline and
-- expires the invitation after it, so a stalled loan is visible instead of
-- silently stuck. The QR flow keeps working unchanged — a scan simply moves an
-- existing pending row to `consented`.

ALTER TABLE public.loan_guarantors
  -- Who was invited, when the invite is not yet tied to a known profile.
  ADD COLUMN IF NOT EXISTS guarantor_phone TEXT,
  ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ,
  -- When the invitation lapses if unanswered.
  ADD COLUMN IF NOT EXISTS consent_deadline TIMESTAMPTZ,
  -- Dedup guard so the reminder worker sends at most one nudge per invite.
  ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ,
  -- Set when the invitation is expired by the worker (distinct from a decline).
  ADD COLUMN IF NOT EXISTS expired_at TIMESTAMPTZ;

-- The reminder/expiry worker scans for pending invites by deadline; without this
-- it is a full scan of loan_guarantors every sweep.
CREATE INDEX IF NOT EXISTS idx_loan_guarantors_pending_deadline
  ON public.loan_guarantors(consent_deadline)
  WHERE status = 'pending' AND consent_deadline IS NOT NULL;
