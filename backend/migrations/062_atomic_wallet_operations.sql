-- ---------------------------------------------------------------------------
-- 062: atomic wallet operations
-- ---------------------------------------------------------------------------
-- Transfers and wallet loan repayments were written as several independent
-- statements from the application. Three problems followed:
--
--   * A transfer debited the sender, then credited the recipient in a separate
--     call. If the second call failed, the debit stayed and the credit never
--     happened — money left one balance and did not arrive in the other.
--   * `adjustBalance` read the balance, computed the new value in JavaScript,
--     and wrote it back. Two requests overlapping that window both read the
--     same starting balance, so one write was lost.
--   * A wallet loan repayment checked only the wallet balance, never the loan's
--     remaining balance, and then clamped the recorded balance with
--     `Math.max(0, ...)`. A member could be debited the full amount while the
--     loan absorbed only part of it.
--
-- Both operations now run as one function, so they take effect entirely or not
-- at all, and each reads its balance under a row lock.
--
-- EXECUTE is revoked from anon and authenticated: these move money without
-- consulting `auth.uid()`, so they must only be reachable with the service
-- role, which is what the backend uses. Leaving them executable by a signed-in
-- member would be a worse hole than the one being closed.

-- ---------------------------------------------------------------------------
-- Shared: a wallet for a profile, created on first use
-- ---------------------------------------------------------------------------
-- Mirrors `ensureWallet` in wallet.js, including its 'active' default.
CREATE OR REPLACE FUNCTION public.ensure_wallet_row(p_profile_id UUID)
RETURNS public.wallets AS $$
DECLARE
  v_wallet public.wallets;
