-- Migration 040: Apply the schema the code already expects
--
-- Found by auditing every table.column reference in the backend against the live
-- schema. The recurring pattern on this platform is code written against a
-- schema that was never applied — `settings`, `loans.total_repaid`,
-- `rollovers.approved_at` and the migration-020 CHECK constraint were all found
-- by hand, one at a time, each after a user-visible symptom.
--
-- This closes the rest of that class in one go. Each item below is a column the
-- code actively reads or writes today; every one was verified against
-- production with a rolled-back statement before being added here.

-- ---------------------------------------------------------------------------
-- 1. loans: the penalty columns the recovery worker writes
-- ---------------------------------------------------------------------------
-- `workers/loanRecoveryWorker.js` sets `penalty_applied` and `penalty_amount`
-- when a member misses a second consecutive month, and `routes/loans.js` does
-- the same for a manual penalty. Neither column exists, so both writes fail with
-- 42703 (verified). The worker's write is not error-checked, so the fine is
-- recorded in `member_fees` but the loan's penalty state never updates.

ALTER TABLE public.loans
  ADD COLUMN IF NOT EXISTS penalty_applied BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS penalty_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
  -- Selected by routes/user.js to total a member's outstanding loans and read by
  -- routes/loans.js for display; neither had a column.
  ADD COLUMN IF NOT EXISTS outstanding_balance NUMERIC(18,2),
  -- routes/guarantor.js selects it; the code already falls back to profile_id, so
  -- it is tolerant, but the reference is real and should resolve.
  ADD COLUMN IF NOT EXISTS borrower_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.loans.penalty_applied IS
  'True once a late-repayment penalty has been applied to this loan.';
COMMENT ON COLUMN public.loans.outstanding_balance IS
  'Convenience mirror of remaining_balance for reporting; remaining_balance stays the source of truth.';

-- Keep the mirror and the authoritative figure in step, so a report reading one
-- and a repayment writing the other cannot disagree.
CREATE OR REPLACE FUNCTION public.sync_loan_outstanding_balance()
RETURNS TRIGGER AS $$
BEGIN
  NEW.outstanding_balance := COALESCE(NEW.remaining_balance, NEW.amount);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_loan_outstanding_balance ON public.loans;
CREATE TRIGGER trg_sync_loan_outstanding_balance
  BEFORE INSERT OR UPDATE OF remaining_balance ON public.loans
  FOR EACH ROW EXECUTE FUNCTION public.sync_loan_outstanding_balance();

UPDATE public.loans
   SET outstanding_balance = COALESCE(remaining_balance, amount)
 WHERE outstanding_balance IS NULL;

-- ---------------------------------------------------------------------------
-- 2. loan_guarantors: the columns the guarantor routes read
-- ---------------------------------------------------------------------------
ALTER TABLE public.loan_guarantors
  ADD COLUMN IF NOT EXISTS guarantor_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS guarantor_name TEXT;

-- Backfill the name from the profile where the id is known.
UPDATE public.loan_guarantors lg
   SET guarantor_name = p.name
  FROM public.profiles p
 WHERE lg.guarantor_profile_id = p.id
   AND lg.guarantor_name IS NULL;

-- ---------------------------------------------------------------------------
-- 3. savings_goals: the columns the savings route writes
-- ---------------------------------------------------------------------------
-- `routes/savings.js` updates `saved_amount` after a deposit toward a goal and
-- reads `category`; neither existed, so a goal deposit updated nothing.
ALTER TABLE public.savings_goals
  ADD COLUMN IF NOT EXISTS saved_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS category TEXT;

-- ---------------------------------------------------------------------------
-- 4. tickets: `subject` and a profile relation
-- ---------------------------------------------------------------------------
-- `routes/adminPlatform.js` and `routes/adminTickets.js` select and filter on
-- `subject`; the tickets table has no such column, so those queries errored.
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS subject TEXT;

UPDATE public.tickets
   SET subject = COALESCE(subject, LEFT(COALESCE(description, 'Support request'), 120))
 WHERE subject IS NULL;

-- ---------------------------------------------------------------------------
-- 5. ticket_status_history: created_at and new_status
-- ---------------------------------------------------------------------------
ALTER TABLE public.ticket_status_history
  ADD COLUMN IF NOT EXISTS new_status TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ---------------------------------------------------------------------------
-- 6. watchlist: the columns the watchlist route writes
-- ---------------------------------------------------------------------------
ALTER TABLE public.watchlist
  ADD COLUMN IF NOT EXISTS target_id UUID,
  ADD COLUMN IF NOT EXISTS target_type TEXT,
  ADD COLUMN IF NOT EXISTS meta JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- 7. backup_snapshots.note
-- ---------------------------------------------------------------------------
ALTER TABLE public.backup_snapshots
  ADD COLUMN IF NOT EXISTS note TEXT;

