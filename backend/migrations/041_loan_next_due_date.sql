-- Migration 041: Maintain loans.next_due_date
--
-- `next_due_date` is read in three places to count and display overdue loans
-- (`adminPlatform.js`'s attention panel, and two blocks in `adminApi.js`), but
-- nothing ever WROTE it. Verified: no insert or update anywhere in either
-- backend sets the column, so every value is NULL and the comparison
-- `next_due_date < now()` could never match. The admin had no way to see an
-- overdue loan.
--
-- The repayment schedule logic already exists in `routes/loans.js`
-- (`dueDateForInstallment`): instalments fall on the 30th, the first on the 30th
-- of the application month unless the application was on/after the 30th. This
-- reproduces that rule in SQL so the column is maintained by the database and
-- cannot drift from the schedule the app renders.

-- ---------------------------------------------------------------------------
-- Next instalment due for a loan
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.loan_next_due_date(p_loan_id UUID)
RETURNS TIMESTAMPTZ AS $$
DECLARE
  v_loan        RECORD;
  v_tenure      INTEGER;
  v_monthly     NUMERIC(18,2);
  v_total       NUMERIC(18,2);
  v_remaining   NUMERIC(18,2);
  v_start       TIMESTAMPTZ;
  v_first_idx   INTEGER;
  v_paid        INTEGER;
  v_next_idx    INTEGER;
  v_year        INTEGER;
  v_month       INTEGER;
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_tenure := COALESCE(v_loan.tenure_months, 0);
  IF v_tenure <= 0 THEN RETURN NULL; END IF;

  v_monthly := COALESCE(v_loan.monthly_repayment, 0);
  v_total := COALESCE(v_loan.total_repayment, v_monthly * v_tenure);
  v_remaining := COALESCE(v_loan.remaining_balance, v_total);
  -- The loan starts at approval; `created_at` is the fallback the route uses.
  v_start := COALESCE(v_loan.approved_at, v_loan.created_at);

  IF v_start IS NULL THEN RETURN NULL; END IF;

  -- Same rule as the app's schedule: first instalment is the 30th of the
  -- application month, or of the following month when applying on/after the 30th.
  v_first_idx := CASE WHEN EXTRACT(DAY FROM v_start) < 30 THEN 0 ELSE 1 END;

  -- Instalments settled, derived from the balance the same way the schedule
  -- endpoint does it, so the two cannot disagree.
  v_paid := CASE
    WHEN v_monthly > 0 THEN
      LEAST(v_tenure, GREATEST(0, FLOOR((v_total - v_remaining) / v_monthly + 1e-6)))
    ELSE 0
  END;

  IF v_paid >= v_tenure THEN RETURN NULL; END IF;  -- fully repaid

  v_next_idx := v_first_idx + v_paid;

  v_year := EXTRACT(YEAR FROM v_start)::INTEGER;
  v_month := EXTRACT(MONTH FROM v_start)::INTEGER + v_next_idx;

  -- Normalise the month overflow into years.
  v_year := v_year + ((v_month - 1) / 12);
  v_month := ((v_month - 1) % 12) + 1;

  RETURN make_timestamptz(v_year, v_month, 30, 0, 0, 0, 'UTC');
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.loan_next_due_date(UUID) IS
  'The next instalment due date for a loan, using the same 30th-of-month rule as the app''s repayment schedule. NULL once the loan is fully repaid or the tenure is unknown.';

-- ---------------------------------------------------------------------------
-- Keep the column current
-- ---------------------------------------------------------------------------
/**
 * Keep `next_due_date` current on the row being written.
 *
 * Computed from NEW's own values rather than by calling
 * `loan_next_due_date(NEW.id)`: a BEFORE trigger runs before the update lands,
 * so re-reading the table would see the previous balance and leave a fully
 * repaid loan holding a due date.
 */
CREATE OR REPLACE FUNCTION public.sync_loan_next_due_date()
RETURNS TRIGGER AS $$
DECLARE
  v_tenure      INTEGER;
  v_monthly     NUMERIC(18,2);
  v_total       NUMERIC(18,2);
  v_remaining   NUMERIC(18,2);
  v_start       TIMESTAMPTZ;
  v_first_idx   INTEGER;
  v_paid        INTEGER;
  v_year        INTEGER;
  v_month       INTEGER;
BEGIN
  v_tenure := COALESCE(NEW.tenure_months, 0);
  IF v_tenure <= 0 THEN
    NEW.next_due_date := NULL;
    RETURN NEW;
  END IF;

  -- A loan that is no longer live has no next instalment.
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
    NEW.next_due_date := NULL;   -- fully repaid
    RETURN NEW;
  END IF;

  v_year := EXTRACT(YEAR FROM v_start)::INTEGER;
  v_month := EXTRACT(MONTH FROM v_start)::INTEGER + v_first_idx + v_paid;
  v_year := v_year + ((v_month - 1) / 12);
  v_month := ((v_month - 1) % 12) + 1;

  NEW.next_due_date := make_timestamptz(v_year, v_month, 30, 0, 0, 0, 'UTC');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recomputed whenever a loan's financial position changes.
DROP TRIGGER IF EXISTS trg_sync_loan_next_due_date ON public.loans;
CREATE TRIGGER trg_sync_loan_next_due_date
  BEFORE UPDATE OF remaining_balance, approved_at, tenure_months, status ON public.loans
  FOR EACH ROW EXECUTE FUNCTION public.sync_loan_next_due_date();

-- And after an approval, which is when a loan's clock actually starts.
DROP TRIGGER IF EXISTS trg_sync_loan_next_due_date_ins ON public.loans;
CREATE TRIGGER trg_sync_loan_next_due_date_ins
  BEFORE INSERT ON public.loans
  FOR EACH ROW EXECUTE FUNCTION public.sync_loan_next_due_date();

-- A repayment changes the balance, so recompute from the repayment side too.
CREATE OR REPLACE FUNCTION public.recompute_next_due_date_on_repayment()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.loan_id IS NULL THEN RETURN NEW; END IF;
  UPDATE public.loans
     SET next_due_date = public.loan_next_due_date(NEW.loan_id),
         updated_at = NOW()
   WHERE id = NEW.loan_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recompute_next_due_date ON public.loan_repayments;
CREATE TRIGGER trg_recompute_next_due_date
  AFTER INSERT OR UPDATE OF status ON public.loan_repayments
  FOR EACH ROW EXECUTE FUNCTION public.recompute_next_due_date_on_repayment();

-- ---------------------------------------------------------------------------
-- Backfill
-- ---------------------------------------------------------------------------
-- Covers live loans only: a closed loan has no next instalment.
UPDATE public.loans
   SET next_due_date = public.loan_next_due_date(id)
 WHERE status IN ('active', 'repaying', 'overdue')
   AND next_due_date IS DISTINCT FROM public.loan_next_due_date(id);

-- Supports the overdue queries that read this column.
CREATE INDEX IF NOT EXISTS idx_loans_next_due_date
  ON public.loans (next_due_date)
  WHERE status IN ('active', 'repaying', 'overdue');