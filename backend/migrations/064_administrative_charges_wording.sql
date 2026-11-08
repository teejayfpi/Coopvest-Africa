-- Migration 064: rename the ₦1,000 administrative component
--
-- The ₦1,500 monthly administrative charge was published as "AGM levy (₦1,000)
-- + Development levy (₦500)". The ₦1,000 component is now published as
-- "Administrative charges". The amount is unchanged; only the name is.
--
-- Keyed on the old wording and idempotent, so re-running is a no-op and a
-- database already carrying the new wording is left untouched.
UPDATE public.fee_types
SET description = 'Monthly administrative charge covering Administrative charges (₦1,000) and the Development levy (₦500).',
    updated_at  = now()
WHERE name = 'Administrative Fee'
  AND description LIKE '%AGM levy%';
