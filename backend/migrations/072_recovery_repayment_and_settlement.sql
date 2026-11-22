-- Migration 072: let a loan in recovery be repaid, and close it when paid off
--
-- Two defects in `wallet_loan_repayment`, both of which strand a defaulted
-- member with no way out.
--
-- 1. `in_recovery` was not an accepted status.
--
--    `loanRecoveryWorker` stage 3 sets `status = 'in_recovery'` on the third
--    consecutive missed month. The RPC then rejected every repayment with
--    "Repayment is only accepted for active, repaying or overdue loans", and
--    nothing anywhere moves a loan out of `in_recovery`. So the member could
--    not pay, and the loan could never be cleared:
--
--      month 2 -> fine + is_flagged = true  -> login blocked (auth.js)
--      month 3 -> status = 'in_recovery'    -> repayment rejected here
--      ...nothing can break the cycle.
--
--    Recovery is a collections *stage*, not a bar on payment. Taking a
--    payment is the outcome recovery wants, so `in_recovery` is now accepted.
--
-- 2. A fully repaid loan was never marked `completed`.
--
--    `remaining_balance` reached 0 but the status stayed `active`, so the loan
--    kept appearing in the active book and `loanRecoveryWorker` kept escalating
--    it: a settled loan would eventually be fined and sent to recovery. Only
--    the admin payment-proof path ever set `completed`.
--
--    Reaching zero now closes the loan, and the member's default flag is
--    cleared in the same statement — previously the flag was only ever lifted
--    in the payment-proof verification path, so a member who repaid from their
--    wallet stayed locked out of login even after settling.
--
-- Idempotent: safe to re-run.

CREATE OR REPLACE FUNCTION public.wallet_loan_repayment(
  p_loan_id    UUID,
  p_profile_id UUID,
  p_amount     NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_loan          public.loans;
  v_wallet        public.wallets;
  v_amount        NUMERIC(18,2);
  v_remaining     NUMERIC(18,2);
  v_new_remaining NUMERIC(18,2);
  v_wallet_after  NUMERIC(18,2);
  v_now           TIMESTAMPTZ := NOW();
  v_repayment     public.loan_repayments;
  v_txn           public.transactions;
  v_principal     NUMERIC(18,2);
  v_interest      NUMERIC(18,2);
  v_new_status    TEXT;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero' USING ERRCODE = '22023';
  END IF;
  v_amount := round(p_amount, 2);

  -- Lock the loan first, then the wallet. Every caller takes them in this
  -- order, so a concurrent repayment of the same loan serialises here rather
  -- than reading a stale remaining_balance.
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Loan not found' USING ERRCODE = '23503';
  END IF;
  IF v_loan.profile_id IS DISTINCT FROM p_profile_id THEN
    RAISE EXCEPTION 'This loan does not belong to the current member' USING ERRCODE = '42501';
  END IF;
  -- `in_recovery` is deliberately accepted: it is a collections stage, and
  -- refusing payment from a loan in recovery traps the member (see header).
  IF v_loan.status NOT IN ('active', 'repaying', 'overdue', 'in_recovery') THEN
    RAISE EXCEPTION 'Repayment is only accepted for active, repaying, overdue or in-recovery loans. Current status: %',
      v_loan.status USING ERRCODE = '22023';
  END IF;

  v_remaining := COALESCE(v_loan.remaining_balance, v_loan.total_repayment, 0);

  -- The whole point of this function. The old code clamped the recorded balance
  -- to zero and kept the difference, so an overpayment quietly took money that
  -- was never applied to the loan.
  IF v_amount > v_remaining THEN
    RAISE EXCEPTION 'Repayment of % exceeds the outstanding loan balance of %',
      v_amount, v_remaining USING ERRCODE = '22023';
  END IF;

  PERFORM public.ensure_wallet_row(p_profile_id);
  SELECT * INTO v_wallet FROM public.wallets
  WHERE profile_id = p_profile_id FOR UPDATE;

  IF COALESCE(v_wallet.balance, 0) < v_amount THEN
    RAISE EXCEPTION 'Insufficient wallet balance for this repayment' USING ERRCODE = '22023';
  END IF;

  -- Same helper the principal_repaid trigger falls back to, so the row and the
  -- loan agree. Interest is the remainder; the two always sum to v_amount.
  v_principal := public.split_repayment_principal(
    v_amount,
    COALESCE(v_loan.original_principal, v_loan.amount),
    v_loan.total_repayment
  );
  v_interest := v_amount - v_principal;

  v_new_remaining := v_remaining - v_amount;
  v_wallet_after  := COALESCE(v_wallet.balance, 0) - v_amount;
  -- A settled loan is closed here, so it leaves the active book and stops
  -- escalating through the recovery worker.
  v_new_status := CASE WHEN v_new_remaining <= 0 THEN 'completed' ELSE v_loan.status END;

  UPDATE public.wallets
  SET balance = v_wallet_after, last_updated = v_now, updated_at = v_now
  WHERE id = v_wallet.id;

  INSERT INTO public.transactions (
    transaction_id, profile_id, reference, type, category, amount, status,
    description, payment_method, balance_before, balance_after, completed_at,
    loan_id
  ) VALUES (
    'TXN-' || gen_random_uuid(),
    p_profile_id,
    'TXN-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || floor(random() * 10000)::text,
    'loan_repayment',
    'debit',
    v_amount,
    'completed',
    'Loan repayment for ' || COALESCE(v_loan.loan_id, v_loan.id::text),
    'wallet',
    COALESCE(v_wallet.balance, 0),
    v_wallet_after,
    v_now,
    p_loan_id
  ) RETURNING * INTO v_txn;

  UPDATE public.loans
  SET remaining_balance = v_new_remaining,
      status            = v_new_status,
      updated_at        = v_now
  WHERE id = p_loan_id;

  INSERT INTO public.loan_repayments (
    loan_id, profile_id, amount, principal_component, interest_component,
    status, paid_at, reference
  ) VALUES (
    p_loan_id, p_profile_id, v_amount, v_principal, v_interest,
    'paid', v_now, v_txn.id
  ) RETURNING * INTO v_repayment;

  -- Clear the Policy default flag once this member has no loan left in
  -- arrears or recovery. Without this, settling from the wallet left the
  -- member locked out of login indefinitely.
  IF v_new_status = 'completed' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.loans
      WHERE profile_id = p_profile_id
        AND status IN ('overdue', 'defaulted', 'in_recovery')
    ) THEN
      UPDATE public.profiles
      SET is_flagged = false, flag_reason = NULL
      WHERE id = p_profile_id
        AND flag_reason = 'loan_default';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'remaining_balance', v_new_remaining,
    'wallet_balance', v_wallet_after,
    'principal_component', v_principal,
    'interest_component', v_interest,
    'loan_status', v_new_status,
    'repayment', to_jsonb(v_repayment),
    'transaction', to_jsonb(v_txn)
  );
END;
$$;
