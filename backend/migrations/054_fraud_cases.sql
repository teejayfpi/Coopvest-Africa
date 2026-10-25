-- Migration 054: fraud/AML case management
--
-- The old "fraud detection" screen derived alerts on the fly, so an alert had no
-- identity: it could not be acknowledged, investigated, or dismissed, and the
-- same suspicion reappeared forever. `lib/fraudDetection.js` now raises findings
-- with a stable `dedupe_key`; this table is where they live between detection
-- and resolution.
--
-- A case is never an accusation and never moves money. It is a queue item for a
-- human, and its whole lifecycle is recorded here.

CREATE TABLE IF NOT EXISTS public.fraud_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Stable identity of the finding: re-detecting the same suspicion updates the
  -- existing case instead of creating a duplicate.
  dedupe_key TEXT NOT NULL UNIQUE,
  rule_id TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'warning' CHECK (severity IN ('info', 'warning', 'critical')),
  -- The member the finding is about, when there is one.
  profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  amount NUMERIC(18,2),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
  resolution_note TEXT,
  detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Bumped every time the scan re-finds this, so a case that keeps recurring is
  -- visible.
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  occurrences INTEGER NOT NULL DEFAULT 1,
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fraud_cases_status
  ON public.fraud_cases(status, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_fraud_cases_profile
  ON public.fraud_cases(profile_id);

CREATE INDEX IF NOT EXISTS idx_fraud_cases_severity_open
  ON public.fraud_cases(severity, detected_at DESC)
  WHERE status IN ('open', 'reviewing');
