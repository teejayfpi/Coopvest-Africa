-- Migration 036: Atomic manual deposit recording
--
-- Why this exists
-- ---------------
-- The admin dashboard's Manual Deposits page recorded member money by writing
-- to the database DIRECTLY FROM THE BROWSER using the anon key plus the admin's
-- session. I verified against production that an authenticated admin can INSERT
-- into `transactions` through PostgREST (the request reached the table and
-- failed only on a NOT NULL column, not on authorisation), so the writes do land.
--
-- That path had several defects that matter for member money:
--
--   1. It was five separate round-trips with no transaction boundary:
--      transaction → deposit_request → read wallet → update wallet →
--      update transaction → audit_log. A failure part-way through leaves a
--      transaction with no wallet credit, or a credit with no audit record.
--   2. The new balance was computed IN THE BROWSER
--      (`newBalance = balanceBefore + amount`). Two admins recording deposits
--      at the same time read the same starting balance and one credit is lost.
--   3. It bypassed every server-side check — no activation-gate validation, no
--      amount validation the server controls, no idempotency.
--   4. It wrote to `audit_logs` from the client, so the audit trail for a
--      manual money movement was itself client-authored.
--
-- This migration adds a single PL/pgSQL function that performs the whole
-- operation in one transaction, with the balance computed server-side under a
-- row lock, and unique-reference protection against double-posting. The
-- dashboard is reduced to one call.

-- ---------------------------------------------------------------------------
-- Repair the allocation_type CHECK constraints
-- ---------------------------------------------------------------------------
-- Production carries TWO CHECK constraints on `deposit_requests.allocation_type`
-- that must both hold, so the effective allowed set is their intersection:
--
--   allocation_type_check                 -> monthly_contribution, loan_repayment,
--                                            fine, fee, registration_fee, mixed
--   deposit_requests_allocation_type_check -> monthly_contribution, loan_repayment,
--                                            mixed
--
-- Migration 020 created the narrow one (as an unnamed CHECK) and migration 021
-- tried to replace it, but its lookup used `pg_get_constraintdef(oid) LIKE
-- '%allocation_type%IN%'` — Postgres normalises `IN (...)` to `= ANY (ARRAY[...])`,
-- so the pattern never matched, the old constraint was never dropped, and a
-- second wider one was added alongside it.
--
-- The consequence is live: `routes/wallet.js` derives `paymentAlloc` from the
-- member's chosen allocation and can emit 'fine', 'fee' or 'registration_fee'.
-- Those are rejected by the narrow constraint, and because that insert sits
-- inside a `try/catch` marked non-fatal, the failure is silent — the debit
-- transaction is created but the `deposit_requests` row an admin needs in order
-- to verify it is not.
--
-- This also blocks `record_manual_deposit()` from recording an entrance fee.
--
-- Drop every allocation_type CHECK and add one correct, validated constraint.

DO $$
DECLARE
  v_conname TEXT;
BEGIN
  FOR v_conname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.deposit_requests'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%allocation_type%'
  LOOP
    EXECUTE format('ALTER TABLE public.deposit_requests DROP CONSTRAINT %I', v_conname);
    RAISE NOTICE 'dropped constraint %', v_conname;
  END LOOP;
END $$;

ALTER TABLE public.deposit_requests
  ADD CONSTRAINT deposit_requests_allocation_type_final
  CHECK (allocation_type IN (
    'monthly_contribution',
    'loan_repayment',
    'fine',
    'fee',
    'registration_fee',
    'mixed'
  ));

COMMENT ON CONSTRAINT deposit_requests_allocation_type_final ON public.deposit_requests IS
  'Single authoritative allocation_type constraint. Replaces the narrow migration-020 CHECK that migration 021 failed to drop, which silently blocked fine/fee/registration_fee allocations.';

-- ---------------------------------------------------------------------------
-- Deposit type semantics
-- ---------------------------------------------------------------------------
-- The page offered six deposit types and credited the member's wallet for ALL
-- of them. That is wrong for the two that are Coopvest income rather than member
-- balance:
--
--   Savings Contribution  → member's money      → credits wallet + savings
--   Special Contribution  → member's money      → credits wallet + savings
--   Adjustment (Credit)   → admin correction    → credits wallet
--   Refund                → money to the member → credits wallet
--   Monthly Levy          → Coopvest income     → does NOT credit the member
--   Entrance Fee          → Coopvest income     → does NOT credit the member,
--                                                 and settles registration_fee_paid
--
-- Crediting a member's wallet for a levy or an entrance fee would create member
-- balance out of nothing while also recording the fee as received. The function
-- below therefore distinguishes them, and returns which treatment it applied so
-- the UI can state it.

CREATE OR REPLACE FUNCTION public.manual_deposit_credits_member_balance(p_deposit_type TEXT)
RETURNS BOOLEAN AS $$
  SELECT COALESCE(p_deposit_type, 'savings') IN
    ('savings', 'special', 'adjustment', 'refund');
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION public.manual_deposit_credits_member_balance(TEXT) IS
  'True when a manual deposit type increases the member''s balance. Levy and entrance_fee are Coopvest income and must not inflate member funds.';

