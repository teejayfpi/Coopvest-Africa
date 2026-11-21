-- Migration 070: disburse an approved loan
--
-- The missing step in the loan lifecycle. `POST /loans/:id/approve` sets a loan
-- to 'approved' and stops there. Nothing moves money, and nothing writes the
-- statuses the rest of the system waits for:
--
--   - POST /loans/:loanId/repay only accepts 'active', 'repaying' or 'overdue'
--     (routes/loans.js and wallet_loan_repayment both enforce it), so an
--     approved loan could never be repaid.
--   - loanRecoveryWorker only scans 'active', 'repaying', 'overdue', so an
--     approved loan was never seen, never escalated, and its guarantors were
--     never warned.
--   - loans.disbursed_by exists but nothing ever wrote it.
--
-- The practical result was that the only money that could reach a member was a
-- bank deposit an admin verified by hand, which reduced remaining_balance while
-- leaving the status at 'approved' — a loan that could be partly repaid and
-- never completed.
--
-- This function is that step. Given an approved loan it credits the member's
-- wallet with the principal and moves the loan to 'active', so repayment,
-- arrears escalation and the guarantor notices all start working.
--
-- Not in governanceSchema.js MIGRATIONS, for the same reason as 065/067/068:
-- this creates money in a member's wallet, so it is applied deliberately after
-- sign-off rather than silently by the deploy bootstrap. Until it is applied the
-- endpoint reports that disbursement is unavailable and changes nothing.
--
-- Idempotent: safe to re-run. Applying it twice replaces the function.

CREATE OR REPLACE FUNCTION public.loan_disburse(
  p_loan_id  UUID,
  p_admin_id UUID
)
RETURNS public.loans
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_loan          public.loans;
  v_wallet        public.wallets;
  v_amount        NUMERIC(18,2);
  v_wallet_before NUMERIC(18,2);
  v_wallet_after  NUMERIC(18,2);
  v_now           TIMESTAMPTZ := NOW();
BEGIN
  -- Lock the loan first. Every other money path that touches a loan
  -- (wallet_loan_repayment, loan_settle_from_savings) takes the loan row before
  -- the wallet, so a disbursement racing a repayment serialises here instead of
  -- double-counting the balance.
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Loan not found' USING ERRCODE = '23503';
  END IF;

  -- The guard that makes this safe to call twice. A disbursement is the one
  -- irreversible credit in the loan lifecycle: repeating it would create money
  -- that no repayment is owed against. Only 'approved' qualifies, and the first
  -- successful run moves the status off it.
  IF v_loan.status <> 'approved' THEN
    RAISE EXCEPTION 'Only an approved loan can be disbursed. Current status: %',
      v_loan.status USING ERRCODE = '22023';
  END IF;

  v_amount := round(COALESCE(v_loan.amount, 0), 2);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'Loan amount must be greater than zero' USING ERRCODE = '22023';
  END IF;

  PERFORM public.ensure_wallet_row(v_loan.profile_id);
  SELECT * INTO v_wallet FROM public.wallets
  WHERE profile_id = v_loan.profile_id FOR UPDATE;

  v_wallet_before := COALESCE(v_wallet.balance, 0);
  v_wallet_after  := v_wallet_before + v_amount;

  UPDATE public.wallets
  SET balance = v_wallet_after, last_updated = v_now, updated_at = v_now
  WHERE id = v_wallet.id;

  INSERT INTO public.transactions (
    transaction_id, profile_id, reference, type, category, amount, status,
    description, payment_method, balance_before, balance_after, completed_at,
    loan_id
  ) VALUES (
    'TXN-' || gen_random_uuid(),
    v_loan.profile_id,
    'LND-' || v_loan.loan_id,
    'loan_disbursement',
    'credit',
    v_amount,
    'completed',
    'Loan disbursement for ' || v_loan.loan_id,
    'wallet',
    v_wallet_before,
    v_wallet_after,
    v_now,
    v_loan.id
  );

  -- 'active' rather than 'disbursed': the status check constraint permits
  -- 'disbursed', but every reader that matters — repayment eligibility, the
  -- recovery worker, the dashboard's active book — keys on 'active'. Writing a
  -- status nothing acts on would rebuild the same dead end this fixes.
  UPDATE public.loans
  SET status       = 'active',
      disbursed_by = p_admin_id,
      approved_at  = COALESCE(approved_at, v_now),
      updated_at   = v_now
  WHERE id = p_loan_id
  RETURNING * INTO v_loan;

  RETURN v_loan;
END;
$$;

COMMENT ON FUNCTION public.loan_disburse(UUID, UUID) IS
  'Credit an approved loan''s principal to the member''s wallet and move the loan to active. Only ''approved'' qualifies, so it cannot be run twice.';
