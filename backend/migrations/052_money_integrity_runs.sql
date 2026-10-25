-- Migration 052: persist money-integrity reconciliation runs
--
-- `lib/moneyIntegrity.js` runs a fixed set of read-only checks that compare the
-- money tables that are supposed to agree (wallet balance vs the transaction
-- ledger, remaining_balance vs its outstanding mirror, duplicate settled
-- charges). The worker and the admin "run now" endpoint both persist their
-- result here, so a discrepancy has a queryable trail and the dashboard can
-- show when the last clean run was.
--
-- Nothing here moves money. A run only records what disagreed.

CREATE TABLE IF NOT EXISTS public.money_integrity_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- 'scheduled' (worker) or 'manual' (admin pressed Run now)
  trigger TEXT NOT NULL DEFAULT 'scheduled',
  ran_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  checks_run INTEGER NOT NULL DEFAULT 0,
  checks_errored INTEGER NOT NULL DEFAULT 0,
  discrepancies INTEGER NOT NULL DEFAULT 0,
  critical_checks TEXT[] NOT NULL DEFAULT '{}',
  warning_checks TEXT[] NOT NULL DEFAULT '{}',
  -- Full per-check result, including the sampled offending rows.
  results JSONB NOT NULL DEFAULT '[]'::jsonb,
  duration_ms INTEGER,
  triggered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_money_integrity_runs_ran_at
  ON public.money_integrity_runs(ran_at DESC);

-- Fast lookup of the most recent run that found anything, so the dashboard can
-- badge "last discrepancy" without scanning every clean run.
CREATE INDEX IF NOT EXISTS idx_money_integrity_runs_discrepancies
  ON public.money_integrity_runs(discrepancies, ran_at DESC);
