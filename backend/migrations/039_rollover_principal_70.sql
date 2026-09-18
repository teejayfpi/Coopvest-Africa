-- Migration 039: Loan rollover as refinancing/top-up, gated on 70% principal repaid
--
-- Replaces the previous rollover model, which was wrong in three ways:
--
--   1. It triggered at 50% of *total amount paid*, not 70% of *principal*.
--      Interest, fees and penalties inflate "amount paid", so a member could
--      look eligible without having repaid 70% of what they actually borrowed.
--   2. It read `loans.total_repaid`, a column that DOES NOT EXIST (verified:
--      42703). The expression always evaluated to 0, so nobody could ever be
--      eligible — the feature was dead.
--   3. Approving it extended the existing loan's tenure. The agreed model is a
--      refinance: the old loan is settled and a NEW loan is created, with only
--      the net difference disbursed to the member.
--
-- Principal was not tracked at all. `loan_repayments.principal_component` and
-- `interest_component` exist but are never written (every row in production is
-- NULL), and `remaining_balance` reduces 1:1 with each payment. So "principal
-- repaid" had no source of truth. This migration establishes one.

-- ---------------------------------------------------------------------------
-- 1. Policy settings (configurable, not hard-coded)
-- ---------------------------------------------------------------------------
INSERT INTO public.system_settings (key, value, description) VALUES
  ('loan.rollover_min_principal_pct', '70',
   'Percentage of original loan principal that must be repaid before a member may request a rollover.'),
  ('loan.rollover_max_consecutive', '2',
   'Maximum number of consecutive rollovers on a single loan chain before the member must settle in full.')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Principal tracking on loans
-- ---------------------------------------------------------------------------
ALTER TABLE public.loans
  -- Principal actually repaid to date. Never decreases.
  ADD COLUMN IF NOT EXISTS principal_repaid NUMERIC(18,2) NOT NULL DEFAULT 0,
  -- Original principal for this loan. Copied from `amount` at creation so a
  -- later edit to `amount` cannot rewrite history.
  ADD COLUMN IF NOT EXISTS original_principal NUMERIC(18,2),
  -- Rollover lineage, so a chain is auditable: Loan #001 → #002 → #003.
  ADD COLUMN IF NOT EXISTS parent_loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_rollover BOOLEAN NOT NULL DEFAULT FALSE,
  -- Consecutive rollovers in this chain, including this loan. Drives the cap.
  ADD COLUMN IF NOT EXISTS rollover_count INTEGER NOT NULL DEFAULT 0,
  -- Where a rollover's net cash went, for tracing the disbursement.
  ADD COLUMN IF NOT EXISTS rollover_disbursement_transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.loans.principal_repaid IS
  'Principal component of repayments received. Drives rollover eligibility: the member qualifies at 70% of original_principal.';
COMMENT ON COLUMN public.loans.rollover_count IS
  'Consecutive rollovers in this chain. Capped by system_settings loan.rollover_max_consecutive.';

-- Existing loans: principal is unknown, so seed original_principal and derive
-- principal_repaid from what has been repaid, allocated pro-rata.
UPDATE public.loans
   SET original_principal = COALESCE(original_principal, amount)
 WHERE original_principal IS NULL;

-- ---------------------------------------------------------------------------
-- 3. Principal / interest split on repayments
-- ---------------------------------------------------------------------------
-- Allocation is PRO-RATA by the principal share of total repayment:
--
--   principal_share = original_principal / total_repayment
--   principal_component = payment × principal_share
--
-- This is the right model for this platform because it uses SIMPLE interest
-- (total_repayment = principal + principal × rate), not amortisation. Under
-- pro-rata, repaying the full total means principal_repaid = principal exactly
-- (100%), and a partial payment credits principal proportionally. A
-- reducing-balance amortisation would front-load interest and make 70% of
-- principal materially harder to reach than the policy intends.
--
-- It also delivers the protection the policy asks for: on a ₦1,000,000 loan at
-- 7.5%, paying ₦700,000 in total credits ₦651,163 of principal — 65.1%, NOT
-- 70% — because ₦48,837 of it was interest.

