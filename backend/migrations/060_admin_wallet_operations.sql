-- Migration 060: Admin wallet operations (freeze/unfreeze and balance adjustment)
--
-- Why this exists
-- ---------------
-- The admin dashboard's Wallet Management page is routed and reachable, but
-- every action on it failed:
--
--   * `PATCH /api/admin/wallets/:id/status`  — no such route
--   * `POST  /api/admin/wallets/:id/adjust`  — no such route
--   * `GET   /api/admin/wallets` returned `{ wallets, pagination }` while the
--     page reads `data`/`total`/`totalBalance`/`frozenCount`, so the table and
--     the summary cards rendered empty even though the query succeeded.
--
-- The balance adjustment is the sensitive one: it moves member money. Writing
-- `balance = balance + amount` from the route would repeat the exact defects
-- migration 036 was written to remove from manual deposits (see its header):
-- a read-then-write race that loses one of two concurrent credits, no
-- transaction boundary, and a client-shaped audit record. So the adjustment is
-- a single PL/pgSQL function that locks the wallet row, computes the new
-- balance server-side, and writes the transaction and audit entry in the same
-- transaction.
--
-- There is no `wallets.status` column today, and nothing reads `wallets.is_active`,
-- so this adds `status` and leaves `is_active` untouched for existing readers.

