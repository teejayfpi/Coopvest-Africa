-- Migration 071: record the principal/interest split on every repayment
--
-- `wallet_loan_repayment` inserted a `loan_repayments` row with only `amount`.
-- `principal_component` and `interest_component` were left NULL, so:
--
--   - `comparative.js` and `comparativeMetrics.js` read those columns and
--     reported zero principal and zero interest for every wallet repayment;
--   - interest income — the cooperative's actual revenue — was unreportable
--     from the ledger;
--   - `trg_sync_loan_principal_repaid` fell back to `split_repayment_principal`
--     to keep `loans.principal_repaid` sane, so the loan row was right while the
--     repayment row it came from was blank.
--
-- The only rows that ever carried a split were those written by the admin
-- manual path (adminApi.js), which takes both figures from the request body.
--
-- The split uses `split_repayment_principal`, the helper the trigger already
-- calls, so there is one definition of how a payment divides. It is a pro-rata
-- share of the whole loan (principal / total_repayment), not a per-instalment
-- amortisation schedule — the schema has no instalment table to amortise
-- against, and inventing one here would disagree with the trigger that has been
-- maintaining `principal_repaid` all along. Recording the same number the
-- trigger would have computed keeps the two in step: the trigger now finds an
-- explicit `principal_component` and stops guessing.
--
-- Nothing else changes: the locking order, the status guard, the overpayment
-- guard and the ledger row are as they were.
--
-- Idempotent: safe to re-run. Applying it twice replaces the function.
--
-- NOT in governanceSchema.js MIGRATIONS, consistent with the other money-path
-- migrations: applied deliberately after sign-off.

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
  IF v_loan.status NOT IN ('active', 'repaying', 'overdue') THEN
    RAISE EXCEPTION 'Repayment is only accepted for active, repaying or overdue loans. Current status: %',
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
  SET remaining_balance = v_new_remaining, updated_at = v_now
  WHERE id = p_loan_id;

  INSERT INTO public.loan_repayments (
    loan_id, profile_id, amount, principal_component, interest_component,
    status, paid_at, reference
  ) VALUES (
    p_loan_id, p_profile_id, v_amount, v_principal, v_interest,
    'paid', v_now, v_txn.id
  ) RETURNING * INTO v_repayment;

  RETURN jsonb_build_object(
    'success', true,
    'remaining_balance', v_new_remaining,
    'wallet_balance', v_wallet_after,
    'principal_component', v_principal,
    'interest_component', v_interest,
    'repayment', to_jsonb(v_repayment),
    'transaction', to_jsonb(v_txn)
  );
END;
$$;

COMMENT ON FUNCTION public.wallet_loan_repayment(UUID, UUID, NUMERIC) IS
  'Debit a wallet repayment against a loan, recording the principal/interest split on the repayment row so interest income is reportable.';