-- ---------------------------------------------------------------------------
-- 8. transaction linkage columns
-- ---------------------------------------------------------------------------
-- `routes/admin.js` and `routes/adminApi.js` write `verified_by` / `verified_at`
-- when an admin confirms a payment, and read `deposit_request_id` to trace a
-- transaction back to the request it settles. None existed, so the
-- verification metadata was never recorded.
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deposit_request_id UUID REFERENCES public.deposit_requests(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_deposit_request
  ON public.transactions (deposit_request_id) WHERE deposit_request_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 9. audit_logs: no backfill possible, and that is correct
-- ---------------------------------------------------------------------------
-- Two routes wrote `actor_type`, which does not exist, and the error was
-- swallowed by a try/catch — so every payment-proof and KYC admin action was
-- missing from the audit trail. The code now writes `actor_role` (a real column).
--
-- The already-lost entries cannot be reconstructed: `audit_logs` carries a
-- `block_audit_log_mutation()` trigger that rejects UPDATE and DELETE, which is
-- exactly what an audit trail should do. I am not going to disable it to tidy up
-- history — an audit log you can rewrite is not an audit log. The gap is
-- recorded here instead, and entries are complete from this migration onward.

-- ---------------------------------------------------------------------------
-- 10. Tables the code references that do not exist
-- ---------------------------------------------------------------------------
-- `payroll_schedules` is read by `adminPlatform.js`'s payroll reconciliation,
-- which currently 500s with "relation does not exist". Slim, matching what the
-- code selects: profile_id, amount, status, organization_id.
CREATE TABLE IF NOT EXISTS public.payroll_schedules (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  profile_id      UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount          NUMERIC(18,2) NOT NULL DEFAULT 0,
  status          TEXT NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payroll_schedules_org
  ON public.payroll_schedules (organization_id, status);

COMMENT ON TABLE public.payroll_schedules IS
  'Expected monthly deduction per member per organisation, used by /api/admin/payroll/:orgId/reconciliation to compare expected against remitted.';

-- `announcements` backs the announcements route and the app's home banner. It is
-- absent, so the route errors rather than returning an empty list.
CREATE TABLE IF NOT EXISTS public.announcements (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  category     TEXT NOT NULL DEFAULT 'info',
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  audience     TEXT NOT NULL DEFAULT 'all',
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ,
  created_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_announcements_active
  ON public.announcements (is_active, published_at DESC);

-- `announcement_reads` tracks who has seen one.
CREATE TABLE IF NOT EXISTS public.announcement_reads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  profile_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  read_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (announcement_id, profile_id)
);

-- The Document Vault reads `documents`; absent, so the page always looked empty.
CREATE TABLE IF NOT EXISTS public.documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  doc_type     TEXT NOT NULL DEFAULT 'other',
  file_url     TEXT,
  file_size    BIGINT,
  status       TEXT NOT NULL DEFAULT 'available',
  uploaded_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documents_profile ON public.documents (profile_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.document_requests (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  doc_type     TEXT NOT NULL,
  reason       TEXT,
  status       TEXT NOT NULL DEFAULT 'pending',
  requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fulfilled_at TIMESTAMPTZ
);

-- Guarantor requests raised from the mobile app, read by the admin guarantor page.
CREATE TABLE IF NOT EXISTS public.guarantor_requests (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id              UUID REFERENCES public.loans(id) ON DELETE CASCADE,
  requester_profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  guarantor_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  guarantor_name       TEXT,
  guarantor_phone      TEXT,
  amount               NUMERIC(18,2),
  status               TEXT NOT NULL DEFAULT 'pending',
  responded_at         TIMESTAMPTZ,
  decline_reason       TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guarantor_requests_status
  ON public.guarantor_requests (status, created_at DESC);

-- Admin notes attached to a member or other record.
CREATE TABLE IF NOT EXISTS public.admin_notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  subject_type TEXT NOT NULL DEFAULT 'profile',
  subject_id   UUID,
  note         TEXT NOT NULL,
  created_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_notes_subject
  ON public.admin_notes (subject_type, subject_id, created_at DESC);

-- Next-of-kin, referenced by the KYC merge and member detail views.
CREATE TABLE IF NOT EXISTS public.next_of_kin (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name         TEXT,
  relationship TEXT,
  phone        TEXT,
  address      TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_next_of_kin_profile ON public.next_of_kin (profile_id);

-- ---------------------------------------------------------------------------
-- 11. RLS: new tables follow the same posture as the rest of the schema
-- ---------------------------------------------------------------------------
-- The backend uses the service-role key and bypasses RLS. These policies are
-- defence-in-depth so a member cannot read another member's rows through an
-- anon/authenticated client.
ALTER TABLE public.payroll_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guarantor_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.next_of_kin ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS announcements_read_all ON public.announcements;
CREATE POLICY announcements_read_all ON public.announcements
  FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS announcement_reads_own ON public.announcement_reads;
CREATE POLICY announcement_reads_own ON public.announcement_reads
  FOR SELECT USING (profile_id = auth.uid());

DROP POLICY IF EXISTS documents_own_read ON public.documents;
CREATE POLICY documents_own_read ON public.documents
  FOR SELECT USING (profile_id = auth.uid());

DROP POLICY IF EXISTS document_requests_own_read ON public.document_requests;
CREATE POLICY document_requests_own_read ON public.document_requests
  FOR SELECT USING (profile_id = auth.uid());

DROP POLICY IF EXISTS guarantor_requests_own_read ON public.guarantor_requests;
CREATE POLICY guarantor_requests_own_read ON public.guarantor_requests
  FOR SELECT USING (
    requester_profile_id = auth.uid() OR guarantor_profile_id = auth.uid()
  );

DROP POLICY IF EXISTS next_of_kin_own_read ON public.next_of_kin;
CREATE POLICY next_of_kin_own_read ON public.next_of_kin
  FOR SELECT USING (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 12. Align the new tables with the column names the code already uses
-- ---------------------------------------------------------------------------
-- The tables created above were shaped from what I read at the time; the audit
-- then showed the code expects different names in several places. Adding the
-- expected names (rather than rewriting every call site) keeps the existing code
-- working and avoids a second round of breakage.

ALTER TABLE public.documents
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS storage_path TEXT,
  ADD COLUMN IF NOT EXISTS document_type TEXT,
  ADD COLUMN IF NOT EXISTS mime_type TEXT;

UPDATE public.documents SET name = COALESCE(name, title) WHERE name IS NULL;

ALTER TABLE public.document_requests
  ADD COLUMN IF NOT EXISTS document_type TEXT,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

UPDATE public.document_requests SET document_type = COALESCE(document_type, doc_type) WHERE document_type IS NULL;

ALTER TABLE public.guarantor_requests
  ADD COLUMN IF NOT EXISTS guarantor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

UPDATE public.guarantor_requests SET guarantor_id = COALESCE(guarantor_id, guarantor_profile_id) WHERE guarantor_id IS NULL;

ALTER TABLE public.admin_notes
  ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

UPDATE public.admin_notes SET admin_id = COALESCE(admin_id, created_by) WHERE admin_id IS NULL;

-- ---------------------------------------------------------------------------
-- 13. Columns the rest of the codebase reads or writes
-- ---------------------------------------------------------------------------
-- Each verified absent against production. Grouped by the table they belong to.

ALTER TABLE public.rollovers
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- `savings` is an aggregate row (total_saved / monthly_savings); the savings
-- routes also read a balance and currency from it.
ALTER TABLE public.savings
  ADD COLUMN IF NOT EXISTS balance NUMERIC(18,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'NGN';

-- Keep `balance` mirroring `total_saved`, which is what the payment-proof
-- triggers maintain, so the two cannot drift.
UPDATE public.savings SET balance = COALESCE(NULLIF(balance, 0), total_saved);

ALTER TABLE public.loans
  ADD COLUMN IF NOT EXISTS recovery_initiated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS user_id TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS preferred_monthly_contribution NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS contribution_day INTEGER,
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS kyc_rejection_reason TEXT;

UPDATE public.profiles SET full_name = COALESCE(full_name, name) WHERE full_name IS NULL;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS body TEXT;

UPDATE public.notifications SET body = COALESCE(body, message) WHERE body IS NULL;

ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT;

UPDATE public.organizations
   SET is_active = (status = 'active')
 WHERE is_active IS DISTINCT FROM (status = 'active');

ALTER TABLE public.login_history
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS logout_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS browser TEXT,
  ADD COLUMN IF NOT EXISTS os TEXT,
  ADD COLUMN IF NOT EXISTS session_duration_seconds INTEGER;

ALTER TABLE public.referral_events
  ADD COLUMN IF NOT EXISTS lock_in_end_date TIMESTAMPTZ;

ALTER TABLE public.member_documents
  ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_member_documents_profile
  ON public.member_documents (profile_id, uploaded_at DESC);

-- ---------------------------------------------------------------------------
-- 14. RBAC: the tables already exist under different names
-- ---------------------------------------------------------------------------
-- `permissions` does not exist because the RBAC tables are `admin_permissions`
-- and `admin_roles`, with `role_permissions` joining them via `role_id` /
-- `permission_id` UUIDs. The audit flagged `permissions` as missing and
-- `role_permissions.roles` as a missing column — both are artefacts of reading
-- the code's naming rather than the schema's.
--
-- Nothing is created here: adding a `permissions` table would have duplicated
-- the catalogue and split the source of truth. The role routes read
-- `admin_permissions` / `admin_roles`, which already exist and are seeded.
COMMENT ON TABLE public.role_permissions IS
  'Joins admin_roles to admin_permissions. The permission catalogue lives in admin_permissions and the role list in admin_roles; there is no `permissions` table.';