-- ---------------------------------------------------------------------------
-- 1. Wallet status
-- ---------------------------------------------------------------------------
ALTER TABLE public.wallets
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'wallets_status_check'
  ) THEN
    ALTER TABLE public.wallets
      ADD CONSTRAINT wallets_status_check
      CHECK (status IN ('active', 'frozen', 'suspended'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_wallets_status ON public.wallets (status);

-- ---------------------------------------------------------------------------
-- 2. Admin balance adjustment
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_adjust_wallet_balance(
  p_wallet_id UUID,
  p_amount    NUMERIC,
  p_note      TEXT,
  p_admin_id  UUID
)
RETURNS JSONB AS $$
DECLARE
  v_wallet        RECORD;
  v_profile       RECORD;
  v_balance_before NUMERIC(18,2) := 0;
  v_balance_after  NUMERIC(18,2) := 0;
  v_category      TEXT;
  v_txn_no        TEXT;
  v_txn_id        UUID;
  v_now           TIMESTAMPTZ := NOW();
BEGIN
  -- ── Validate input ────────────────────────────────────────────────────────
  IF p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'A wallet must be selected' USING ERRCODE = '22023';
  END IF;
  IF p_amount IS NULL OR p_amount = 0 THEN
    RAISE EXCEPTION 'Amount must be a non-zero number' USING ERRCODE = '22023';
  END IF;
  IF abs(p_amount) > 100000000 THEN
    RAISE EXCEPTION 'Amount exceeds the maximum of 100,000,000' USING ERRCODE = '22023';
  END IF;
  -- An unexplained money movement is not auditable, so the note is required.
  IF p_note IS NULL OR length(btrim(p_note)) < 3 THEN
    RAISE EXCEPTION 'A reason of at least 3 characters is required' USING ERRCODE = '22023';
  END IF;

  v_category := CASE WHEN p_amount > 0 THEN 'credit' ELSE 'debit' END;

  -- ── Lock the wallet row; the balance is read under this lock ──────────────
  SELECT * INTO v_wallet FROM public.wallets WHERE id = p_wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found' USING ERRCODE = '23503';
  END IF;

  IF v_wallet.status <> 'active' THEN
    RAISE EXCEPTION 'This wallet is %; unfreeze it before adjusting the balance',
      v_wallet.status USING ERRCODE = '22023';
  END IF;

  SELECT id, name, user_id INTO v_profile
    FROM public.profiles WHERE id = v_wallet.profile_id;

  v_balance_before := COALESCE(v_wallet.balance, 0);
  v_balance_after  := v_balance_before + p_amount;

  -- A debit may not take the wallet below zero. A negative member balance is
  -- almost always a typo, and correcting it later would itself need an
  -- adjustment, so refuse it here instead of writing one.
  IF v_balance_after < 0 THEN
    RAISE EXCEPTION 'Adjustment would take the balance negative (from % by %)',
      v_balance_before, p_amount USING ERRCODE = '22023';
  END IF;

  v_txn_no := 'TXN-ADJUST-' || replace(gen_random_uuid()::text, '-', '');

  -- ── 1. The money movement ─────────────────────────────────────────────────
  INSERT INTO public.transactions (
    transaction_id, profile_id, wallet_id, type, category, amount, currency,
    status, payment_method, description,
    initiated_at, completed_at, created_at,
    balance_before, balance_after,
    posted_by, metadata
  ) VALUES (
    v_txn_no, v_wallet.profile_id, v_wallet.id, 'adjustment', v_category,
    abs(p_amount), COALESCE(v_wallet.currency, 'NGN'),
    'completed', 'admin_adjustment', btrim(p_note),
    v_now, v_now, v_now,
    v_balance_before, v_balance_after,
    p_admin_id,
    jsonb_build_object('source', 'admin_wallet_adjustment', 'note', btrim(p_note))
  ) RETURNING id INTO v_txn_id;

  -- ── 2. The balance, computed server-side under the lock ───────────────────
  UPDATE public.wallets
     SET balance = v_balance_after,
         updated_at = v_now,
         last_updated = v_now
   WHERE id = p_wallet_id;

  -- ── 3. Audit trail ────────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (
    action, target_model, target_id, metadata, actor_id, actor_role, details, created_at
  ) VALUES (
    'WALLET_BALANCE_ADJUSTED', 'wallets', p_wallet_id::text,
    jsonb_build_object(
      'profile_id', v_wallet.profile_id,
      'member_name', v_profile.name,
      'membership_id', v_profile.user_id,
      'amount', p_amount,
      'category', v_category,
      'note', btrim(p_note),
      'balance_before', v_balance_before,
      'balance_after', v_balance_after,
      'transaction_id', v_txn_id
    ),
    p_admin_id, 'admin',
    jsonb_build_object(
      'summary', 'Wallet balance adjusted by ' || p_amount::text ||
                 ' for ' || COALESCE(v_profile.name, v_wallet.profile_id::text),
      'note', btrim(p_note)
    ),
    v_now
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'wallet_id', p_wallet_id,
    'transaction_id', v_txn_id,
    'transaction_ref', v_txn_no,
    'balance_before', v_balance_before,
    'balance_after', v_balance_after,
    'category', v_category
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 3. Admin wallet status change
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_wallet_status(
  p_wallet_id UUID,
  p_status    TEXT,
  p_admin_id  UUID
)
RETURNS JSONB AS $$
DECLARE
  v_wallet  RECORD;
  v_profile RECORD;
  v_now     TIMESTAMPTZ := NOW();
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('active', 'frozen', 'suspended') THEN
    RAISE EXCEPTION 'Unknown wallet status: %', p_status USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE id = p_wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found' USING ERRCODE = '23503';
  END IF;

  SELECT id, name, user_id INTO v_profile
    FROM public.profiles WHERE id = v_wallet.profile_id;

  UPDATE public.wallets
     SET status = p_status, updated_at = v_now
   WHERE id = p_wallet_id;

  INSERT INTO public.audit_logs (
    action, target_model, target_id, metadata, actor_id, actor_role, details, created_at
  ) VALUES (
    'WALLET_STATUS_CHANGED', 'wallets', p_wallet_id::text,
    jsonb_build_object(
      'profile_id', v_wallet.profile_id,
      'member_name', v_profile.name,
      'from', v_wallet.status,
      'to', p_status
    ),
    p_admin_id, 'admin',
    jsonb_build_object(
      'summary', 'Wallet status changed from ' || v_wallet.status || ' to ' || p_status ||
                 ' for ' || COALESCE(v_profile.name, v_wallet.profile_id::text)
    ),
    v_now
  );

  RETURN jsonb_build_object('success', TRUE, 'wallet_id', p_wallet_id, 'status', p_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 4. Dashboard summary figures
-- ---------------------------------------------------------------------------
-- The page renders four summary cards. Computing them in the database keeps the
-- route from pulling every wallet row just to sum a column.
CREATE OR REPLACE FUNCTION public.admin_wallet_stats()
RETURNS JSONB AS $$
DECLARE
  v_total   NUMERIC(18,2);
  v_frozen  INTEGER;
  v_pending INTEGER;
  v_today   NUMERIC(18,2);
BEGIN
  SELECT COALESCE(SUM(balance), 0) INTO v_total FROM public.wallets;
  SELECT COUNT(*) INTO v_frozen FROM public.wallets WHERE status = 'frozen';
  SELECT COUNT(*) INTO v_pending FROM public.transactions WHERE status = 'pending';
  SELECT COALESCE(SUM(amount), 0) INTO v_today
    FROM public.transactions
   WHERE status = 'completed'
     AND completed_at >= date_trunc('day', NOW());

  RETURN jsonb_build_object(
    'totalBalance', v_total,
    'frozenCount', v_frozen,
    'pendingTransfers', v_pending,
    'todayVolume', v_today
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.admin_adjust_wallet_balance IS
  'Adjusts a member wallet balance atomically: locks the wallet row, computes the new balance server-side, writes the adjustment transaction and the audit entry, or none of them. Rejects a frozen/suspended wallet, a zero amount, a missing reason, and any adjustment that would take the balance negative.';
COMMENT ON FUNCTION public.admin_set_wallet_status IS
  'Changes a wallet status (active/frozen/suspended) and writes the audit entry in the same transaction.';

COMMENT ON FUNCTION public.admin_wallet_stats IS
  'Aggregate figures for the admin wallet dashboard: total balance, frozen wallet count, pending transfer count and today''s completed volume.';
