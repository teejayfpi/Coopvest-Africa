-- ============================================================================
-- Coopvest Admin Platform — optional schema migration
-- ============================================================================
-- Run this in the Supabase SQL editor (Dashboard → SQL → New query) to enable
-- the persistent double-entry ledger. It is OPTIONAL: the admin API falls back
-- to a computed ledger view over the existing `transactions` table when
-- `ledger_entries` is absent.
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Financial Ledger (append-only double-entry)
-- ---------------------------------------------------------------------------
create table if not exists public.ledger_entries (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid references public.profiles(id) on delete set null,
  reference       text,
  type            text not null default 'adjustment',
  description     text,
  debit           numeric(14,2) not null default 0,
  credit          numeric(14,2) not null default 0,
  source          text not null default 'system',
  status          text not null default 'completed',
  initiated_by    uuid,
  -- Append-only reversal tracking: an entry is never deleted, only reversed.
  reversed        boolean not null default false,
  reversal_of     uuid,                       -- references the original entry id
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create index if not exists ledger_entries_profile_idx        on public.ledger_entries (profile_id, created_at desc);
create index if not exists ledger_entries_reference_idx      on public.ledger_entries (reference);
create index if not exists ledger_entries_reversal_of_idx    on public.ledger_entries (reversal_of);
create index if not exists ledger_entries_created_at_idx     on public.ledger_entries (created_at desc);

-- Enable Row Level Security; the Node backend uses the service role key
-- (which bypasses RLS), so no policy grants are required for API access.
alter table public.ledger_entries enable row level security;

-- ---------------------------------------------------------------------------
-- 2. Notification Templates (optional dedicated table)
-- ---------------------------------------------------------------------------
-- The admin API stores templates in `system_settings` under
-- `notification_template.*` so this table is not strictly required. It is
-- provided for teams that prefer a dedicated table for direct reporting.
create table if not exists public.notification_templates (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique,
  title       text,
  body        text,
  channels    jsonb not null default '{"push": true, "sms": false, "email": false}'::jsonb,
  enabled     boolean not null default true,
  updated_at  timestamptz not null default now()
);

create index if not exists notification_templates_key_idx on public.notification_templates (key);
alter table public.notification_templates enable row level security;

-- ---------------------------------------------------------------------------
-- 3. Loan Approval Matrix (optional dedicated table)
-- ---------------------------------------------------------------------------
-- Stored in `system_settings` under `loan_approval.thresholds` by the admin
-- API. This table is optional and provided for audit/reporting on its own.
create table if not exists public.loan_approval_thresholds (
  id          uuid primary key default gen_random_uuid(),
  level       int not null,
  max_amount  numeric(14,2) not null,
  role        text not null,
  updated_at  timestamptz not null default now()
);

alter table public.loan_approval_thresholds enable row level security;

-- ---------------------------------------------------------------------------
-- 4. Seed default emergency controls (all off) so the dashboard renders
-- ---------------------------------------------------------------------------
insert into public.system_settings (key, value, description)
values
  ('emergency.freeze_loans', false, 'Emergency freeze: new loan applications'),
  ('emergency.freeze_withdrawals', false, 'Emergency freeze: withdrawals'),
  ('emergency.freeze_registration', false, 'Emergency freeze: new registrations'),
  ('emergency.freeze_contribution_adjustments', false, 'Emergency freeze: contribution adjustments'),
  ('emergency.freeze_payment_proof_approval', false, 'Emergency freeze: payment proof approvals'),
  ('emergency.read_only', false, 'Emergency: read-only mode for the whole system'),
  ('emergency.force_logout_all', false, 'Emergency: force all admins to log out'),
  ('emergency.message', null, 'Public message shown during an emergency/maintenance'),
  ('emergency.updated_at', now()::timestamptz::text, 'Last emergency control change timestamp')
on conflict (key) do nothing;
