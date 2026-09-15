-- Fix the payment-proof approval trigger, which has never written a
-- contribution row.
--
-- `handle_payment_proof_approval()` inserts into `contributions`
-- (profile_id, amount, status, contribution_month, payment_proof_id, notes),
-- but `contributions` has neither `payment_proof_id` nor `notes`. The insert
-- therefore raised `column "payment_proof_id" of relation "contributions" does
-- not exist`, and the surrounding
--
--     exception when others then new_contribution_id := null;
--
-- swallowed it. Result: approving a monthly contribution never created the
-- contribution record, `contributions` stayed empty, and members saw
-- "0 contributions" / a 0-month contribution history with loan eligibility and
-- insights falling back to the savings row.
--
-- Additive and idempotent: the columns the trigger already expects, plus an
-- index for the proof→contribution lookup. `payment_proof_id` is where the
-- trigger writes back `new.contribution_id`, so it is the join key between the
-- two tables.

ALTER TABLE contributions
  ADD COLUMN IF NOT EXISTS payment_proof_id UUID
    REFERENCES payment_proofs(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE INDEX IF NOT EXISTS idx_contributions_payment_proof
  ON contributions (payment_proof_id);

-- The trigger also writes payment_proofs.contribution_id back to the proof.
-- That column already exists on this install, but guard it so the migration is
-- safe on a database created before the column was added.
ALTER TABLE payment_proofs
  ADD COLUMN IF NOT EXISTS contribution_id UUID
    REFERENCES contributions(id) ON DELETE SET NULL;
