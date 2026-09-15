-- 034_registration_fee_wallet_credit_repair.sql
--
-- Fixes wallet balances inflated by the Paystack allocation bug in
-- POST /api/v1/payments/initialize.
--
-- Root cause: an activation-screen payment posts only
--   { amount, payment_type: 'registration_fee' }
-- with no allocation_type. normalizeAllocations() defaulted an unmatched
-- type to `{ type: 'savings' }`, so every registration-fee charge was ALSO
-- credited to the member's wallet as savings. The same default mislabelled
-- loan repayments as savings in `payment_proofs.metadata` (e.g. ₦100,000
-- loan repayments stored as `[{"type":"savings","amount":100000}]`).
--
-- 1. Correct the stored allocation breakdown so the books describe what the
--    money actually settled (registration_fee proofs → registration_fee;
--    loan_repayment proofs → loan_repayment).
-- 2. Debit the wallet for every mislabelled savings credit that was actually
--    applied (only `approved` proofs credit a wallet), clamped at zero so a
--    balance can never go negative.
--
-- Idempotent: the metadata rewrite is a no-op once applied, and the balance
-- repair is keyed off the `savings` allocation which step 1 removes, so a
-- re-run cannot debit twice.

-- ---------------------------------------------------------------------------
-- 1. Reverse the wallet credits the mislabelled proofs created. This MUST run
--    before the metadata rewrite below (which removes the evidence).
--    Only `approved` proofs ever credited a wallet.
-- ---------------------------------------------------------------------------
with overcredited as (
  select pp.profile_id,
         sum((a->>'amount')::numeric) as amount
  from public.payment_proofs pp
  cross join lateral jsonb_array_elements(pp.metadata->'allocations') a
  where pp.status = 'approved'
    and a->>'type' = 'savings'
    and coalesce(pp.metadata->>'allocation_type', '') <> 'monthly_contribution'
    and pp.payment_type in ('registration_fee', 'loan_repayment')
  group by pp.profile_id
)
update public.wallets w
set balance = greatest(0, w.balance - o.amount),
    last_updated = now(),
    updated_at = now()
from overcredited o
where w.profile_id = o.profile_id
  and o.amount > 0;

-- ---------------------------------------------------------------------------
-- 2. Rewrite the mislabelled allocation breakdowns so the books describe what
--    the money actually settled.
-- ---------------------------------------------------------------------------
update public.payment_proofs pp
set metadata = jsonb_set(
      pp.metadata,
      '{allocations}',
      jsonb_build_array(
        jsonb_build_object('type', pp.payment_type, 'amount', pp.amount)
      )
    )
where pp.metadata ? 'allocations'
  and pp.metadata->'allocations' @> '[{"type":"savings"}]'::jsonb
  and coalesce(pp.metadata->>'allocation_type', '') <> 'monthly_contribution'
  and pp.payment_type in ('registration_fee', 'loan_repayment');