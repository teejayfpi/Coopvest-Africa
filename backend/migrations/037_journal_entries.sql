-- Migration 037: Manual journal entries
--
-- Why this exists
-- ---------------
-- The Accounting page's "New Journal Entry" dialog posted to
-- `/api/admin/accounting/journal-entry`, which was never implemented — the
-- `/accounting` router exists only in the sibling backend and is not deployed
-- here, so the button failed every time.
--
-- The Accounting reports themselves were made to derive from the ledger, since
-- the server-side reports were unavailable. That means a manual journal entry has
-- to land where those reports actually read: `ledger_entries`, which
-- `GET /api/admin/ledger` unions with `transactions` (deduped by reference).
-- Posting here therefore shows up immediately in the trial balance, general
-- ledger, balance sheet and P&L.
--
-- The function enforces double-entry: every entry is a balanced set of lines
-- sharing one txn_no, so the trial balance cannot be broken by a manual post.

-- ---------------------------------------------------------------------------
-- Serialized transaction number
-- ---------------------------------------------------------------------------
-- Reuses `next_ledger_txn_no()` from migration 023 when present, so manual
-- entries join the same numbering sequence as every other ledger row rather than
-- introducing a second scheme. Falls back to a generated value if that function
-- is absent.

CREATE OR REPLACE FUNCTION public.post_journal_entry(
  p_txn_date    DATE,
  p_description TEXT,
  p_lines       JSONB,
  p_admin_id    UUID
)
RETURNS JSONB AS $$
DECLARE
  v_line        JSONB;
  v_txn_no      TEXT;
  v_total_debit NUMERIC(18,2) := 0;
  v_total_credit NUMERIC(18,2) := 0;
  v_posted      INTEGER := 0;
  v_admin_name  TEXT;
  v_lines       JSONB;
BEGIN
  -- ── Validate ──────────────────────────────────────────────────────────────
  IF p_description IS NULL OR length(btrim(p_description)) < 3 THEN
    RAISE EXCEPTION 'A description of at least 3 characters is required' USING ERRCODE = '22023';
  END IF;
  -- Tolerate a JSON-encoded array as well as a real one. Callers that pass
  -- `JSON.stringify(lines)` deliver a jsonb *string*, and rejecting that with
  -- "needs at least two lines" is misleading; decode it instead. `p_lines` is an
  -- IN parameter so the decoded copy lives in v_lines.
  v_lines := p_lines;
  IF v_lines IS NOT NULL AND jsonb_typeof(v_lines) = 'string' THEN
    BEGIN
      v_lines := (v_lines #>> '{}')::jsonb;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'lines must be a JSON array' USING ERRCODE = '22023';
    END;
  END IF;

  IF v_lines IS NULL OR jsonb_typeof(v_lines) <> 'array' OR jsonb_array_length(v_lines) < 2 THEN
    RAISE EXCEPTION 'A journal entry needs at least two lines' USING ERRCODE = '22023';
  END IF;

  -- Sum first so a bad entry is rejected before anything is written.
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_lines) LOOP
    IF COALESCE(v_line->>'account_code', '') = '' THEN
      RAISE EXCEPTION 'Every line requires an account_code' USING ERRCODE = '22023';
    END IF;
    v_total_debit  := v_total_debit  + COALESCE((v_line->>'debit')::NUMERIC, 0);
    v_total_credit := v_total_credit + COALESCE((v_line->>'credit')::NUMERIC, 0);
  END LOOP;

  IF ABS(v_total_debit - v_total_credit) > 0.01 THEN
    RAISE EXCEPTION 'Entry is unbalanced: debits % do not equal credits %',
      v_total_debit, v_total_credit USING ERRCODE = '22023';
  END IF;
  IF v_total_debit <= 0 THEN
    RAISE EXCEPTION 'A journal entry must move a non-zero amount' USING ERRCODE = '22023';
  END IF;

  -- ── Serial number ─────────────────────────────────────────────────────────
  BEGIN
    SELECT public.next_ledger_txn_no() INTO v_txn_no;
  EXCEPTION WHEN OTHERS THEN
    v_txn_no := 'JNL-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' ||
                UPPER(SUBSTRING(REPLACE(gen_random_uuid()::text, '-', '') FROM 1 FOR 6));
  END;

  SELECT name INTO v_admin_name FROM public.profiles WHERE id = p_admin_id;

  -- ─ Post every line under one txn_no ──────────────────────────────────────
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_lines) LOOP
    INSERT INTO public.ledger_entries (
      txn_no, txn_date, reference, type, description,
      account_code, account_name,
      debit, credit, amount, source, status,
      approved_by, initiated_by, created_at
    ) VALUES (
      v_txn_no,
      p_txn_date,
      v_txn_no,
      'journal_entry',
      btrim(p_description),
      v_line->>'account_code',
      -- Fall back to the code when a caller omits the name, so the ledger never
      -- shows a blank account.
      COALESCE(NULLIF(v_line->>'account_name', ''), v_line->>'account_code'),
      COALESCE((v_line->>'debit')::NUMERIC, 0),
      COALESCE((v_line->>'credit')::NUMERIC, 0),
      -- Signed amount in the house convention: debit positive, credit negative.
      COALESCE((v_line->>'debit')::NUMERIC, 0) - COALESCE((v_line->>'credit')::NUMERIC, 0),
      'admin-journal',
      'completed',
      p_admin_id,
      p_admin_id,
      NOW()
    );
    v_posted := v_posted + 1;
  END LOOP;

  -- ── Audit ────────────────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (
    action, target_model, target_id, metadata, actor_id, actor_role, details, created_at
  ) VALUES (
    'JOURNAL_ENTRY_POSTED', 'ledger_entries', NULL,
    jsonb_build_object(
      'txn_no', v_txn_no,
      'txn_date', p_txn_date,
      'description', p_description,
      'lines', v_lines,
      'total_debit', v_total_debit,
      'total_credit', v_total_credit,
      'posted_by', v_admin_name
    ),
    p_admin_id, 'admin',
    -- `audit_logs.details` is jsonb, so this must be an object, not a string.
    jsonb_build_object(
      'summary', 'Journal entry ' || v_txn_no || ': ' || btrim(p_description) ||
                 ' (' || v_total_debit::text || ' across ' || v_posted::text || ' lines)',
      'txn_no', v_txn_no,
      'total_debit', v_total_debit
    ),
    NOW()
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'txn_no', v_txn_no,
    'lines_posted', v_posted,
    'total_debit', v_total_debit,
    'total_credit', v_total_credit
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.post_journal_entry(DATE, TEXT, JSONB, UUID) IS
  'Posts a balanced manual journal entry into ledger_entries under one txn_no, so it appears in the derived trial balance, general ledger, balance sheet and P&L. Rejects an unbalanced or single-line entry.';

-- Narrow the grant: RLS still applies to other callers, and SECURITY DEFINER
-- means this runs with the owner's rights.
REVOKE ALL ON FUNCTION public.post_journal_entry(DATE, TEXT, JSONB, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.post_journal_entry(DATE, TEXT, JSONB, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.post_journal_entry(DATE, TEXT, JSONB, UUID) FROM authenticated;

-- Manual entries are looked up by their serial number; help the ledger list.
CREATE INDEX IF NOT EXISTS idx_ledger_entries_journal
  ON public.ledger_entries (txn_no) WHERE type = 'journal_entry';