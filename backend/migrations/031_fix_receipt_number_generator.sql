-- ============================================================================
-- FIX: receipt-number generator serialization/boundary bug + data repair
--
-- Background
-- ----------
-- generate_receipt_number() previously parsed the sequence with
-- SUBSTRING(receipt_number FROM 4 FOR 6), which reads the YEAR plus the first
-- four sequence digits instead of the actual 6-digit sequence. This produced a
-- runaway number series:
--
--   RCP26000001 -> RCP26260001 -> RCP26262601 -> RCP26262627 -> (stuck)
--
-- Once RCP26262627 existed, every new approval computed the same next number
-- and failed with:
--   duplicate key value violates unique constraint
--   "digital_receipts_receipt_number_key"
--
-- This migration:
--   1. Rewrites the generator to parse the sequence from the last 6 chars.
--   2. Serializes concurrent calls with a transaction-level advisory lock.
--   3. Renumbers any malformed receipts already in the table (idempotent).
--
-- Note: the previous shape of the function is migrated to the corrected one;
-- this file is safe to re-run on an already-fixed database.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Correct receipt-number generator
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_receipt_number()
RETURNS TEXT AS $$
DECLARE
  receipt_num TEXT;
  year_part TEXT;
  seq_num INTEGER;
BEGIN
  year_part := to_char(NOW(), 'YY');

  -- Serialize concurrent approvals so the MAX(...)+1 lookup is race-free.
  PERFORM pg_advisory_xact_lock(hashtext('receipt_number_generator'));

  -- Sequence = the last 6 chars of the receipt number (positions 6-11).
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(receipt_number FROM 6 FOR 6) AS INTEGER)
  ), 0) + 1
  INTO seq_num
  FROM public.digital_receipts
  WHERE receipt_number LIKE 'RCP' || year_part || '%';

  receipt_num := 'RCP' || year_part || LPAD(seq_num::TEXT, 6, '0');

  RETURN receipt_num;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 2. Repair corrupted receipt numbers already in the table.
--    Order by created_at so numbering matches when each receipt was issued.
--    Idempotent: receipts that already match their slot are left untouched.
-- ---------------------------------------------------------------------------
WITH renumbered AS (
  SELECT
    id,
    receipt_number,
    row_number() OVER (ORDER BY created_at, id) AS seq
  FROM public.digital_receipts
),
updates AS (
  SELECT
    rn.id,
    rn.receipt_number AS old_number,
    'RCP' || to_char(NOW(), 'YY') || LPAD(rn.seq::TEXT, 6, '0') AS new_number
  FROM renumbered rn
),
changed AS (
  UPDATE public.digital_receipts d
  SET receipt_number = u.new_number,
      receipt_id     = 'RCP-' || SUBSTRING(u.new_number, 4, 8),
      updated_at     = NOW()
  FROM updates u
  WHERE d.id = u.id
    AND d.receipt_number != u.new_number
  RETURNING u.old_number, u.new_number
)
SELECT * FROM changed;