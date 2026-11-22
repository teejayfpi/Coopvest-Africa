-- ---------------------------------------------------------------------------
-- 076  Billing month on member_fees, so a monthly charge can only exist once
-- ---------------------------------------------------------------------------
-- The monthly administrative charge (NGN1,500 = NGN1,000 administrative
-- charges + NGN500 development levy) was published to members in the terms and
-- shown in the fee schedule, but nothing ever created the `member_fees` row it
-- is collected from. `computeObligations` only totals rows that exist, so the
-- charge was invisible in "amount due" for every member who had not been
-- assigned one by hand in the admin dashboard.
--
-- `monthlyAdministrativeFeeWorker` now bills it. That worker must be safe to
-- re-run: it ticks on a timer, restarts with the server, and may overlap on a
-- slow tick. Without a key, each run would insert another NGN1,500 obligation
-- and quietly multiply what a member owes.
--
-- `billing_month` ('YYYY-MM') is that key. It is nullable because every
-- existing row predates monthly billing - a one-off fine or registration fee
-- has no month and must not be constrained by one. The partial unique index
-- covers only rows that carry a month, so it cannot reject existing data.
ALTER TABLE public.member_fees
  ADD COLUMN IF NOT EXISTS billing_month TEXT;

-- One charge per member per fee type per month. Partial (billing_month IS NOT
-- NULL) so the many NULL rows are unaffected by uniqueness.
CREATE UNIQUE INDEX IF NOT EXISTS member_fees_billing_month_uniq
  ON public.member_fees (profile_id, fee_type_id, billing_month)
  WHERE billing_month IS NOT NULL;

COMMENT ON COLUMN public.member_fees.billing_month IS
  'YYYY-MM for charges billed once a month (monthly administrative fee). NULL for one-off fines and registration fees.';
