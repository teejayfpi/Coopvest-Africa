-- Migration 055: rename the "Mobile App Fee" catalogue entry
--
-- The ₦1,500 monthly charge is the cooperative's administrative charge, made up
-- of the AGM levy (₦1,000) and the Development levy (₦500) — the same figures
-- AppConfig.totalMonthlyLevies has always carried. "Mobile App Fee" named the
-- delivery channel rather than the charge, so the admin catalogue now calls it
-- what it is.
--
-- Keyed on the old name and guarded against the new name already existing, so
-- re-running is a no-op and a database that has already been renamed is left
-- untouched (fee_types.name is UNIQUE).
UPDATE public.fee_types
SET name        = 'Administrative Fee',
    description = 'Monthly administrative charge covering the AGM levy (₦1,000) and the Development levy (₦500).',
    updated_at  = now()
WHERE name = 'Mobile App Fee'
  AND NOT EXISTS (
    SELECT 1 FROM public.fee_types WHERE name = 'Administrative Fee'
  );

-- member_fees.label is copied from the catalogue at assignment time, so rows
-- assigned before the rename keep the old wording. Relabel them so the member
-- and the admin see one consistent name. Display-only; no financial effect.
UPDATE public.member_fees
SET label      = 'Administrative Fee',
    updated_at = now()
WHERE label = 'Mobile App Fee';

-- The fee was switched off in the admin catalogue. The monthly administrative
-- charge is a standing obligation, so it is active. (Fee activity is driven by
-- whether an outstanding member_fees row exists; this flag drives the admin
-- catalogue and the member's "amount due" breakdown.)
UPDATE public.fee_types
SET is_active  = true,
    updated_at = now()
WHERE name = 'Administrative Fee' AND category = 'fee';