-- ---------------------------------------------------------------------------
-- The atomic recorder
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_manual_deposit(
  p_profile_id     UUID,
  p_amount         NUMERIC,
  p_deposit_type   TEXT,
  p_payment_method TEXT,
  p_reference      TEXT,
  p_description    TEXT,
  p_admin_id       UUID
)
RETURNS JSONB AS $$
DECLARE
  v_profile      RECORD;
  v_wallet       RECORD;
  v_txn_id       UUID;
  v_deposit_id   UUID;
  v_balance_before NUMERIC(18,2) := 0;
  v_balance_after  NUMERIC(18,2) := 0;
  v_credits_member BOOLEAN;
  v_txn_no       TEXT;
  v_type_label   TEXT;
  v_now          TIMESTAMPTZ := NOW();
BEGIN
  -- ── Validate input ────────────────────────────────────────────────────────
  IF p_profile_id IS NULL THEN
    RAISE EXCEPTION 'A member must be selected' USING ERRCODE = '22023';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero' USING ERRCODE = '22023';
  END IF;
  -- Matches the dashboard's ceiling, so an API caller cannot exceed what the UI
  -- allows and silently bypass a control the admin was held to.
  IF p_amount > 100000000 THEN
    RAISE EXCEPTION 'Amount exceeds the maximum of 100,000,000' USING ERRCODE = '22023';
  END IF;
  IF p_reference IS NULL OR length(btrim(p_reference)) < 3 THEN
    RAISE EXCEPTION 'A reference of at least 3 characters is required' USING ERRCODE = '22023';
  END IF;
  IF p_deposit_type IS NULL OR p_deposit_type NOT IN
     ('savings','levy','entrance_fee','special','adjustment','refund') THEN
    RAISE EXCEPTION 'Unknown deposit type: %', p_deposit_type USING ERRCODE = '22023';
  END IF;

  v_credits_member := public.manual_deposit_credits_member_balance(p_deposit_type);

  -- ── Member must exist and be allowed to receive money ─────────────────────
  SELECT id, name, user_id, is_active, is_flagged, registration_fee_paid
    INTO v_profile
    FROM public.profiles
   WHERE id = p_profile_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found' USING ERRCODE = '23503';
  END IF;
  IF v_profile.is_active = FALSE THEN
    RAISE EXCEPTION 'This member''s account is inactive; deposits cannot be recorded against it'
      USING ERRCODE = '22023';
  END IF;

  -- ── Idempotency: the same reference must not post twice ────────────────────
  -- An admin re-submitting after a timeout is the common case; without this the
  -- member is credited twice for one payment.
  IF EXISTS (
    SELECT 1 FROM public.deposit_requests
     WHERE payment_reference = btrim(p_reference)
  ) THEN
    RAISE EXCEPTION 'A deposit with reference "%" has already been recorded', btrim(p_reference)
      USING ERRCODE = '23505';
  END IF;

  v_type_label := CASE p_deposit_type
    WHEN 'savings'      THEN 'Savings Contribution'
    WHEN 'levy'         THEN 'Monthly Levy'
    WHEN 'entrance_fee' THEN 'Entrance Fee'
    WHEN 'special'      THEN 'Special Contribution'
    WHEN 'adjustment'   THEN 'Adjustment (Credit)'
    WHEN 'refund'       THEN 'Refund'
  END;

  -- ── Lock the wallet so the balance cannot race ────────────────────────────
  -- The whole reason this is server-side: two concurrent calls must serialise
  -- here, not both compute the same new balance in separate browsers.
  SELECT * INTO v_wallet
    FROM public.wallets
   WHERE profile_id = p_profile_id
   FOR UPDATE;

  v_balance_before := COALESCE(v_wallet.balance, 0);
  v_balance_after := CASE WHEN v_credits_member
                          THEN v_balance_before + p_amount
                          ELSE v_balance_before END;

  v_txn_no := 'TXN-MANUAL-' || replace(gen_random_uuid()::text, '-', '');

  -- ── 1. Transaction (the money movement) ───────────────────────────────────
  INSERT INTO public.transactions (
    transaction_id, profile_id, wallet_id, type, category, amount, currency,
    status, payment_method, reference, description,
    initiated_at, completed_at, created_at,
    balance_before, balance_after,
    contribution_source, contribution_month, posted_by, metadata
  ) VALUES (
    v_txn_no, p_profile_id, v_wallet.id, 'deposit', 'credit', p_amount, 'NGN',
    'completed', COALESCE(p_payment_method, 'manual'), btrim(p_reference),
    v_type_label || ': ' || COALESCE(p_description, 'Recorded by admin'),
    v_now, v_now, v_now,
    v_balance_before, v_balance_after,
    'admin_manual',
    -- A savings-family deposit settles the month it was recorded in; fee types
    -- are not contributions and carry no month.
    CASE WHEN v_credits_member AND p_deposit_type <> 'refund' AND p_deposit_type <> 'adjustment'
         THEN TO_CHAR(v_now, 'YYYY-MM') ELSE NULL END,
    p_admin_id,
    jsonb_build_object(
      'source', 'admin-manual',
      'deposit_type', p_deposit_type,
      'credits_member_balance', v_credits_member,
      'verified_by', p_admin_id,
      'received_by', p_admin_id
    )
  ) RETURNING id INTO v_txn_id;

  -- ── 2. Deposit request (the admin-facing record of the payment) ───────────
  INSERT INTO public.deposit_requests (
    profile_id, transaction_id, amount, currency, status,
    payment_reference, payment_date, admin_notes,
    verified_by, verified_at, created_at,
    allocation_type
  ) VALUES (
    p_profile_id, v_txn_id, p_amount, 'NGN', 'verified',
    btrim(p_reference), v_now, p_description,
    p_admin_id, v_now, v_now,
    CASE WHEN p_deposit_type = 'entrance_fee' THEN 'registration_fee'
         WHEN v_credits_member THEN 'monthly_contribution'
         ELSE 'fee' END
  ) RETURNING id INTO v_deposit_id;

  -- ── 3. Wallet ─────────────────────────────────────────────────────────────
  IF v_credits_member THEN
    IF v_wallet.id IS NULL THEN
      INSERT INTO public.wallets (profile_id, balance, currency, is_active, last_updated, created_at, updated_at)
      VALUES (p_profile_id, p_amount, 'NGN', TRUE, v_now, v_now, v_now);
    ELSE
      UPDATE public.wallets
         SET balance = v_balance_after,
             last_updated = v_now,
             updated_at = v_now
       WHERE id = v_wallet.id;
    END IF;
  END IF;

  -- ── 4. Savings mirror (savings-family deposits only) ──────────────────────
  IF v_credits_member AND p_deposit_type IN ('savings', 'special') THEN
    UPDATE public.savings
       SET total_saved = COALESCE(total_saved, 0) + p_amount,
           last_savings_date = v_now
     WHERE profile_id = p_profile_id;
  END IF;

  -- ── 5. Entrance fee settles the registration-fee gate ─────────────────────
  -- Recording the fee IS the settlement, so the member's activation gate opens
  -- on the strength of a real payment rather than an exemption.
  IF p_deposit_type = 'entrance_fee' AND v_profile.registration_fee_paid IS NOT TRUE THEN
    UPDATE public.profiles
       SET registration_fee_paid = TRUE,
           registration_fee_paid_at = COALESCE(registration_fee_paid_at, v_now),
           updated_at = v_now
     WHERE id = p_profile_id;
  END IF;

  -- ── 6. Audit trail, written server-side ───────────────────────────────────
  INSERT INTO public.audit_logs (
    action, target_model, target_id, metadata, actor_id, actor_role, details, created_at
  ) VALUES (
    'MANUAL_DEPOSIT_CREATED', 'deposit_requests', v_deposit_id::text,
    jsonb_build_object(
      'profile_id', p_profile_id,
      'member_name', v_profile.name,
      'membership_id', v_profile.user_id,
      'amount', p_amount,
      'deposit_type', p_deposit_type,
      'payment_method', p_payment_method,
      'reference', btrim(p_reference),
      'balance_before', v_balance_before,
      'balance_after', v_balance_after,
      'credits_member_balance', v_credits_member,
      'transaction_id', v_txn_id
    ),
    p_admin_id, 'admin',
    -- `audit_logs.details` is jsonb, so this must be an object, not a string.
    jsonb_build_object(
      'summary', 'Manual deposit: ' || v_type_label || ' of ' || p_amount::text ||
                 ' for ' || COALESCE(v_profile.name, p_profile_id::text),
      'deposit_type', p_deposit_type,
      'amount', p_amount
    ),
    v_now
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'transaction_id', v_txn_id,
    'transaction_ref', v_txn_no,
    'deposit_request_id', v_deposit_id,
    'balance_before', v_balance_before,
    'balance_after', v_balance_after,
    'credits_member_balance', v_credits_member,
    'settled_registration_fee', p_deposit_type = 'entrance_fee',
    'deposit_type_label', v_type_label
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.record_manual_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID) IS
  'Records an admin manual deposit atomically: transaction, deposit_request, wallet balance (server-computed under a row lock), savings mirror, entrance-fee settlement and the audit entry either all commit or none do. Rejects a duplicate reference.';

-- Only the backend's service role may invoke this; RLS still applies to any
-- other caller, and SECURITY DEFINER means the function bypasses RLS when it
-- runs, so the grant must be narrow.
REVOKE ALL ON FUNCTION public.record_manual_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_manual_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.record_manual_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID) FROM authenticated;

-- A reference identifies one payment; make double-posting impossible at the
-- database level as well as inside the function. Partial index so legacy rows
-- with a NULL reference do not collide.
CREATE UNIQUE INDEX IF NOT EXISTS idx_deposit_requests_reference_unique
  ON public.deposit_requests (payment_reference)
  WHERE payment_reference IS NOT NULL;
