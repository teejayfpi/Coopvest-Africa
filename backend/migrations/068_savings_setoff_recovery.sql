-- Migration 068: recover a defaulted loan from savings
--
-- The last gap in default handling. `loanRecoveryWorker` escalates a default
-- through reminder -> penalty -> recovery, notifies the borrower, notifies the
-- guarantors, flags the admin dashboard, and then stops. Nothing ever collected.
-- Migration 065 held savings against a borrower's own loan and 067 extended the
-- hold to guarantees, but a hold only stops the member withdrawing; it does not
-- pay the debt.
--
-- This is the function that pays it. Given a loan in arrears it debits, in
-- order:
--
--   1. the borrower's own savings, in full, because it is their debt and that
--      money is already held against the loan by migration 065;
--   2. each guarantor's savings, capped at the `pledged_amount` they agreed to
--      at consent (migration 067), in consent order.
--
-- Nobody is charged more than they agreed to. A guarantor who pledged 83,334
-- contributes 83,334 at most, even if the loan is larger, and even if they have
-- more savings than that. Whatever remains after every source is exhausted is
-- returned as `shortfall` rather than invented from somewhere else.
--
-- Authority. `default_recovery_policy` clause 3 tells the member outstanding
-- balances "may be recovered from the member's contributions, savings, or
-- dividends", and `guarantor_requirement` clause 3 tells a guarantor they
-- "accept joint responsibility for the repayment of the guaranteed loan in the
-- event of default", with clause 4 ending that obligation on full repayment.
-- The published terms already provide for this; the code did not.
--
-- Notice. `p_notice_served` must be true. Taking money from a member's savings
-- without telling them first turns a recoverable arrears case into a complaint,
-- and the policy commits to recovery being possible, not to it being silent. The
-- caller is expected to have sent `setOffNotice` and waited out its period;
-- this flag records that it did, and the audit row preserves who said so.
--
-- Statuses. Only overdue, defaulted and in_recovery qualify. An active or
-- repaying loan is being serviced — its savings are already held by the lien,
-- and applying set-off there would take money from a member who is mid-term and
-- current.
--
-- Locking. The loan row is locked first, matching wallet_loan_repayment. Savings
-- rows are then locked in profile_id order, not plan order, so two concurrent
-- recoveries touching the same guarantor cannot deadlock; the debits are still
-- applied in plan order.
--
-- Idempotent: safe to re-run. Applying it twice replaces the function.
--
-- NOT listed in governanceSchema.js MIGRATIONS: like 065 and 067 this changes
-- what members may do with their own money, so it is applied deliberately after
-- sign-off rather than silently by the deploy bootstrap.

