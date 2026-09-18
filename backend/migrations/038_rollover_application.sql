-- Migration 038: Rollover approval actually extends the loan
--
-- Three defects this fixes, all on the same flow — a member asking to extend a
-- loan's tenure so they can repay over more months:
--
-- 1. There was NO admin API for rollovers. The dashboard's Rollover Management
--    page calls `/api/admin/rollovers`, `/rollovers/:id/approve` and
--    `/rollovers/:id/reject`; none were implemented, so the page 404'd on
--    everything. (The routes in `routes/rollover.js` are the member-facing
--    `/api/v1/rollover/*` ones and use member auth.)
--
-- 2. Approving or rejecting wrote columns that do not exist. The handlers set
--    `approved_at` / `admin_notes` / `rejected_at`; the table actually has
--    `reviewed_by` / `reviewed_at` / `rejection_reason`. Verified against
--    production: `column "approved_at" of relation "rollovers" does not exist`,
--    so approve and reject failed outright even for the member-facing routes.
--
-- 3. Approving never applied the rollover. It flipped `status` to 'approved' and
--    sent the member "Your new repayment schedule is now active", but nothing
--    ever touched the loan — `routes/rollover.js` contains no `loans` update.
--    The member was told their schedule had changed while the obligation, tenure
--    and monthly repayment were all unchanged. Nothing else in the codebase
--    applies it: no trigger, no worker, no mobile-side handling.
--
-- This migration adds the missing columns (additively, keeping the existing
-- ones working) and a function that applies an approved rollover to the loan in
-- one transaction.

-- ---------------------------------------------------------------------------
-- 1. Columns the handlers actually write
-- ---------------------------------------------------------------------------
ALTER TABLE public.rollovers
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS admin_notes TEXT,
  ADD COLUMN IF NOT EXISTS applied_at TIMESTAMPTZ,
  -- Records the loan state after the extension so the change is auditable and
  -- reversible in review.
  ADD COLUMN IF NOT EXISTS previous_tenure_months INTEGER,
  ADD COLUMN IF NOT EXISTS previous_remaining_balance NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS previous_monthly_repayment NUMERIC(18,2);

COMMENT ON COLUMN public.rollovers.applied_at IS
  'When the approved rollover was actually written onto the loan. NULL means approved but not yet applied — the state the member must never be told is "active".';

-- ---------------------------------------------------------------------------
-- 2. Apply an approved rollover to its loan, atomically
-- ---------------------------------------------------------------------------
-- Extends the loan's tenure and recalculates the monthly repayment over the new
-- term, keeping the outstanding balance (a rollover re-schedules; it does not
-- forgive). Guarded so it can only run once per rollover.

CREATE OR REPLACE FUNCTION public.apply_loan_rollover(
  p_rollover_id UUID,
  p_admin_id    UUID
)
RETURNS JSONB AS $$
DECLARE
  v_rollover     RECORD;
  v_loan         RECORD;
  v_extension    INTEGER;
  v_new_tenure   INTEGER;
  v_new_monthly  NUMERIC(18,2);
  v_remaining    NUMERIC(18,2);
  v_now          TIMESTAMPTZ := NOW();