CREATE OR REPLACE FUNCTION public.split_repayment_principal(
  p_amount           NUMERIC,
  p_original_principal NUMERIC,
  p_total_repayment  NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
  v_share NUMERIC;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN RETURN 0; END IF;
  IF COALESCE(p_original_principal, 0) <= 0 THEN RETURN 0; END IF;

  -- Without a total to divide by, treat the whole payment as principal rather
  -- than crediting nothing.
  IF COALESCE(p_total_repayment, 0) <= 0 THEN RETURN p_amount; END IF;

  v_share := LEAST(1, p_original_principal / p_total_repayment);
  RETURN ROUND(p_amount * v_share, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.split_repayment_principal(NUMERIC, NUMERIC, NUMERIC) IS
  'Pro-rata split of a loan repayment into its principal component. Full repayment of total_repayment yields principal_repaid = original_principal exactly.';

-- Backfill principal_component on existing repayments so historical loans have
-- a defensible principal position rather than zero.
UPDATE public.loan_repayments lr
   SET principal_component = public.split_repayment_principal(
         lr.amount, l.original_principal, l.total_repayment),
       interest_component = lr.amount - public.split_repayment_principal(
         lr.amount, l.original_principal, l.total_repayment)
  FROM public.loans l
 WHERE lr.loan_id = l.id
   AND lr.principal_component IS NULL
   AND lr.status IN ('paid', 'completed', 'successful');

-- Derive each loan's principal position from its recorded repayments.
UPDATE public.loans l
   SET principal_repaid = COALESCE(sub.total, 0)
  FROM (
    SELECT loan_id, SUM(COALESCE(principal_component, 0)) AS total
      FROM public.loan_repayments
     WHERE status IN ('paid', 'completed', 'successful')
     GROUP BY loan_id
  ) sub
 WHERE sub.loan_id = l.id
   AND l.principal_repaid = 0;

-- Keep principal_repaid current whenever a repayment is marked paid.
CREATE OR REPLACE FUNCTION public.sync_loan_principal_repaid()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.loan_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.status NOT IN ('paid', 'completed', 'successful') THEN RETURN NEW; END IF;

  -- Only count a repayment once.
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN RETURN NEW; END IF;

  UPDATE public.loans l
     SET principal_repaid = LEAST(
           COALESCE(l.original_principal, l.amount),
           COALESCE(l.principal_repaid, 0) +
             COALESCE(NEW.principal_component,
                      public.split_repayment_principal(
                        NEW.amount, l.original_principal, l.total_repayment))
         ),
         updated_at = NOW()
   WHERE l.id = NEW.loan_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_loan_principal_repaid ON public.loan_repayments;
CREATE TRIGGER trg_sync_loan_principal_repaid
  AFTER INSERT OR UPDATE OF status ON public.loan_repayments
  FOR EACH ROW EXECUTE FUNCTION public.sync_loan_principal_repaid();

-- ---------------------------------------------------------------------------
-- 4. Principal position for a loan
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.loan_principal_position(p_loan_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_loan RECORD;
  v_principal NUMERIC(18,2);
  v_repaid NUMERIC(18,2);
  v_outstanding NUMERIC(18,2);
  v_pct NUMERIC(6,2);
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Loan not found' USING ERRCODE = '23503';
  END IF;

  v_principal := COALESCE(v_loan.original_principal, v_loan.amount, 0);
  -- Never report more principal repaid than was borrowed, however the data got
  -- into that state.
  v_repaid := LEAST(v_principal, GREATEST(0, COALESCE(v_loan.principal_repaid, 0)));
  v_outstanding := GREATEST(0, v_principal - v_repaid);
  v_pct := CASE WHEN v_principal > 0 THEN ROUND((v_repaid / v_principal) * 100, 2) ELSE 0 END;

  RETURN jsonb_build_object(
    'loan_id', v_loan.id,
    'loan_ref', v_loan.loan_id,
    'original_principal', v_principal,
    'principal_repaid', v_repaid,
    'outstanding_principal', v_outstanding,
    'repayment_percentage', v_pct,
    -- Outstanding total including interest, which is what a refinance settles.
    'outstanding_balance', COALESCE(v_loan.remaining_balance, v_outstanding),
    'total_repayment', v_loan.total_repayment,
    'interest_rate', v_loan.effective_interest_rate,
    'status', v_loan.status,
    'rollover_count', COALESCE(v_loan.rollover_count, 0),
    'is_rollover', COALESCE(v_loan.is_rollover, FALSE)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 5. Rollover eligibility — the 70% gate plus the four supporting rules
-- ---------------------------------------------------------------------------
-- Eligibility to APPLY, never approval. Each rule reports separately so the app
-- can explain exactly what is missing.

CREATE OR REPLACE FUNCTION public.loan_rollover_eligibility(p_loan_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_loan        RECORD;
  v_pos         JSONB;
  v_min_pct     NUMERIC := 70;
  v_max_cycles  INTEGER := 2;
  v_blockers    JSONB := '[]'::jsonb;
  v_unpaid_fees INTEGER := 0;
  v_serious_defaults INTEGER := 0;
  v_repaid_pct  NUMERIC;
  v_is_eligible BOOLEAN;
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Loan not found' USING ERRCODE = '23503';
  END IF;

  SELECT COALESCE(value::text, '70')::NUMERIC INTO v_min_pct
    FROM public.system_settings WHERE key = 'loan.rollover_min_principal_pct';
  v_min_pct := COALESCE(v_min_pct, 70);

  SELECT COALESCE(value::text, '2')::INTEGER INTO v_max_cycles
    FROM public.system_settings WHERE key = 'loan.rollover_max_consecutive';
  v_max_cycles := COALESCE(v_max_cycles, 2);

  v_pos := public.loan_principal_position(p_loan_id);
  v_repaid_pct := COALESCE((v_pos->>'repayment_percentage')::NUMERIC, 0);

  -- ── Rule 1: 70% of PRINCIPAL repaid (the entry gate) ─────────────────────
  IF v_repaid_pct < v_min_pct THEN
    v_blockers := v_blockers || jsonb_build_object(
      'code', 'INSUFFICIENT_PRINCIPAL_REPAID',
      'message', format('You become eligible after repaying %s%% of your current loan principal (currently %s%%).',
                        v_min_pct, v_repaid_pct),
      'required_percentage', v_min_pct,
      'current_percentage', v_repaid_pct
    );
  END IF;

  -- ── Rule 2: no serious default ───────────────────────────────────────────
  SELECT COUNT(*) INTO v_serious_defaults
    FROM public.loans l
   WHERE l.profile_id = v_loan.profile_id
     AND l.id <> v_loan.id
     AND l.status IN ('defaulted', 'in_recovery');
  IF v_serious_defaults > 0 THEN
    v_blockers := v_blockers || jsonb_build_object(
      'code', 'SERIOUS_DEFAULT',
      'message', 'A member with a defaulted or in-recovery loan cannot roll over. Please resolve it first.',
      'count', v_serious_defaults
    );
  END IF;

  -- Also block if THIS loan is already in trouble.
  IF v_loan.status IN ('overdue', 'defaulted', 'in_recovery') THEN
    v_blockers := v_blockers || jsonb_build_object(
      'code', 'LOAN_IN_ARREARS',
      'message', 'This loan is overdue. Please clear the arrears before requesting a rollover.',
      'status', v_loan.status
    );
  END IF;

  -- ── Rule 3: account in good standing ─────────────────────────────────────
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_loan.profile_id AND is_flagged = TRUE) THEN
    v_blockers := v_blockers || jsonb_build_object(
      'code', 'ACCOUNT_FLAGGED',
      'message', 'Your account is restricted. Please contact support before requesting a rollover.'
    );
  END IF;

  SELECT COUNT(*) INTO v_unpaid_fees
    FROM public.member_fees
   WHERE profile_id = v_loan.profile_id
     AND status NOT IN ('paid', 'settled', 'waived', 'cancelled');
  IF v_unpaid_fees > 0 THEN
    v_blockers := v_blockers || jsonb_build_object(
      'code', 'OUTSTANDING_OBLIGATIONS',
      'message', format('You have %s outstanding obligation(s). Please settle them before requesting a rollover.', v_unpaid_fees),
      'count', v_unpaid_fees
    );
  END IF;

  -- ── Rule 4: within the consecutive-rollover cap ───────────────────────────
  IF COALESCE(v_loan.rollover_count, 0) >= v_max_cycles THEN
    v_blockers := v_blockers || jsonb_build_object(
      'code', 'ROLLOVER_LIMIT_REACHED',
      'message', format('This loan has already been rolled over %s time(s), the maximum allowed. It must be settled in full.', v_max_cycles),
      'rollover_count', COALESCE(v_loan.rollover_count, 0),
      'max_consecutive', v_max_cycles
    );
  END IF;

  -- ── Rule 5: the loan must be one that can be refinanced ──────────────────
  IF v_loan.status NOT IN ('active', 'repaying') THEN
    v_blockers := v_blockers || jsonb_build_object(
      'code', 'LOAN_NOT_ACTIVE',
      'message', format('Only an active loan can be rolled over (this one is %s).', v_loan.status),
      'status', v_loan.status
    );
  END IF;

  v_is_eligible := jsonb_array_length(v_blockers) = 0;

  RETURN jsonb_build_object(
    'is_eligible', v_is_eligible,
    'status', CASE WHEN v_is_eligible THEN 'eligible' ELSE 'ineligible' END,
    -- The five rules, each reported so the UI can show a checklist.
    'min_principal_percentage', v_min_pct,
    'repayment_percentage', v_repaid_pct,
    'has_minimum_principal_repaid', v_repaid_pct >= v_min_pct,
    'has_no_serious_default', v_serious_defaults = 0 AND v_loan.status NOT IN ('overdue','defaulted','in_recovery'),
    'account_in_good_standing', v_unpaid_fees = 0 AND NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_loan.profile_id AND is_flagged = TRUE),
    'within_rollover_limit', COALESCE(v_loan.rollover_count, 0) < v_max_cycles,
    'rollover_count', COALESCE(v_loan.rollover_count, 0),
    'max_consecutive_rollovers', v_max_cycles,
    'blockers', v_blockers,
    'position', v_pos
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.loan_rollover_eligibility(UUID) IS
  'Whether a member may REQUEST a rollover: 70% of principal repaid, no serious default, account in good standing, within the consecutive-rollover cap, and the loan still active. Eligibility to apply, never approval.';

-- ---------------------------------------------------------------------------
-- 6. Rollover terms — the refinancing calculation
-- ---------------------------------------------------------------------------
-- New loan minus the balance it settles = the net amount the member receives.
-- The member must never be handed the full new loan while still owing the old
-- one, which is what the previous model did.

CREATE OR REPLACE FUNCTION public.loan_rollover_terms(
  p_loan_id           UUID,
  p_requested_amount  NUMERIC,
  p_new_tenure_months INTEGER DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_loan         RECORD;
  v_pos          JSONB;
  v_savings      NUMERIC(18,2);
  v_wallet       NUMERIC(18,2);
  v_max_loan     NUMERIC(18,2);
  v_multiplier   NUMERIC(6,2);
  v_rate         NUMERIC(6,2);
  v_tenure       INTEGER;
  v_settlement   NUMERIC(18,2);
  v_net          NUMERIC(18,2);
  v_total_repay  NUMERIC(18,2);
  v_monthly      NUMERIC(18,2);
  v_errors       JSONB := '[]'::jsonb;
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Loan not found' USING ERRCODE = '23503';
  END IF;

  v_pos := public.loan_principal_position(p_loan_id);
  v_settlement := COALESCE((v_pos->>'outstanding_balance')::NUMERIC, 0);
  v_rate := COALESCE(v_loan.effective_interest_rate, 0);
  v_tenure := COALESCE(p_new_tenure_months, v_loan.tenure_months, 12);

  -- Savings-based cap, mirroring loanPolicy.js: multipliers by product.
  SELECT COALESCE(s.total_saved, 0) INTO v_savings
    FROM public.savings s WHERE s.profile_id = v_loan.profile_id;
  SELECT COALESCE(w.balance, 0) INTO v_wallet
    FROM public.wallets w WHERE w.profile_id = v_loan.profile_id;
  IF COALESCE(v_savings, 0) <= 0 THEN v_savings := COALESCE(v_wallet, 0); END IF;

  v_multiplier := CASE v_loan.loan_type
    WHEN 'Premium Loan' THEN 4
    WHEN 'Maxi Loan' THEN 5
    ELSE 3
  END;
  v_max_loan := ROUND(COALESCE(v_savings, 0) * v_multiplier, 2);

  IF p_requested_amount IS NULL OR p_requested_amount <= 0 THEN
    v_errors := v_errors || jsonb_build_object(
      'code', 'AMOUNT_REQUIRED', 'message', 'Enter the amount you want to borrow.');
  ELSIF p_requested_amount > v_max_loan THEN
    v_errors := v_errors || jsonb_build_object(
      'code', 'EXCEEDS_LOAN_LIMIT',
      'message', format('The maximum you can borrow is %s (%sx your savings of %s).',
                        to_char(v_max_loan, 'FM999,999,999,990.00'), v_multiplier,
                        to_char(COALESCE(v_savings,0), 'FM999,999,999,990.00')),
      'maximum', v_max_loan, 'multiplier', v_multiplier, 'savings', COALESCE(v_savings, 0));
  ELSIF p_requested_amount <= v_settlement THEN
    -- A rollover must leave the member with something; otherwise it is just a
    -- repayment with extra steps.
    v_errors := v_errors || jsonb_build_object(
      'code', 'NO_NET_DISBURSEMENT',
      'message', format('The new loan must exceed your outstanding balance of %s so there is an amount to disburse.',
                        to_char(v_settlement, 'FM999,999,999,990.00')),
      'outstanding_balance', v_settlement);
  END IF;

  -- Simple interest, matching the platform's existing convention
  -- (total = principal + principal x rate), NOT EMI x tenure.
  v_total_repay := ROUND(p_requested_amount + (p_requested_amount * v_rate / 100), 2);
  v_monthly := CASE WHEN v_tenure > 0 THEN ROUND(v_total_repay / v_tenure, 2) ELSE v_total_repay END;
  v_net := p_requested_amount - v_settlement;

  RETURN jsonb_build_object(
    'valid', jsonb_array_length(v_errors) = 0,
    'errors', v_errors,
    -- Current loan
    'current', v_pos,
    -- New loan
    'maximum_eligible', v_max_loan,
    'loan_multiplier', v_multiplier,
    'member_savings', COALESCE(v_savings, 0),
    'requested_amount', p_requested_amount,
    'interest_rate', v_rate,
    'new_tenure_months', v_tenure,
    'total_repayment', v_total_repay,
    'monthly_repayment', v_monthly,
    -- The settlement breakdown the member must see before accepting
    'settlement', jsonb_build_object(
      'new_loan_amount', p_requested_amount,
      'existing_balance_settled', v_settlement,
      'net_amount_to_member', v_net
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.loan_rollover_terms(UUID, NUMERIC, INTEGER) IS
  'Computes rollover terms as a refinance: new loan minus the outstanding balance it settles equals the net amount disbursed to the member.';

-- ---------------------------------------------------------------------------
-- 7. Execute a rollover: settle the old loan, create a new one
-- ---------------------------------------------------------------------------
-- Replaces the previous `apply_loan_rollover`, which extended the existing
-- loan's tenure in place. The agreed model preserves the chain:
-- Loan #001 → Rollover → Loan #002.

CREATE OR REPLACE FUNCTION public.execute_loan_rollover(
  p_rollover_id      UUID,
  p_requested_amount NUMERIC,
  p_new_tenure_months INTEGER,
  p_admin_id         UUID
) RETURNS JSONB AS $$
DECLARE
  v_rollover    RECORD;
  v_old         RECORD;
  v_terms       JSONB;
  v_new_loan_id UUID;
  v_new_ref     TEXT;
  v_settlement  NUMERIC(18,2);
  v_net         NUMERIC(18,2);
  v_now         TIMESTAMPTZ := NOW();
BEGIN
  SELECT * INTO v_rollover FROM public.rollovers WHERE id = p_rollover_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rollover not found' USING ERRCODE = '23503';
  END IF;
  IF v_rollover.status <> 'approved' THEN
    RAISE EXCEPTION 'Only an approved rollover can be executed (status: %)', v_rollover.status
      USING ERRCODE = '22023';
  END IF;
  IF v_rollover.applied_at IS NOT NULL THEN
    RAISE EXCEPTION 'This rollover has already been executed' USING ERRCODE = '23505';
  END IF;

  SELECT * INTO v_old FROM public.loans WHERE id = v_rollover.loan_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The loan for this rollover no longer exists' USING ERRCODE = '23503';
  END IF;
  IF v_old.status NOT IN ('active', 'repaying') THEN
    RAISE EXCEPTION 'This loan is % and cannot be rolled over', v_old.status USING ERRCODE = '22023';
  END IF;

  v_terms := public.loan_rollover_terms(v_old.id, p_requested_amount, p_new_tenure_months);
  IF NOT COALESCE((v_terms->>'valid')::BOOLEAN, FALSE) THEN
    RAISE EXCEPTION 'Rollover terms are not valid: %', v_terms->'errors' USING ERRCODE = '22023';
  END IF;

  v_settlement := COALESCE((v_terms->'settlement'->>'existing_balance_settled')::NUMERIC, 0);
  v_net := COALESCE((v_terms->'settlement'->>'net_amount_to_member')::NUMERIC, 0);

  -- ── Create the new loan (rule 4: a new record, never a mutation) ──────────
  v_new_ref := COALESCE(v_old.loan_id, v_old.id::text) || '-R' ||
               (COALESCE(v_old.rollover_count, 0) + 1)::text;

  INSERT INTO public.loans (
    loan_id, profile_id, loan_type, amount, original_principal, tenure_months, purpose,
    base_interest_rate, effective_interest_rate, monthly_repayment, total_repayment,
    remaining_balance, remaining_months, status, principal_repaid,
    parent_loan_id, is_rollover, rollover_count,
    monthly_contribution_at_application, approved_by, approved_at, created_at, updated_at
  ) VALUES (
    v_new_ref, v_old.profile_id, v_old.loan_type,
    p_requested_amount, p_requested_amount, p_new_tenure_months,
    COALESCE(v_old.purpose, 'Rollover of ' || COALESCE(v_old.loan_id, v_old.id::text)),
    v_old.base_interest_rate, v_old.effective_interest_rate,
    COALESCE((v_terms->>'monthly_repayment')::NUMERIC, 0),
    COALESCE((v_terms->>'total_repayment')::NUMERIC, 0),
    COALESCE((v_terms->>'total_repayment')::NUMERIC, 0),
    p_new_tenure_months, 'active', 0,
    v_old.id, TRUE, COALESCE(v_old.rollover_count, 0) + 1,
    v_old.monthly_contribution_at_application,
    p_admin_id, v_now, v_now, v_now
  ) RETURNING id INTO v_new_loan_id;

  -- ── Settle the old loan ───────────────────────────────────────────────────
  -- The refinance clears it, so it is closed as 'rolled_over' rather than left
  -- active with a stale balance.
  UPDATE public.loans
     SET status = 'rolled_over',
         remaining_balance = 0,
         remaining_months = 0,
         updated_at = v_now
   WHERE id = v_old.id;

  -- Record the settlement as a repayment on the old loan so the ledger and the
  -- principal position both reflect that it was paid off.
  INSERT INTO public.loan_repayments (
    loan_id, profile_id, amount, principal_component, interest_component,
    status, paid_at, reference, recorded_by, created_at, updated_at
  ) VALUES (
    v_old.id, v_old.profile_id, v_settlement,
    GREATEST(0, COALESCE((v_terms->'current'->>'outstanding_principal')::NUMERIC, 0)),
    GREATEST(0, v_settlement - COALESCE((v_terms->'current'->>'outstanding_principal')::NUMERIC, 0)),
    'paid', v_now, 'ROLLOVER-' || p_rollover_id::text, p_admin_id, v_now, v_now
  );

  -- ── Disburse only the net difference ──────────────────────────────────────
  IF v_net > 0 THEN
    UPDATE public.wallets
       SET balance = COALESCE(balance, 0) + v_net, updated_at = v_now
     WHERE profile_id = v_old.profile_id;

    INSERT INTO public.transactions (
      transaction_id, profile_id, type, category, amount, currency, status,
      payment_method, reference, description, completed_at, created_at,
      contribution_source, posted_by, metadata
    ) VALUES (
      'TXN-ROLLOVER-' || replace(gen_random_uuid()::text, '-', ''),
      v_old.profile_id, 'loan_disbursement', 'credit', v_net, 'NGN', 'completed',
      'wallet', 'ROLLOVER-' || p_rollover_id::text,
      format('Rollover disbursement: new loan %s less %s settled on %s',
             to_char(p_requested_amount, 'FM999,999,999,990.00'),
             to_char(v_settlement, 'FM999,999,999,990.00'),
             COALESCE(v_old.loan_id, v_old.id::text)),
      v_now, v_now, 'self_paid', p_admin_id,
      jsonb_build_object(
        'rollover_id', p_rollover_id,
        'new_loan_id', v_new_loan_id,
        'settled_loan_id', v_old.id,
        'new_loan_amount', p_requested_amount,
        'settlement_amount', v_settlement,
        'net_disbursed', v_net
      )
    );
  END IF;

  UPDATE public.rollovers
     SET applied_at = v_now,
         new_loan_id = v_new_loan_id,
         settled_loan_id = v_old.id,
         requested_tenure = p_new_tenure_months,
         previous_tenure_months = v_old.tenure_months,
         previous_remaining_balance = v_settlement,
         previous_monthly_repayment = v_old.monthly_repayment,
         reviewed_by = COALESCE(v_rollover.reviewed_by, p_admin_id),
         reviewed_at = COALESCE(v_rollover.reviewed_at, v_now),
         updated_at = v_now
   WHERE id = p_rollover_id;

  INSERT INTO public.audit_logs (
    action, target_model, target_id, metadata, actor_id, actor_role, details, created_at
  ) VALUES (
    'ROLLOVER_EXECUTED', 'loans', v_new_loan_id::text,
    jsonb_build_object(
      'rollover_id', p_rollover_id,
      'settled_loan', COALESCE(v_old.loan_id, v_old.id::text),
      'new_loan', v_new_ref,
      'new_loan_amount', p_requested_amount,
      'settlement_amount', v_settlement,
      'net_disbursed', v_net,
      'principal_repaid_at_rollover', COALESCE(v_old.principal_repaid, 0),
      'repayment_percentage', v_terms->'current'->>'repayment_percentage'
    ),
    p_admin_id, 'admin',
    jsonb_build_object(
      'summary', format('Rollover executed: %s settled, new loan %s of %s, net %s disbursed.',
        COALESCE(v_old.loan_id, v_old.id::text), v_new_ref,
        to_char(p_requested_amount, 'FM999,999,999,990.00'),
        to_char(v_net, 'FM999,999,999,990.00'))
    ),
    v_now
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'new_loan_id', v_new_loan_id,
    'new_loan_ref', v_new_ref,
    'settled_loan_id', v_old.id,
    'settlement_amount', v_settlement,
    'net_disbursed', v_net,
    'terms', v_terms
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.execute_loan_rollover(UUID, NUMERIC, INTEGER, UUID) IS
  'Executes an approved rollover as a refinance: creates a NEW loan, settles the old one, and disburses only the net difference to the member. Single-use.';

REVOKE ALL ON FUNCTION public.execute_loan_rollover(UUID, NUMERIC, INTEGER, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.execute_loan_rollover(UUID, NUMERIC, INTEGER, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.execute_loan_rollover(UUID, NUMERIC, INTEGER, UUID) FROM authenticated;
REVOKE ALL ON FUNCTION public.loan_rollover_terms(UUID, NUMERIC, INTEGER) FROM anon;
REVOKE ALL ON FUNCTION public.loan_rollover_eligibility(UUID) FROM anon;

-- ---------------------------------------------------------------------------
-- 7b. Repair the loans.status vocabulary
-- ---------------------------------------------------------------------------
-- Production's CHECK allows:
--   pending, under_review, approved, active, rejected, completed, defaulted,
--   in_recovery, cancelled
--
-- but the codebase uses three more that it therefore cannot write:
--
--   'overdue'      — `workers/loanRecoveryWorker.js` sets it in two places when
--                    a payment is missed (stage-1 reminder and stage-2 penalty).
--                    The constraint rejects it, and because those writes are not
--                    checked for error, overdue detection and the ₦3,000 late
--                    escalation fail SILENTLY: a loan never becomes overdue, so
--                    it is never escalated, and the penalty is never applied.
--   'repaying'     — read in several places (loan policy, repayment guard,
--                    rollover eligibility) but never writable.
--   'rolled_over'  — needed so a loan settled by a refinance is closed
--                    distinctly from one repaid in full.
--
-- Dropped and recreated with the union, following the same pattern that the
-- allocation_type constraint needed in migration 036 (and using a definition
-- match that actually works, unlike migration 021's `LIKE '%IN%'`).

DO $$
DECLARE
  v_conname TEXT;
BEGIN
  FOR v_conname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.loans'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE public.loans DROP CONSTRAINT %I', v_conname);
  END LOOP;
END $$;

ALTER TABLE public.loans
  ADD CONSTRAINT loans_status_check
  CHECK (status IN (
    'pending', 'under_review', 'approved', 'active', 'repaying',
    'overdue', 'defaulted', 'in_recovery',
    'completed', 'rejected', 'cancelled', 'rolled_over'
  ));

COMMENT ON CONSTRAINT loans_status_check ON public.loans IS
  'Superset of the values the code writes. Adds overdue/repaying/rolled_over, which the previous definition rejected — that silently broke the loan-recovery worker.';

-- ---------------------------------------------------------------------------
-- 8. Rollover columns this model needs
-- ---------------------------------------------------------------------------
ALTER TABLE public.rollovers
  ADD COLUMN IF NOT EXISTS new_loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS settled_loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS requested_amount NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS net_disbursed NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS settlement_amount NUMERIC(18,2);

COMMENT ON COLUMN public.rollovers.net_disbursed IS
  'Amount actually paid to the member: requested new loan less the balance it settled.';

-- Indexes for the chain and the eligibility lookups.
CREATE INDEX IF NOT EXISTS idx_loans_parent_loan ON public.loans (parent_loan_id);
CREATE INDEX IF NOT EXISTS idx_loans_profile_status ON public.loans (profile_id, status);
CREATE INDEX IF NOT EXISTS idx_loan_repayments_loan_status ON public.loan_repayments (loan_id, status);

-- 'rolled_over' joins the status vocabulary for a loan settled by a rollover.
COMMENT ON COLUMN public.loans.status IS
  'pending | approved | active | repaying | completed | rejected | cancelled | overdue | defaulted | in_recovery | rolled_over.';
