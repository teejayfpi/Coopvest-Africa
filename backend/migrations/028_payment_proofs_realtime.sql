-- 028: Enable Supabase Realtime for payment_proofs
--
-- The admin dashboard's Payment Proofs page (+ wallet/ledger views) subscribe
-- to postgres_changes on this table so Paystack instant-approvals appear
-- immediately (no manual refresh). For UPDATE payloads to include the changed
-- columns (status → approved, approved_by, etc., we also need REPLICA
-- IDENTITY FULL.

-- Make sure the table is published for realtime.（Safe to re-run: checks
-- whether it's already in the publication before adding..
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'payment_proofs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_proofs;
  END IF;
END $$;

-- Deliver full change payloads on UPDATE so the UI can react to the status flip
-- (pending → approved) without an extra fetch..
ALTER TABLE public.payment_proofs REPLICA IDENTITY FULL;

-- Optional but recommended: same for deposit_requests so Deposit Verification
-- UPDATE events (verify/reject) also carry full rows if you ever need them..
ALTER TABLE public.deposit_requests REPLICA IDENTITY FULL;