BEGIN
  SELECT * INTO v_wallet FROM public.wallets WHERE profile_id = p_profile_id;
  IF FOUND THEN
    RETURN v_wallet;
  END IF;

  INSERT INTO public.wallets (profile_id, balance, currency)
  VALUES (p_profile_id, 0, 'NGN')
  ON CONFLICT (profile_id) DO NOTHING
  RETURNING * INTO v_wallet;

  -- Another session inserted it between the SELECT and the INSERT.
  IF v_wallet IS NULL THEN
    SELECT * INTO v_wallet FROM public.wallets WHERE profile_id = p_profile_id;
  END IF;

  RETURN v_wallet;
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 1. Transfer between two members' wallets
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.wallet_transfer(
  p_from_profile_id UUID,
  p_to_user_ref     TEXT,      -- recipient profiles.user_id or profiles.id
  p_amount          NUMERIC,
  p_description     TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_sender_wallet    public.wallets;
  v_recipient_wallet public.wallets;
  v_recipient        RECORD;
  v_sender           RECORD;
  v_amount           NUMERIC(18,2);
  v_ref              TEXT;
  v_now              TIMESTAMPTZ := NOW();
  v_sender_after     NUMERIC(18,2);
  v_recipient_after  NUMERIC(18,2);
  v_sender_txn       public.transactions;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero' USING ERRCODE = '22023';
  END IF;
  v_amount := round(p_amount, 2);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'Amount is below the smallest transferable unit' USING ERRCODE = '22023';
  END IF;
  IF v_amount > 100000000 THEN
    RAISE EXCEPTION 'Amount exceeds the maximum of 100,000,000' USING ERRCODE = '22023';
  END IF;

  SELECT id, name, user_id INTO v_recipient
  FROM public.profiles
  WHERE user_id = p_to_user_ref OR id::text = p_to_user_ref
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Recipient not found' USING ERRCODE = '23503';
  END IF;
  IF v_recipient.id = p_from_profile_id THEN
    RAISE EXCEPTION 'Cannot transfer to yourself' USING ERRCODE = '22023';
  END IF;

  SELECT id, name, user_id INTO v_sender
  FROM public.profiles WHERE id = p_from_profile_id;

  PERFORM public.ensure_wallet_row(p_from_profile_id);
  PERFORM public.ensure_wallet_row(v_recipient.id);

  -- Lock both wallet rows in one statement, ordered by id. Locking in a fixed
  -- order means two transfers in opposite directions cannot deadlock.
  PERFORM 1 FROM public.wallets
  WHERE profile_id IN (p_from_profile_id, v_recipient.id)
  ORDER BY id
  FOR UPDATE;

  SELECT * INTO v_sender_wallet
  FROM public.wallets WHERE profile_id = p_from_profile_id;
  SELECT * INTO v_recipient_wallet
  FROM public.wallets WHERE profile_id = v_recipient.id;

  IF v_sender_wallet.status <> 'active' THEN
    RAISE EXCEPTION 'Your wallet is %; transfers are blocked until it is active',
      v_sender_wallet.status USING ERRCODE = '22023';
  END IF;
  IF v_recipient_wallet.status <> 'active' THEN
    RAISE EXCEPTION 'The recipient wallet is %; transfers to it are blocked',
      v_recipient_wallet.status USING ERRCODE = '22023';
  END IF;

  IF COALESCE(v_sender_wallet.balance, 0) < v_amount THEN
    RAISE EXCEPTION 'Insufficient wallet balance' USING ERRCODE = '22023';
  END IF;

  v_sender_after    := COALESCE(v_sender_wallet.balance, 0) - v_amount;
  v_recipient_after := COALESCE(v_recipient_wallet.balance, 0) + v_amount;
  v_ref             := 'TRF-' || to_char(v_now, 'YYYYMMDDHH24MISSMS')
                       || '-' || floor(random() * 10000)::text;

  UPDATE public.wallets
  SET balance = v_sender_after, last_updated = v_now, updated_at = v_now
  WHERE id = v_sender_wallet.id;

  UPDATE public.wallets
  SET balance = v_recipient_after, last_updated = v_now, updated_at = v_now
  WHERE id = v_recipient_wallet.id;

  INSERT INTO public.transactions (
    transaction_id, profile_id, reference, type, category, amount, status,
    description, payment_method, balance_before, balance_after, completed_at,
    metadata
  ) VALUES (
    'TXN-' || gen_random_uuid(),
    p_from_profile_id,
    v_ref,
    'transfer_out',
    'debit',
    v_amount,
    'completed',
    COALESCE(p_description, 'Transfer to ' || COALESCE(v_recipient.name, v_recipient.user_id)),
    'wallet',
    COALESCE(v_sender_wallet.balance, 0),
    v_sender_after,
    v_now,
    jsonb_build_object('counterparty_id', v_recipient.id)
  ) RETURNING * INTO v_sender_txn;

  INSERT INTO public.transactions (
    transaction_id, profile_id, reference, type, category, amount, status,
    description, payment_method, balance_before, balance_after, completed_at,
    metadata
  ) VALUES (
    'TXN-' || gen_random_uuid(),
    v_recipient.id,
    v_ref,
    'transfer_in',
    'credit',
    v_amount,
    'completed',
    COALESCE(p_description, 'Transfer from ' || COALESCE(v_sender.name, v_sender.user_id)),
    'wallet',
    COALESCE(v_recipient_wallet.balance, 0),
    v_recipient_after,
    v_now,
    jsonb_build_object('counterparty_id', p_from_profile_id)
  );

  RETURN jsonb_build_object(
    'success', true,
    'reference', v_ref,
    'amount', v_amount,
    'sender_balance', v_sender_after,
    'recipient_id', v_recipient.id,
    'transaction', to_jsonb(v_sender_txn)
  );
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 2. Loan repayment paid from the wallet
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.wallet_loan_repayment(
  p_loan_id UUID,
  p_profile_id UUID,
  p_amount NUMERIC
)
RETURNS JSONB AS $$
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
    loan_id, profile_id, amount, status, paid_at, reference
  ) VALUES (
    p_loan_id, p_profile_id, v_amount, 'paid', v_now, v_txn.id
  ) RETURNING * INTO v_repayment;

  RETURN jsonb_build_object(
    'success', true,
    'remaining_balance', v_new_remaining,
    'wallet_balance', v_wallet_after,
    'repayment', to_jsonb(v_repayment),
    'transaction', to_jsonb(v_txn)
  );
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 3. Referral bonus: claim one event atomically
-- ---------------------------------------------------------------------------
-- The application read a candidate event and marked it consumed in two steps,
-- so two simultaneous loan applications could both apply the same bonus.
-- `consumed_by_loan_id` also records which loan took it; previously that only
-- reached the audit log, so there was no way to trace the consumption.
ALTER TABLE public.referral_events
  ADD COLUMN IF NOT EXISTS consumed_by_loan_id UUID;

CREATE INDEX IF NOT EXISTS idx_referral_events_unconsumed
  ON public.referral_events (referrer_id, confirmed_at)
  WHERE bonus_consumed = false;

-- ---------------------------------------------------------------------------
-- 5. Savings ↔ wallet movements
-- ---------------------------------------------------------------------------
-- savings.js used the same read-then-write helper (`adjustBalance`,
-- `adjustSavings`) and moved money in two steps, so a deposit debited the
-- wallet and credited savings as separate statements and a withdrawal did the
-- reverse. These carry the same defect the transfer and repayment fixes close,
-- so they are closed here too rather than left as the remaining instance.
CREATE OR REPLACE FUNCTION public.ensure_savings_row(p_profile_id UUID)
RETURNS public.savings AS $$
DECLARE
  v_savings public.savings;