BEGIN
  SELECT * INTO v_rollover FROM public.rollovers WHERE id = p_rollover_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rollover not found' USING ERRCODE = '23503';
  END IF;

  IF v_rollover.status <> 'approved' THEN
    RAISE EXCEPTION 'Only an approved rollover can be applied (current status: %)',
      v_rollover.status USING ERRCODE = '22023';
  END IF;

  -- Idempotency: applying twice would double the extension.
  IF v_rollover.applied_at IS NOT NULL THEN
    RAISE EXCEPTION 'This rollover has already been applied' USING ERRCODE = '23505';
  END IF;

  SELECT * INTO v_loan FROM public.loans WHERE id = v_rollover.loan_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The loan for this rollover no longer exists' USING ERRCODE = '23503';
  END IF;

  -- A completed or cancelled loan has nothing to extend.
  IF v_loan.status IN ('completed', 'cancelled', 'rejected') THEN
    RAISE EXCEPTION 'This loan is % and cannot be rolled over', v_loan.status
      USING ERRCODE = '22023';
  END IF;

  v_extension := GREATEST(1, LEAST(12, COALESCE(v_rollover.extension_months, 1)));
  v_new_tenure := COALESCE(v_loan.tenure_months, 0) + v_extension;

  -- Outstanding balance is what still has to be repaid; the rollover spreads it
  -- over the new term rather than changing what is owed.
  v_remaining := COALESCE(v_loan.remaining_balance, v_loan.total_repayment, v_loan.amount, 0);

  v_new_monthly := CASE
    WHEN v_new_tenure > 0 THEN ROUND(v_remaining / v_new_tenure, 2)
    ELSE v_remaining
  END;

  UPDATE public.loans
     SET tenure_months        = v_new_tenure,
         remaining_months     = GREATEST(0, COALESCE(v_loan.remaining_months, 0) + v_extension),
         monthly_repayment    = v_new_monthly,
         updated_at           = v_now
   WHERE id = v_loan.id;

  UPDATE public.rollovers
     SET applied_at                    = v_now,
         previous_tenure_months        = v_loan.tenure_months,
         previous_remaining_balance    = v_remaining,
         previous_monthly_repayment    = v_loan.monthly_repayment,
         reviewed_by                   = COALESCE(v_rollover.reviewed_by, p_admin_id),
         reviewed_at                   = COALESCE(v_rollover.reviewed_at, v_now),
         updated_at                    = v_now
   WHERE id = p_rollover_id;

  INSERT INTO public.audit_logs (
    action, target_model, target_id, metadata, actor_id, actor_role, details, created_at
  ) VALUES (
    'ROLLOVER_APPLIED', 'loans', v_loan.id::text,
    jsonb_build_object(
      'rollover_id', p_rollover_id,
      'loan_id', v_loan.loan_id,
      'extension_months', v_extension,
      'previous_tenure_months', v_loan.tenure_months,
      'new_tenure_months', v_new_tenure,
      'previous_monthly_repayment', v_loan.monthly_repayment,
      'new_monthly_repayment', v_new_monthly,
      'outstanding_balance', v_remaining
    ),
    p_admin_id, 'admin',
    jsonb_build_object(
      'summary', 'Rollover applied: loan ' || COALESCE(v_loan.loan_id, v_loan.id::text) ||
                 ' extended by ' || v_extension::text || ' months to ' || v_new_tenure::text ||
                 ' months; monthly repayment ' || v_new_monthly::text
    ),
    v_now
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'loan_id', v_loan.id,
    'extension_months', v_extension,
    'previous_tenure_months', v_loan.tenure_months,
    'new_tenure_months', v_new_tenure,
    'previous_monthly_repayment', v_loan.monthly_repayment,
    'new_monthly_repayment', v_new_monthly,
    'outstanding_balance', v_remaining
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.apply_loan_rollover(UUID, UUID) IS
  'Writes an approved rollover onto its loan: extends the tenure and re-spreads the outstanding balance over the new term. Single-use and idempotent — a second call is refused.';

REVOKE ALL ON FUNCTION public.apply_loan_rollover(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_loan_rollover(UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.apply_loan_rollover(UUID, UUID) FROM authenticated;

-- ---------------------------------------------------------------------------
-- 3. Rollover status vocabulary
-- ---------------------------------------------------------------------------
-- The member-facing route creates rollovers as 'pending' while the dashboard
-- filters on 'pending_guarantors' / 'awaiting_admin_approval'. Both are kept
-- readable: the list endpoint returns the stored value and the dashboard already
-- falls back to a default badge for anything it does not recognise.
CREATE INDEX IF NOT EXISTS idx_rollovers_status
  ON public.rollovers (status, created_at DESC);

COMMENT ON COLUMN public.rollovers.status IS
  'pending | awaiting_admin_approval | approved | rejected | cancelled. The guarantor stage is tracked on rollover_guarantors; "pending_guarantors" is a derived label, not a stored status.';