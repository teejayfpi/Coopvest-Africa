-- Migration 065: hold savings against an outstanding loan
--
-- `savings_move(..., 'withdraw')` checked only that the wallet was active and
-- that the savings balance was sufficient. It did not look at the member's
-- loans. A borrower could therefore move their whole savings balance to the
-- wallet and withdraw it, leaving the loan with nothing behind it.
--
-- That contradicts what the app already publishes. `default_recovery_policy`
-- clause 3 tells the member: "Outstanding balances may be recovered from the
-- member's contributions, savings, or dividends held with the cooperative."
-- The published right existed; nothing enforced it. This migration makes the
-- savings part of that sentence true.
--
-- The rule: a withdrawal may not take the savings balance below the total
-- outstanding balance of the member's live loans. Savings above that line
-- remain the member's to withdraw, so a member with a loan and no arrears can
-- still reach their own money. Deposits are never restricted.
--
-- A loan is capped at a multiple of savings (3x-5x, see lib/loanPolicy.js), so
-- savings alone can never cover a default. This lien is not the whole of
-- recovery; it stops the borrower draining what security does exist. It is a
-- deliberate, conservative reading of the published policy - the cooperative
-- holds the savings, the member keeps access to everything above the debt.
--
-- Which loans count. The status vocabulary is the CHECK constraint on
-- public.loans (migration 039): pending | under_review | approved | active |
-- repaying | overdue | defaulted | in_recovery | completed | rejected |
-- cancelled | rolled_over. Only rows carrying live debt count:
--   approved, active, repaying, overdue, defaulted, in_recovery.
-- 'pending' and 'under_review' are excluded on purpose - an application that has
-- not been disbursed must not freeze a member's own savings. 'completed',
-- 'rejected' and 'cancelled' are settled or dead. 'rolled_over' is excluded
-- because a refinance closed that row and the debt moved to the successor loan,
-- which counts in its own right; counting both would double the lien.
--
-- Scope note: the check reads the loan rows in the same statement, taking the
-- loans lock before the wallet and savings locks. `wallet_loan_repayment`
-- already locks loans before the wallet, so this keeps one lock order and
-- cannot deadlock against a repayment. A loan row inserted by a concurrent
-- disbursement is not seen by a snapshot already taken; the window is the
-- microseconds of a single statement, and an admin disbursement is not a
-- race with a member's withdrawal in practice.
--
-- NOT listed in governanceSchema.js MIGRATIONS yet: it changes what members may
-- do with their own money, so it is applied deliberately, after sign-off, not
-- silently by the deploy bootstrap. Add the name to that list to apply it.

CREATE OR REPLACE FUNCTION public.savings_move(
  p_profile_id UUID,
  p_amount     NUMERIC,
  p_direction  TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB AS $function$
DECLARE
  v_wallet   public.wallets;
  v_savings  public.savings;
  v_amount   NUMERIC(18,2);
  v_now      TIMESTAMPTZ := NOW();
  v_wallet_after  NUMERIC(18,2);
  v_savings_after NUMERIC(18,2);
  v_lien     NUMERIC(18,2);
  v_txn      public.transactions;
BEGIN
  IF p_direction NOT IN ('deposit', 'withdraw') THEN
    RAISE EXCEPTION 'Direction must be deposit or withdraw' USING ERRCODE = '22023';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero' USING ERRCODE = '22023';
  END IF;
  v_amount := round(p_amount, 2);

  -- Total the member still owes across live loans. Locked before the wallet and
  -- savings rows, matching wallet_loan_repayment's loans-then-wallet order.
  PERFORM 1
    FROM public.loans
   WHERE profile_id = p_profile_id
     AND status IN ('approved', 'active', 'repaying', 'overdue', 'defaulted', 'in_recovery')
   FOR UPDATE;

  SELECT COALESCE(SUM(COALESCE(remaining_balance, total_repayment, amount, 0)), 0)
    INTO v_lien
    FROM public.loans
   WHERE profile_id = p_profile_id
     AND status IN ('approved', 'active', 'repaying', 'overdue', 'defaulted', 'in_recovery');

  PERFORM public.ensure_wallet_row(p_profile_id);
  PERFORM public.ensure_savings_row(p_profile_id);

  -- Same fixed lock order as wallet_transfer: wallet then savings.
  SELECT * INTO v_wallet  FROM public.wallets WHERE profile_id = p_profile_id FOR UPDATE;
  SELECT * INTO v_savings FROM public.savings WHERE profile_id = p_profile_id FOR UPDATE;

  IF v_wallet.status <> 'active' THEN
    RAISE EXCEPTION 'Your wallet is %; savings movements are blocked until it is active',
      v_wallet.status USING ERRCODE = '22023';
  END IF;

  IF p_direction = 'deposit' THEN
    IF COALESCE(v_wallet.balance, 0) < v_amount THEN
      RAISE EXCEPTION 'Insufficient wallet balance' USING ERRCODE = '22023';
    END IF;
    v_wallet_after  := COALESCE(v_wallet.balance, 0) - v_amount;
    v_savings_after := COALESCE(v_savings.balance, 0) + v_amount;
  ELSE
    IF COALESCE(v_savings.balance, 0) < v_amount THEN
      RAISE EXCEPTION 'Insufficient savings balance' USING ERRCODE = '22023';
    END IF;
    -- Savings below the outstanding loan balance are held. The member may
    -- withdraw everything above it; the wording is the figure they can move.
    IF v_lien > 0 AND (COALESCE(v_savings.balance, 0) - v_amount) < v_lien THEN
      RAISE EXCEPTION
        'Insufficient available savings: % of your % savings is held against your outstanding loan balance. You can withdraw up to % while the loan is unpaid.',
        v_lien, COALESCE(v_savings.balance, 0), GREATEST(COALESCE(v_savings.balance, 0) - v_lien, 0)
        USING ERRCODE = '22023';
    END IF;
    v_wallet_after  := COALESCE(v_wallet.balance, 0) + v_amount;
    v_savings_after := COALESCE(v_savings.balance, 0) - v_amount;
  END IF;

  UPDATE public.wallets
  SET balance = v_wallet_after, last_updated = v_now, updated_at = v_now
  WHERE id = v_wallet.id;

  UPDATE public.savings
  SET balance = v_savings_after, updated_at = v_now
  WHERE id = v_savings.id;

  INSERT INTO public.transactions (
    transaction_id, profile_id, reference, type, category, amount, status,
    description, payment_method, balance_before, balance_after, completed_at
  ) VALUES (
    'TXN-' || gen_random_uuid(),
    p_profile_id,
    'TXN-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || floor(random() * 10000)::text,
    CASE WHEN p_direction = 'deposit' THEN 'savings_deposit' ELSE 'savings_withdrawal' END,
    CASE WHEN p_direction = 'deposit' THEN 'debit' ELSE 'credit' END,
    v_amount,
    'completed',
    COALESCE(p_description, CASE WHEN p_direction = 'deposit' THEN 'Savings deposit' ELSE 'Savings withdrawal' END),
    'wallet',
    COALESCE(v_wallet.balance, 0),
    v_wallet_after,
    v_now
  ) RETURNING * INTO v_txn;

  RETURN jsonb_build_object(
    'success', true,
    'wallet_balance', v_wallet_after,
    'savings_balance', v_savings_after,
    'savings_id', v_savings.id,
    'transaction', to_jsonb(v_txn)
  );
END $function$ LANGUAGE plpgsql SECURITY DEFINER;