-- ---------------------------------------------------------------------------
-- 1. Track how much of each pledge has already been collected
-- ---------------------------------------------------------------------------
-- Without this, a second recovery run on a partly-covered loan would take
-- another full pledge's worth from each guarantor, because the cap would be
-- recomputed from `pledged_amount` as though nothing had been collected yet.
-- That would charge a guarantor far more than they agreed to. The cap is
-- therefore `pledged_amount - pledged_recovered`.
ALTER TABLE public.loan_guarantors
  ADD COLUMN IF NOT EXISTS pledged_recovered NUMERIC(18,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.loan_guarantors.pledged_recovered IS
  'Savings already collected from this guarantor against pledged_amount. Recovery is capped at pledged_amount - pledged_recovered.';

CREATE OR REPLACE FUNCTION public.loan_settle_from_savings(
  p_loan_id       UUID,
  p_admin_id      UUID,
  p_notice_served BOOLEAN
)
RETURNS JSONB AS $function$
DECLARE
  v_loan        public.loans;
  v_outstanding NUMERIC(18,2);
  v_remaining   NUMERIC(18,2);
  v_now         TIMESTAMPTZ := NOW();
  v_borrower    public.savings;
  v_guarantor   RECORD;
  v_savings     public.savings;
  v_take        NUMERIC(18,2);
  v_total       NUMERIC(18,2) := 0;
  v_steps       JSONB := '[]'::jsonb;
  v_new_status  TEXT;
BEGIN
  IF p_notice_served IS NOT TRUE THEN
    RAISE EXCEPTION 'Recovery from savings requires notice to have been served and its period to have elapsed'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Loan not found' USING ERRCODE = '23503';
  END IF;

  IF v_loan.status NOT IN ('overdue', 'defaulted', 'in_recovery') THEN
    RAISE EXCEPTION 'Savings recovery applies only to overdue, defaulted or in-recovery loans. Current status: %',
      v_loan.status USING ERRCODE = '22023';
  END IF;

  v_outstanding := COALESCE(v_loan.remaining_balance, v_loan.total_repayment, v_loan.amount, 0);
  IF v_outstanding <= 0 THEN
    RETURN jsonb_build_object('success', true, 'recovered', 0, 'shortfall', 0, 'steps', v_steps);
  END IF;

  -- Lock every savings row this recovery may touch, in profile_id order, before
  -- any of them is debited.
  PERFORM 1
    FROM public.savings
   WHERE profile_id IN (
           SELECT v_loan.profile_id
           UNION
           SELECT COALESCE(lg.guarantor_profile_id, lg.guarantor_id)
             FROM public.loan_guarantors lg
            WHERE lg.loan_id = p_loan_id
              AND lg.status = 'consented'
              AND lg.pledged_amount IS NOT NULL
         )
   ORDER BY profile_id
   FOR UPDATE;

  v_remaining := v_outstanding;

  -- 1. The borrower's own savings.
  SELECT * INTO v_borrower FROM public.savings WHERE profile_id = v_loan.profile_id;
  IF FOUND AND COALESCE(v_borrower.balance, 0) > 0 THEN
    v_take := LEAST(COALESCE(v_borrower.balance, 0), v_remaining);
    IF v_take > 0 THEN
      UPDATE public.savings
         SET balance = COALESCE(balance, 0) - v_take, updated_at = v_now
       WHERE id = v_borrower.id;

      INSERT INTO public.transactions (
        transaction_id, profile_id, reference, type, category, amount, status,
        description, payment_method, balance_before, balance_after, completed_at, loan_id
      ) VALUES (
        'TXN-' || gen_random_uuid(), v_loan.profile_id,
        'TXN-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || floor(random() * 10000)::text,
        'loan_repayment', 'debit', v_take, 'completed',
        'Recovery from savings for ' || COALESCE(v_loan.loan_id, v_loan.id::text),
        'savings', COALESCE(v_borrower.balance, 0), COALESCE(v_borrower.balance, 0) - v_take,
        v_now, p_loan_id
      );

      INSERT INTO public.loan_repayments (
        loan_id, profile_id, amount, principal_component, interest_component,
        paid_at, status, reference, recorded_by
      ) VALUES (
        p_loan_id, v_loan.profile_id, v_take,
        public.split_repayment_principal(v_take, v_loan.original_principal, v_loan.total_repayment),
        v_take - public.split_repayment_principal(v_take, v_loan.original_principal, v_loan.total_repayment),
        v_now, 'paid', 'SETOFF-' || left(p_loan_id::text, 8), p_admin_id
      );

      v_steps := v_steps || jsonb_build_object(
        'profileId', v_loan.profile_id, 'role', 'borrower', 'amount', v_take);
      v_total := v_total + v_take;
      v_remaining := v_remaining - v_take;
    END IF;
  END IF;

  -- 2. Guarantors, in consent order, each capped at their pledge.
  FOR v_guarantor IN
    SELECT COALESCE(lg.guarantor_profile_id, lg.guarantor_id) AS profile_id,
           lg.id AS guarantee_id,
           GREATEST(COALESCE(lg.pledged_amount, 0) - COALESCE(lg.pledged_recovered, 0), 0) AS available_pledge
      FROM public.loan_guarantors lg
     WHERE lg.loan_id = p_loan_id
       AND lg.status = 'consented'
       AND lg.pledged_amount IS NOT NULL
     ORDER BY lg.consented_at NULLS LAST, lg.id
  LOOP
    EXIT WHEN v_remaining <= 0;

    SELECT * INTO v_savings FROM public.savings WHERE profile_id = v_guarantor.profile_id;
    CONTINUE WHEN NOT FOUND;

    v_take := LEAST(COALESCE(v_savings.balance, 0), v_guarantor.available_pledge, v_remaining);
    CONTINUE WHEN v_take <= 0;

    UPDATE public.savings
       SET balance = COALESCE(balance, 0) - v_take, updated_at = v_now
     WHERE id = v_savings.id;

    UPDATE public.loan_guarantors
       SET pledged_recovered = COALESCE(pledged_recovered, 0) + v_take
     WHERE id = v_guarantor.guarantee_id;

    INSERT INTO public.transactions (
      transaction_id, profile_id, reference, type, category, amount, status,
      description, payment_method, balance_before, balance_after, completed_at, loan_id
    ) VALUES (
      'TXN-' || gen_random_uuid(), v_guarantor.profile_id,
      'TXN-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || floor(random() * 10000)::text,
      'loan_repayment', 'debit', v_take, 'completed',
      'Guarantor recovery from savings for ' || COALESCE(v_loan.loan_id, v_loan.id::text),
      'savings', COALESCE(v_savings.balance, 0), COALESCE(v_savings.balance, 0) - v_take,
      v_now, p_loan_id
    );

    INSERT INTO public.loan_repayments (
      loan_id, profile_id, amount, principal_component, interest_component,
      paid_at, status, reference, recorded_by
    ) VALUES (
      p_loan_id, v_guarantor.profile_id, v_take,
      public.split_repayment_principal(v_take, v_loan.original_principal, v_loan.total_repayment),
      v_take - public.split_repayment_principal(v_take, v_loan.original_principal, v_loan.total_repayment),
      v_now, 'paid', 'SETOFF-G-' || left(p_loan_id::text, 8), p_admin_id
    );

    v_steps := v_steps || jsonb_build_object(
      'profileId', v_guarantor.profile_id, 'role', 'guarantor', 'amount', v_take);
    v_total := v_total + v_take;
    v_remaining := v_remaining - v_take;
  END LOOP;

  v_new_status := CASE WHEN v_remaining <= 0 THEN 'completed' ELSE v_loan.status END;

  UPDATE public.loans
     SET remaining_balance = GREATEST(v_remaining, 0),
         principal_repaid = COALESCE(principal_repaid, 0)
           + public.split_repayment_principal(v_total, v_loan.original_principal, v_loan.total_repayment),
         status = v_new_status,
         updated_at = v_now
   WHERE id = p_loan_id;

  INSERT INTO public.loan_audit_log (loan_id, action, old_status, new_status, admin_id, notes)
  VALUES (
    p_loan_id,
    'SAVINGS_SETOFF',
    v_loan.status,
    v_new_status,
    p_admin_id,
    format('Recovered %s from savings across %s account(s); shortfall %s',
           v_total, jsonb_array_length(v_steps), GREATEST(v_remaining, 0))
  );

  RETURN jsonb_build_object(
    'success', true,
    'recovered', v_total,
    'shortfall', GREATEST(v_remaining, 0),
    'steps', v_steps,
    'status', v_new_status
  );
END $function$ LANGUAGE plpgsql SECURITY DEFINER;
