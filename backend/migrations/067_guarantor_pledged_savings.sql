-- Migration 067: hold a guarantor's savings against the loan they backed
--
-- Migration 065 made a borrower's savings answer for their own loan. It did not
-- touch guarantees. So a member could consent to guarantee a ₦300,000 loan, and
-- the same afternoon move every naira of savings to their wallet and withdraw
-- it. The guarantee recorded *who* stood behind the loan and never *how much*
-- they were committing — `loan_guarantors` had no amount column at all.
--
-- That is the gap this closes. On consent, the guarantor's share of the loan is
-- written to `loan_guarantors.pledged_amount`, and `savings_move` holds that
-- amount in the same way it already holds a borrower's own debt: the money
-- stays in the member's savings and keeps earning, it simply cannot be
-- withdrawn while the loan is unpaid.
--
-- Why a pledge and not a cap on the loan
-- --------------------------------------
-- Refusing any loan larger than a guarantor's savings would be trivially
-- gamed: a guarantor who wanted to help would withdraw savings first to look
-- poor. A pledge is recorded at consent, from the balance at that moment, so
-- the security exists before the member can move it.
--
-- Existing guarantors
-- -------------------
-- `pledged_amount` is NULL for every guarantee recorded before this migration,
-- and NULL means "no pledge": those rows add nothing to the lien. Backfilling a
-- lien onto loans that are already running would freeze savings that members
-- are entitled to, without notice. New consents set the column; the loan
-- approval path refuses an under-covered loan in the application layer. No
-- existing member's savings are frozen by applying this.
--
-- Status list matches migration 065 exactly. If the two lists ever diverge, a
-- member is shown one coverage figure and the database enforces another.
--
-- Idempotent: safe to re-run.
--
-- NOT listed in governanceSchema.js MIGRATIONS: like 065 it changes what
-- members may do with their own money, so it is applied deliberately after
-- sign-off rather than silently by the deploy bootstrap.

-- ---------------------------------------------------------------------------
-- 1. The pledge column
-- ---------------------------------------------------------------------------
ALTER TABLE public.loan_guarantors
  ADD COLUMN IF NOT EXISTS pledged_amount NUMERIC(18,2);

COMMENT ON COLUMN public.loan_guarantors.pledged_amount IS
  'Savings held against this guarantee. NULL for guarantees recorded before migration 067, which carry no lien.';

-- A pledge is a hold, never a negative amount.
ALTER TABLE public.loan_guarantors
  DROP CONSTRAINT IF EXISTS loan_guarantors_pledged_amount_non_negative;
ALTER TABLE public.loan_guarantors
  ADD CONSTRAINT loan_guarantors_pledged_amount_non_negative
  CHECK (pledged_amount IS NULL OR pledged_amount >= 0);

-- ---------------------------------------------------------------------------
-- 2. savings_move: count pledges as well as the member's own loans
-- ---------------------------------------------------------------------------
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
  v_loan_lien     NUMERIC(18,2);
  v_pledge_lien   NUMERIC(18,2);
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

  -- Lock the member's own loans first, matching wallet_loan_repayment's
  -- loans-then-wallet order, then the guarantees they have consented to.
  PERFORM 1
    FROM public.loans
   WHERE profile_id = p_profile_id
     AND status IN ('approved', 'active', 'repaying', 'overdue', 'defaulted', 'in_recovery')
   FOR UPDATE;

  SELECT COALESCE(SUM(COALESCE(remaining_balance, total_repayment, amount, 0)), 0)
    INTO v_loan_lien
    FROM public.loans
   WHERE profile_id = p_profile_id
     AND status IN ('approved', 'active', 'repaying', 'overdue', 'defaulted', 'in_recovery');

  -- Guarantees this member has consented to, on loans that still carry debt.
  -- A NULL pledged_amount is a pre-067 guarantee and adds nothing.
  PERFORM 1
    FROM public.loan_guarantors lg
    JOIN public.loans l ON l.id = lg.loan_id
   WHERE COALESCE(lg.guarantor_profile_id, lg.guarantor_id) = p_profile_id
     AND lg.status = 'consented'
     AND l.status IN ('approved', 'active', 'repaying', 'overdue', 'defaulted', 'in_recovery')
   FOR UPDATE OF lg;

  SELECT COALESCE(SUM(lg.pledged_amount), 0)
    INTO v_pledge_lien
    FROM public.loan_guarantors lg
    JOIN public.loans l ON l.id = lg.loan_id
   WHERE COALESCE(lg.guarantor_profile_id, lg.guarantor_id) = p_profile_id
     AND lg.status = 'consented'
     AND lg.pledged_amount IS NOT NULL
     AND l.status IN ('approved', 'active', 'repaying', 'overdue', 'defaulted', 'in_recovery');

  v_lien := COALESCE(v_loan_lien, 0) + COALESCE(v_pledge_lien, 0);

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
    -- Savings below the held total are not available. The wording reports the
    -- figure the member can actually move, which is what they will act on.
    IF v_lien > 0 AND (COALESCE(v_savings.balance, 0) - v_amount) < v_lien THEN
      RAISE EXCEPTION
        'Insufficient available savings: % is held against your outstanding loans and guarantees. Of your % savings, you can withdraw up to %.',
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
