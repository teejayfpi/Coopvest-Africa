-- Failed / reversed gateway charges.
--
-- Why: a card charge can fail *after* the member's bank has authorised or even
-- debited it (the classic Paystack `charge.failed` with a debit-on-hold, plus
-- `transfer.reversed`). The old flow only understood `charge.success`, so those
-- references sat at `payment_proofs.status = 'pending'` forever: the member saw
-- an indefinite "Payment not confirmed yet", and nothing recorded that money
-- may have left their account.
--
-- This migration adds the missing terminal state and an audit trail so support
-- can tell "never paid" apart from "debited but not credited" — the second is
-- real money that must be credited or reversed, not silently ignored.

-- 1. Allow `failed` alongside the existing proof states. `pending` stays the
--    pre-payment "parked" state; a failed charge is terminal, never credited.
ALTER TABLE public.payment_proofs
  DROP CONSTRAINT IF EXISTS payment_proofs_status_check;
ALTER TABLE public.payment_proofs
  ADD CONSTRAINT payment_proofs_status_check
  CHECK (status = ANY (ARRAY['pending'::text, 'under_review'::text, 'approved'::text, 'rejected'::text, 'failed'::text]));

-- Distinguishes a gateway failure from an admin rejection, which share the
-- rejected_* columns awkwardly. Nullable so existing rows are untouched.
ALTER TABLE public.payment_proofs
  ADD COLUMN IF NOT EXISTS failed_at timestamptz,
  ADD COLUMN IF NOT EXISTS failure_reason text;

-- 2. Audit every gateway failure event. A `charge.failed` can arrive more than
--    once (Paystack retries, and the reconcile sweep may race the webhook), so
--    the reference+event pair is unique: one row per real event.
CREATE TABLE IF NOT EXISTS public.payment_failed_charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reference text NOT NULL,
  amount numeric(14,2),
  currency text DEFAULT 'NGN',
  gateway text NOT NULL DEFAULT 'paystack',
  gateway_status text,          -- charge.failed status: failed | reversed | abandoned
  gateway_message text,         -- Paystack's human-readable reason
  -- True when Paystack's payload indicates the member may already have been
  -- debited (e.g. a reversal, or a failed charge carrying a paid-at marker).
  -- This is the flag that tells support "credit or refund this member".
  possible_debit boolean NOT NULL DEFAULT false,
  needs_followup boolean NOT NULL DEFAULT true,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_note text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT payment_failed_charges_ref_event_key UNIQUE (reference, gateway_status)
);

CREATE INDEX IF NOT EXISTS idx_payment_failed_charges_open
  ON public.payment_failed_charges (needs_followup, created_at DESC)
  WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_payment_failed_charges_profile
  ON public.payment_failed_charges (profile_id, created_at DESC);
