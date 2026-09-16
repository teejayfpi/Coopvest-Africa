-- Migration 035: Salary-based deduction contribution flow
--
-- Adds the schema the membership has needed since salary deduction was first
-- offered in the mobile app: partner-organisation remittance details, an
-- auditable per-member remittance batch, and provenance on the money tables so
-- a payroll-posted contribution is distinguishable from a self-paid one and can
-- be traced back to the batch it arrived in.
--
-- Additive and idempotent; safe to re-run. Nothing here drops or rewrites
-- existing member money.
--
-- Context discovered while writing this (recorded because it explains the
-- shape of the migration):
--   * `organizations` exists in production but WITHOUT the `deduction_type`,
--     `deduction_enabled` or `remittance_cycle` columns that
--     `routes/admin.js` has been writing to. Those writes therefore failed on
--     every call, which is why enabling deduction has never worked.
--   * There is no per-member remittance table at all, so `payroll_batches`
--     could hold a header row but nothing linking a contribution to it.
--   * Neither `transactions` nor `contributions` records where a contribution
--     came from, so a payroll-posted contribution is indistinguishable from an
--     in-app payment.
--   * `contributions` is empty even though approved monthly-contribution
--     payment proofs exist: the approval trigger inserts columns that were
--     missing, and its `exception when others` swallowed the error. Migration
--     033 added those columns; this migration additionally backfills the rows
--     that were lost so member history and contribution-months are correct
--     from the moment this ships.

-- ---------------------------------------------------------------------------
-- 1. Partner organisations: remittance details + deduction config
-- ---------------------------------------------------------------------------

ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS code TEXT,
  ADD COLUMN IF NOT EXISTS deduction_type TEXT NOT NULL DEFAULT 'manual_upload',
  ADD COLUMN IF NOT EXISTS deduction_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS remittance_cycle TEXT NOT NULL DEFAULT 'monthly',
  ADD COLUMN IF NOT EXISTS contact_name TEXT,
  ADD COLUMN IF NOT EXISTS contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS remittance_bank_name TEXT,
  ADD COLUMN IF NOT EXISTS remittance_account_number TEXT,
  ADD COLUMN IF NOT EXISTS remittance_account_name TEXT,
  ADD COLUMN IF NOT EXISTS remittance_reference_hint TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT;

