-- Migration 025 (OPTIONAL): allow 'paystack' as a payment_proofs method
--
-- The backend records Paystack deposits with payment_method = 'paystack' when
-- this constraint allows it, and falls back to 'card' (+ metadata.gateway =
-- 'paystack') when it doesn't — so applying this is recommended for cleaner
-- reporting but not required for correctness.

ALTER TABLE public.payment_proofs
  DROP CONSTRAINT IF EXISTS payment_proofs_payment_method_check;
ALTER TABLE public.payment_proofs
  ADD CONSTRAINT payment_proofs_payment_method_check
  CHECK (payment_method IN ('bank_transfer', 'ussd', 'pos', 'cash_deposit', 'card', 'paystack'));