BEGIN
  SELECT * INTO v_savings FROM public.savings WHERE profile_id = p_profile_id;
  IF FOUND THEN
    RETURN v_savings;
  END IF;

  INSERT INTO public.savings (profile_id, balance, currency)
  VALUES (p_profile_id, 0, 'NGN')
  ON CONFLICT (profile_id) DO NOTHING
  RETURNING * INTO v_savings;

  IF v_savings IS NULL THEN
    SELECT * INTO v_savings FROM public.savings WHERE profile_id = p_profile_id;
  END IF;

  RETURN v_savings;
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- direction: 'deposit' moves wallet → savings, 'withdraw' moves savings → wallet.
CREATE OR REPLACE FUNCTION public.savings_move(
  p_profile_id UUID,
  p_amount     NUMERIC,
  p_direction  TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_wallet   public.wallets;
  v_savings  public.savings;
  v_amount   NUMERIC(18,2);
  v_now      TIMESTAMPTZ := NOW();
  v_wallet_after  NUMERIC(18,2);
  v_savings_after NUMERIC(18,2);
  v_txn      public.transactions;
BEGIN
  IF p_direction NOT IN ('deposit', 'withdraw') THEN
    RAISE EXCEPTION 'Direction must be deposit or withdraw' USING ERRCODE = '22023';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero' USING ERRCODE = '22023';
  END IF;
  v_amount := round(p_amount, 2);

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
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 6. Admin deposit verification
-- ---------------------------------------------------------------------------
-- Both admin deposit-verify paths credited the wallet with a read-then-write
-- (`ensureWallet` then `balance + amount`) and then updated the transaction and
-- the request as separate statements. Two admins verifying the same request at
-- once both passed the `status = 'pending'` check and both credited it, and a
-- failure between the wallet write and the request update left the money
-- credited with the request still pending — so it could be credited again.
-- This function locks the request, so the status check and the credit are one
-- indivisible step.
CREATE OR REPLACE FUNCTION public.verify_deposit_request(
  p_deposit_id UUID,
  p_admin_id   UUID,
  p_notes      TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_deposit public.deposit_requests;
  v_wallet  public.wallets;
  v_amount  NUMERIC(18,2);
  v_now     TIMESTAMPTZ := NOW();
  v_before  NUMERIC(18,2);
  v_after   NUMERIC(18,2);
BEGIN
  -- The row lock is what makes the status check authoritative: a second caller
  -- blocks here until the first commits, then sees status <> 'pending'.
  SELECT * INTO v_deposit
    FROM public.deposit_requests WHERE id = p_deposit_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deposit request not found' USING ERRCODE = '23503';
  END IF;
  IF v_deposit.status <> 'pending' THEN
    RAISE EXCEPTION 'Deposit already %; cannot verify', v_deposit.status USING ERRCODE = '22023';
  END IF;

  v_amount := round(COALESCE(v_deposit.amount, 0), 2);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'Deposit amount must be greater than zero' USING ERRCODE = '22023';
  END IF;

  PERFORM public.ensure_wallet_row(v_deposit.profile_id);
  SELECT * INTO v_wallet FROM public.wallets WHERE profile_id = v_deposit.profile_id FOR UPDATE;
  IF v_wallet.status <> 'active' THEN
    RAISE EXCEPTION 'This wallet is %; it cannot be credited', v_wallet.status USING ERRCODE = '22023';
  END IF;

  v_before := COALESCE(v_wallet.balance, 0);
  v_after  := v_before + v_amount;

  UPDATE public.wallets
     SET balance = v_after, last_updated = v_now, updated_at = v_now
   WHERE id = v_wallet.id;

  IF v_deposit.transaction_id IS NOT NULL THEN
    UPDATE public.transactions
       SET status = 'completed',
           completed_at = v_now,
           balance_before = v_before,
           balance_after = v_after,
           metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
             'verified_by', p_admin_id,
             'verified_at', v_now,
             'deposit_request_id', p_deposit_id)
     WHERE id = v_deposit.transaction_id;
  END IF;

  -- COALESCE keeps any notes already on the request; the previous version
  -- wrote `notes || null` and so erased them on a re-verify.
  UPDATE public.deposit_requests
     SET status = 'verified',
         verified_by = p_admin_id,
         verified_at = v_now,
         admin_notes = COALESCE(p_notes, admin_notes),
         updated_at = v_now
   WHERE id = p_deposit_id
   RETURNING * INTO v_deposit;

  RETURN jsonb_build_object(
    'success', true,
    'deposit_id', p_deposit_id,
    'profile_id', v_deposit.profile_id,
    'amount', v_amount,
    'balance_before', v_before,
    'balance_after', v_after,
    'deposit', to_jsonb(v_deposit)
  );
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 7. Lock these down to the service role
-- ---------------------------------------------------------------------------
-- A SECURITY DEFINER function runs as its owner, so it must not be callable by
-- a role that has not been authorised for the operation. These do not consult
-- auth.uid() — they trust the profile id they are handed — so anon and
-- authenticated must not reach them at all.
REVOKE ALL ON FUNCTION public.ensure_wallet_row(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.wallet_transfer(UUID, TEXT, NUMERIC, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.wallet_loan_repayment(UUID, UUID, NUMERIC) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ensure_savings_row(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.savings_move(UUID, NUMERIC, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.verify_deposit_request(UUID, UUID, TEXT) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.wallet_transfer(UUID, TEXT, NUMERIC, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.wallet_loan_repayment(UUID, UUID, NUMERIC) TO service_role;
GRANT EXECUTE ON FUNCTION public.savings_move(UUID, NUMERIC, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.verify_deposit_request(UUID, UUID, TEXT) TO service_role;