-- Constrain the enum-ish columns without failing on legacy values.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'organizations_deduction_type_check'
  ) THEN
    ALTER TABLE public.organizations
      ADD CONSTRAINT organizations_deduction_type_check
      CHECK (deduction_type IN ('manual_upload', 'api'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'organizations_remittance_cycle_check'
  ) THEN
    ALTER TABLE public.organizations
      ADD CONSTRAINT organizations_remittance_cycle_check
      CHECK (remittance_cycle IN ('monthly', 'biweekly', 'quarterly', 'ad_hoc'));
  END IF;
END $$;

-- A code is the stable handle finance officers quote on remittance advice.
-- Only unique when present; legacy rows have none.
CREATE UNIQUE INDEX IF NOT EXISTS idx_organizations_code
  ON public.organizations (code) WHERE code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_organizations_deduction
  ON public.organizations (deduction_enabled) WHERE deduction_enabled = TRUE;

COMMENT ON COLUMN public.organizations.deduction_enabled IS
  'Whether this employer is currently remitting payroll deductions for its staff. The global switch in system_settings gates this further.';

-- ---------------------------------------------------------------------------
-- 2. Remittance batches: audit + reconciliation fields
-- ---------------------------------------------------------------------------
-- `payroll_batches` already exists and is populated by the batch list endpoint.
-- These columns let a batch carry the reference the organisation quoted, the
-- period it covers, who recorded it, and whether it reconciled.

ALTER TABLE public.payroll_batches
  ADD COLUMN IF NOT EXISTS batch_reference TEXT,
  ADD COLUMN IF NOT EXISTS recorded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS period_month TEXT,
  ADD COLUMN IF NOT EXISTS total_contribution_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_registration_fee_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reconciled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reconciled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS mismatch_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS note TEXT;

CREATE INDEX IF NOT EXISTS idx_payroll_batches_org_period
  ON public.payroll_batches (organization_id, period_month);

-- ---------------------------------------------------------------------------
-- 3. Per-member remittance lines — the missing link
-- ---------------------------------------------------------------------------
-- One row per member per month inside a batch. This is what makes the upload
-- reviewable before posting, postable atomically, and reconcilable afterwards.

CREATE TABLE IF NOT EXISTS public.payroll_batch_lines (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id              UUID NOT NULL REFERENCES public.payroll_batches(id) ON DELETE CASCADE,
  profile_id            UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

  -- What the organisation said each member identified as. Kept verbatim so a
  -- finance officer can see the raw row that produced a mismatch.
  raw_member_identifier TEXT,
  raw_row               JSONB NOT NULL DEFAULT '{}'::jsonb,

  contribution_month    TEXT NOT NULL,                 -- 'YYYY-MM'
  contribution_amount   NUMERIC(18, 2) NOT NULL DEFAULT 0,
  registration_fee_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

  -- Posted money, for tracing back from the member's statement.
  transaction_id        UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  fee_transaction_id    UUID REFERENCES public.transactions(id) ON DELETE SET NULL,

  status                TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'valid', 'invalid', 'posted', 'skipped', 'failed')),

  -- Populated by the validation pass so the preview screen can explain itself
  -- without re-deriving the rules client-side.
  validation_errors     JSONB NOT NULL DEFAULT '[]'::jsonb,
  post_error            TEXT,

  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- A member cannot be remitted twice for the same month in the same batch.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payroll_batch_lines_unique
  ON public.payroll_batch_lines (batch_id, profile_id, contribution_month)
  WHERE profile_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payroll_batch_lines_batch
  ON public.payroll_batch_lines (batch_id, status);

CREATE INDEX IF NOT EXISTS idx_payroll_batch_lines_profile_month
  ON public.payroll_batch_lines (profile_id, contribution_month);

COMMENT ON TABLE public.payroll_batch_lines IS
  'One row per member per month within an organisation remittance batch. Held as a draft until the batch is confirmed, then posted atomically.';

