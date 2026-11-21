-- Migration 069: stop the due-date functions crashing on February
--
-- Migration 041 fixed instalments to the 30th of each month:
--
--   RETURN make_timestamptz(v_year, v_month, 30, 0, 0, 0, 'UTC');
--
-- February has no 30th. Any loan whose next instalment falls in February raises
-- `date field value out of range: 2027-02-30` from inside a BEFORE UPDATE
-- trigger on `public.loans`, which aborts the whole statement. In practice that
-- means a member cannot repay a February instalment at all, and an admin cannot
-- update the loan. It is not a display glitch: the write fails.
--
-- The JavaScript has always done this correctly. `dueDateForInstallment` in
-- routes/loans.js clamps to the last day of the month:
--
--   const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
--   return new Date(Date.UTC(year, month, Math.min(30, lastDay)));
--
-- So the app tells the member their February instalment is due on the 28th
-- while the database refuses to record it. This migration makes SQL agree with
-- the JS rather than inventing a third rule: the 30th where the month has one,
-- otherwise the last day. February becomes the 28th, or the 29th in a leap year.
--
-- Both functions from 041 are recreated. `loan_next_due_date` is STABLE and
-- reads a loan; `sync_loan_next_due_date` is the trigger body. They duplicate
-- the arithmetic deliberately — keep them in step, as 041 did.
--
-- Idempotent: CREATE OR REPLACE, safe to re-run.
--
-- NOT in governanceSchema.js MIGRATIONS. This changes when members' instalments
-- fall due, so it is applied deliberately. It is a bug fix rather than a policy
-- change: the app has been promising the clamped date all along.

CREATE OR REPLACE FUNCTION public.loan_next_due_date(p_loan_id UUID)
RETURNS TIMESTAMPTZ AS $function$
DECLARE
  v_loan      public.loans;
  v_tenure    INTEGER;
  v_monthly   NUMERIC(18,2);
  v_total     NUMERIC(18,2);
  v_remaining NUMERIC(18,2);
  v_start     TIMESTAMPTZ;
  v_first_idx INTEGER;
  v_paid      INTEGER;
  v_next_idx  INTEGER;
  v_year      INTEGER;
  v_month     INTEGER;
  v_last_day  INTEGER;
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_tenure := COALESCE(v_loan.tenure_months, 0);
  IF v_tenure <= 0 THEN RETURN NULL; END IF;
  IF COALESCE(v_loan.status, '') IN ('completed', 'cancelled', 'rejected', 'rolled_over') THEN
    RETURN NULL;
  END IF;

  v_monthly := COALESCE(v_loan.monthly_repayment, 0);
  v_total := COALESCE(v_loan.total_repayment, v_monthly * v_tenure);
  v_remaining := COALESCE(v_loan.remaining_balance, v_total);
  v_start := COALESCE(v_loan.approved_at, v_loan.created_at);

  IF v_start IS NULL THEN RETURN NULL; END IF;

  v_first_idx := CASE WHEN EXTRACT(DAY FROM v_start) < 30 THEN 0 ELSE 1 END;

  v_paid := CASE
    WHEN v_monthly > 0 THEN
      LEAST(v_tenure, GREATEST(0, FLOOR((v_total - v_remaining) / v_monthly + 1e-6)))
    ELSE 0
  END;

  IF v_paid >= v_tenure THEN RETURN NULL; END IF;

  v_next_idx := v_first_idx + v_paid;

  v_year := EXTRACT(YEAR FROM v_start)::INTEGER;
  v_month := EXTRACT(MONTH FROM v_start)::INTEGER + v_next_idx;
  v_year := v_year + ((v_month - 1) / 12);
  v_month := ((v_month - 1) % 12) + 1;

  -- The 30th, or the last day of a shorter month.
  v_last_day := EXTRACT(DAY FROM (
    make_date(v_year, v_month, 1) + INTERVAL '1 month' - INTERVAL '1 day'
  ))::INTEGER;

  RETURN make_timestamptz(v_year, v_month, LEAST(30, v_last_day), 0, 0, 0, 'UTC');
END;
$function$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.loan_next_due_date(UUID) IS
  'The next instalment due date for a loan: the 30th of the month, or the last day where the month is shorter (February becomes the 28th, or the 29th in a leap year). NULL once repaid or the tenure is unknown.';

CREATE OR REPLACE FUNCTION public.sync_loan_next_due_date()
RETURNS TRIGGER AS $function$
DECLARE
  v_tenure    INTEGER;
  v_monthly   NUMERIC(18,2);
  v_total     NUMERIC(18,2);
  v_remaining NUMERIC(18,2);
  v_start     TIMESTAMPTZ;
  v_first_idx INTEGER;
  v_paid      INTEGER;
  v_year      INTEGER;
  v_month     INTEGER;
  v_last_day  INTEGER;
BEGIN
  v_tenure := COALESCE(NEW.tenure_months, 0);
  IF v_tenure <= 0 THEN
    NEW.next_due_date := NULL;
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.status, '') IN ('completed', 'cancelled', 'rejected', 'rolled_over') THEN
    NEW.next_due_date := NULL;
    RETURN NEW;
  END IF;

  v_monthly := COALESCE(NEW.monthly_repayment, 0);
  v_total := COALESCE(NEW.total_repayment, v_monthly * v_tenure);
  v_remaining := COALESCE(NEW.remaining_balance, v_total);
  v_start := COALESCE(NEW.approved_at, NEW.created_at);

  IF v_start IS NULL THEN
    NEW.next_due_date := NULL;
    RETURN NEW;
  END IF;

  v_first_idx := CASE WHEN EXTRACT(DAY FROM v_start) < 30 THEN 0 ELSE 1 END;

  v_paid := CASE
    WHEN v_monthly > 0 THEN
      LEAST(v_tenure, GREATEST(0, FLOOR((v_total - v_remaining) / v_monthly + 1e-6)))
    ELSE 0
  END;

  IF v_paid >= v_tenure THEN
    NEW.next_due_date := NULL;
    RETURN NEW;
  END IF;

  v_year := EXTRACT(YEAR FROM v_start)::INTEGER;
  v_month := EXTRACT(MONTH FROM v_start)::INTEGER + v_first_idx + v_paid;
  v_year := v_year + ((v_month - 1) / 12);
  v_month := ((v_month - 1) % 12) + 1;

  v_last_day := EXTRACT(DAY FROM (
    make_date(v_year, v_month, 1) + INTERVAL '1 month' - INTERVAL '1 day'
  ))::INTEGER;

  NEW.next_due_date := make_timestamptz(v_year, v_month, LEAST(30, v_last_day), 0, 0, 0, 'UTC');
  RETURN NEW;
END;
$function$ LANGUAGE plpgsql;

-- Repair any row whose stored date is wrong or was never set because a February
-- write had failed. The trigger is `BEFORE UPDATE OF remaining_balance, ...`, so
-- it only fires when one of those columns is named in SET — assigning
-- `updated_at = updated_at` alone would not re-run it. `remaining_balance` is
-- named (and given its own value) purely to fire the trigger.
UPDATE public.loans
   SET remaining_balance = remaining_balance
 WHERE status NOT IN ('completed', 'cancelled', 'rejected', 'rolled_over')
   AND tenure_months > 0;