-- ---------------------------------------------------------------------------
-- 4. Contribution provenance on the money tables
-- ---------------------------------------------------------------------------
-- `transactions` is the audit anchor the ledger, wallet and reconciliation all
-- read, so provenance belongs there as well as on `contributions`. A real
-- column (rather than transactions.metadata) makes "show me every payroll
-- contribution last quarter" an indexed query instead of a JSON scan.

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS contribution_source TEXT NOT NULL DEFAULT 'self_paid',
  ADD COLUMN IF NOT EXISTS contribution_month TEXT,
  ADD COLUMN IF NOT EXISTS remittance_batch_id UUID REFERENCES public.payroll_batches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS posted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transactions_contribution_source_check'
  ) THEN
    ALTER TABLE public.transactions
      ADD CONSTRAINT transactions_contribution_source_check
      CHECK (contribution_source IN ('self_paid', 'salary_deduction', 'admin_manual', 'import'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_transactions_contribution_source
  ON public.transactions (contribution_source, contribution_month);

CREATE INDEX IF NOT EXISTS idx_transactions_remittance_batch
  ON public.transactions (remittance_batch_id) WHERE remittance_batch_id IS NOT NULL;

ALTER TABLE public.contributions
  ADD COLUMN IF NOT EXISTS contribution_source TEXT NOT NULL DEFAULT 'self_paid',
  ADD COLUMN IF NOT EXISTS remittance_batch_id UUID REFERENCES public.payroll_batches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS posted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'contributions_contribution_source_check'
  ) THEN
    ALTER TABLE public.contributions
      ADD CONSTRAINT contributions_contribution_source_check
      CHECK (contribution_source IN ('self_paid', 'salary_deduction', 'admin_manual', 'import'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_contributions_source
  ON public.contributions (profile_id, contribution_source, contribution_month);

COMMENT ON COLUMN public.transactions.contribution_source IS
  'How this contribution reached Coopvest: paid in-app, deducted from salary by an employer, entered manually by an admin, or imported in bulk.';
COMMENT ON COLUMN public.transactions.contribution_month IS
  'The contribution month this payment settles (YYYY-MM). Stored, not derived from created_at, so a payroll run posted late still attributes to the month it covers.';
COMMENT ON COLUMN public.contributions.contribution_source IS
  'Mirrors transactions.contribution_source so the member-facing history can state provenance without joining the money table.';

-- ---------------------------------------------------------------------------
-- 5. Registration-fee exemption for payroll members
-- ---------------------------------------------------------------------------
-- A salary-deduction member's registration fee is deducted from salary and
-- remitted with their contributions, so requiring them to pay it in-app before
-- their account activates is wrong. The exemption is DERIVED rather than
-- stored: a stored flag can drift out of sync with the contribution method,
-- whereas `contribution_method = 'payroll' AND organization_id IS NOT NULL`
-- cannot.
--
-- `registration_fee_paid = TRUE` is still honoured first, so once the payroll
-- remittance actually settles the fee we record the settlement properly instead
-- of relying on the exemption forever.

CREATE OR REPLACE FUNCTION public.member_registration_fee_settled(p public.profiles)
RETURNS BOOLEAN AS $$
  SELECT p.registration_fee_paid = TRUE
      OR (
        -- The app writes 'payroll' (settings screen) or 'salary_deduction'
        -- (KYC screen) depending on which flow the member came through; both
        -- mean the employer deducts at source.
        COALESCE(p.contribution_method, p.contribution_type) IN ('payroll', 'salary_deduction')
        AND p.organization_id IS NOT NULL
      );
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION public.member_registration_fee_settled(public.profiles) IS
  'True when the registration fee is settled, or when a salary-deduction member with an employer on file is exempt because their fee is recovered via payroll remittance. Used by the account-activation gate.';

-- ---------------------------------------------------------------------------
-- 6. Backfill lost contribution rows
-- ---------------------------------------------------------------------------
-- Approved monthly-contribution payment proofs never produced a `contributions`
-- row (missing columns + a swallowed exception), so `contributions` is empty
-- while members have real, approved savings. Without this, a member's
-- contribution history, contributed-month count and loan-eligibility score are
-- all wrong — and a payroll batch would post into the same void.
--
-- Reconstruct from approved proofs, which carry the member, amount and payment
-- date. Idempotent: `payment_proof_id` is the join key, and the insert is
-- guarded on NOT EXISTS so re-running never duplicates.

INSERT INTO public.contributions (
  profile_id, amount, status, contribution_month, payment_proof_id, notes,
  contribution_source
)
SELECT
  pp.profile_id,
  pp.amount,
  'successful',
  TO_CHAR(COALESCE(pp.payment_date, pp.created_at), 'YYYY-MM'),
  pp.id,
  'Backfilled from approved payment proof (migration 035)',
  'self_paid'
FROM public.payment_proofs pp
WHERE pp.payment_type = 'monthly_contribution'
  AND pp.status = 'approved'
  AND pp.deleted_at IS NULL
  AND pp.profile_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.contributions c WHERE c.payment_proof_id = pp.id
  );

-- Approved registration-fee proofs imply a settled fee. Migration 022 already
-- flips the flag; re-assert it here so a profile that missed the earlier
-- backfill is consistent with the exemption rule above.
UPDATE public.profiles p
SET registration_fee_paid = TRUE,
    registration_fee_paid_at = COALESCE(p.registration_fee_paid_at, pp.approved_at, NOW())
FROM public.payment_proofs pp
WHERE pp.profile_id = p.id
  AND pp.payment_type = 'registration_fee'
  AND pp.status = 'approved'
  AND pp.deleted_at IS NULL
  AND p.registration_fee_paid = FALSE;

-- ---------------------------------------------------------------------------
-- 7b. Employer approval-request fields on profiles
-- ---------------------------------------------------------------------------
-- `POST /api/v1/organizations/request-approval` records the employer a member
-- is waiting on. Without these columns the request had nowhere to live, which is
-- partly why the old call was a no-op, and there was no way to tell whether a
-- member had already asked.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS pending_organization_name TEXT,
  ADD COLUMN IF NOT EXISTS pending_organization_requested_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_pending_organization
  ON public.profiles (pending_organization_requested_at)
  WHERE pending_organization_name IS NOT NULL;

COMMENT ON COLUMN public.profiles.pending_organization_name IS
  'Employer a salary-deduction member has asked us to enrol. Cleared once the organisation exists and the member is linked to it.';

-- ---------------------------------------------------------------------------
-- 8. Atomic batch posting
-- ---------------------------------------------------------------------------
-- Posts every validated line of a batch in ONE transaction. Either the whole
-- remittance lands or none of it does — a partially-posted payroll run would
-- leave member balances that reconcile against nothing.

CREATE OR REPLACE FUNCTION public.post_payroll_batch(p_batch_id UUID, p_admin_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_batch        RECORD;
  v_line         RECORD;
  v_txn_id       UUID;
  v_fee_txn_id   UUID;
  v_paid_count   INTEGER := 0;
  v_fee_count    INTEGER := 0;
  v_errors       JSONB := '[]'::jsonb;
  v_txn_no       TEXT;
BEGIN
  SELECT * INTO v_batch FROM public.payroll_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Batch % not found', p_batch_id;
  END IF;

  IF v_batch.status = 'posted' THEN
    RAISE EXCEPTION 'Batch % has already been posted', p_batch_id;
  END IF;

  -- Post the contribution lines.
  FOR v_line IN
    SELECT * FROM public.payroll_batch_lines
    WHERE batch_id = p_batch_id AND status = 'valid' AND contribution_amount > 0
    ORDER BY id
  LOOP
    BEGIN
      v_txn_no := 'TXN-PAYROLL-' || replace(gen_random_uuid()::text, '-', '');

      INSERT INTO public.transactions (
        transaction_id, profile_id, type, category, amount, currency, status,
        payment_method, reference, description, completed_at,
        contribution_source, contribution_month, remittance_batch_id, posted_by, metadata
      ) VALUES (
        v_txn_no, v_line.profile_id, 'deposit', 'credit', v_line.contribution_amount,
        'NGN', 'completed', 'salary_deduction',
        COALESCE(v_batch.batch_reference, p_batch_id::text),
        'Salary deduction contribution' ||
          CASE WHEN v_batch.period_month IS NOT NULL
               THEN ' for ' || v_batch.period_month ELSE '' END,
        COALESCE(v_batch.remitted_at, NOW()),
        'salary_deduction', v_line.contribution_month, p_batch_id, p_admin_id,
        jsonb_build_object('source', 'salary_deduction', 'batch_id', p_batch_id)
      ) RETURNING id INTO v_txn_id;

      -- Mirror into `contributions` so member history, contributed-month count
      -- and risk scoring all see it. This is the write the old admin manual
      -- path was missing.
      INSERT INTO public.contributions (
        profile_id, amount, status, contribution_month, notes,
        contribution_source, remittance_batch_id, posted_by
      ) VALUES (
        v_line.profile_id, v_line.contribution_amount, 'successful',
        v_line.contribution_month,
        'Salary deduction via employer remittance',
        'salary_deduction', p_batch_id, p_admin_id
      );

      UPDATE public.payroll_batch_lines
      SET transaction_id = v_txn_id, status = 'posted', updated_at = NOW()
      WHERE id = v_line.id;

      v_paid_count := v_paid_count + 1;
    EXCEPTION WHEN OTHERS THEN
      -- Record the failure on the line, then abort the whole batch. A silent
      -- partial post is the failure mode this function exists to prevent.
      UPDATE public.payroll_batch_lines
      SET status = 'failed', post_error = SQLERRM, updated_at = NOW()
      WHERE id = v_line.id;
      RAISE EXCEPTION 'Batch % aborted on line %: %', p_batch_id, v_line.id, SQLERRM;
    END;
  END LOOP;

  -- Registration fees recovered through the same remittance.
  FOR v_line IN
    SELECT * FROM public.payroll_batch_lines
    WHERE batch_id = p_batch_id AND status = 'valid' AND registration_fee_amount > 0
    ORDER BY id
  LOOP
    BEGIN
      v_txn_no := 'TXN-PAYROLL-FEE-' || replace(gen_random_uuid()::text, '-', '');

      INSERT INTO public.transactions (
        transaction_id, profile_id, type, category, amount, currency, status,
        payment_method, reference, description, completed_at,
        contribution_source, contribution_month, remittance_batch_id, posted_by, metadata
      ) VALUES (
        v_txn_no, v_line.profile_id, 'fee', 'credit', v_line.registration_fee_amount,
        'NGN', 'completed', 'salary_deduction',
        COALESCE(v_batch.batch_reference, p_batch_id::text),
        'Registration fee recovered via salary deduction',
        COALESCE(v_batch.remitted_at, NOW()),
        'salary_deduction', v_line.contribution_month, p_batch_id, p_admin_id,
        jsonb_build_object('source', 'salary_deduction', 'batch_id', p_batch_id, 'fee', 'registration_fee')
      ) RETURNING id INTO v_fee_txn_id;

      -- Settle the fee flag, which also clears the exemption and satisfies the
      -- activation gate on its own merits from here on.
      UPDATE public.profiles
      SET registration_fee_paid = TRUE,
          registration_fee_paid_at = COALESCE(registration_fee_paid_at, NOW())
      WHERE id = v_line.profile_id AND registration_fee_paid = FALSE;

      UPDATE public.payroll_batch_lines
      SET fee_transaction_id = v_fee_txn_id, updated_at = NOW()
      WHERE id = v_line.id;

      v_fee_count := v_fee_count + 1;
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.payroll_batch_lines
      SET status = 'failed', post_error = SQLERRM, updated_at = NOW()
      WHERE id = v_line.id;
      RAISE EXCEPTION 'Batch % aborted on fee line %: %', p_batch_id, v_line.id, SQLERRM;
    END;
  END LOOP;

  UPDATE public.payroll_batches
  SET status = 'posted',
      matched_count = v_paid_count,
      record_count = (SELECT COUNT(*) FROM public.payroll_batch_lines WHERE batch_id = p_batch_id),
      updated_at = NOW()
  WHERE id = p_batch_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'posted', v_paid_count,
    'fees_posted', v_fee_count,
    'errors', v_errors
  );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.post_payroll_batch(UUID, UUID) IS
  'Posts every validated line of a remittance batch atomically, writing both transactions and contributions with salary_deduction provenance. Any line failure aborts the entire batch.';

-- Keep updated_at current on batch lines.
CREATE OR REPLACE FUNCTION public.touch_payroll_batch_lines()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payroll_batch_lines_updated_at ON public.payroll_batch_lines;
CREATE TRIGGER trg_payroll_batch_lines_updated_at
  BEFORE UPDATE ON public.payroll_batch_lines
  FOR EACH ROW EXECUTE FUNCTION public.touch_payroll_batch_lines();

-- ---------------------------------------------------------------------------
-- 8. Row-Level Security
-- ---------------------------------------------------------------------------
-- The backend uses the service-role key and bypasses RLS, so API access is
-- unaffected. These policies are defence-in-depth for any anon/authenticated
-- client: a member must never be able to read another member's remittance line.

ALTER TABLE public.payroll_batch_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payroll_batch_lines_admin_all ON public.payroll_batch_lines;
CREATE POLICY payroll_batch_lines_admin_all ON public.payroll_batch_lines
  FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS payroll_batch_lines_own_read ON public.payroll_batch_lines;
CREATE POLICY payroll_batch_lines_own_read ON public.payroll_batch_lines
  FOR SELECT USING (profile_id = auth.uid());
