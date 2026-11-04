-- 012_super_admin_governance.sql
-- Super Admin governance infrastructure: approval workflow, security alerts,
-- login monitoring enrichment, and live admin monitoring.
-- Idempotent (IF NOT EXISTS) so it is safe to run on every deploy.

-- ─────────────────────────────────────────────────────────────────────────────
-- login_history: enrich if the table already exists (created outside this repo)
-- ─────────────────────────────────────────────────────────────────────────────
-- Defensive: only add columns that are missing. ALTER ... ADD COLUMN IF NOT EXISTS
-- is supported on Postgres 9.6+ (Supabase ships PG 15).
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS device_type TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS device_name TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS os TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS browser TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS app_version TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS ip_address TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS latitude NUMERIC(9,6);
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS longitude NUMERIC(9,6);
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS success BOOLEAN DEFAULT true;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS failure_reason TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS login_method TEXT DEFAULT 'password';
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS mfa_used BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS session_id TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS logout_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS session_duration_seconds INTEGER;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS isp TEXT;
ALTER TABLE IF EXISTS public.login_history ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_login_history_profile ON public.login_history(profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_history_success ON public.login_history(success, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_history_ip ON public.login_history(ip_address);

-- ─────────────────────────────────────────────────────────────────────────────
-- admin_approvals: role-based approval workflow
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_type TEXT NOT NULL,
  -- human-readable summary (e.g. "Approve loan LN-123 for NGN 500,000")
  title TEXT,
  -- JSON payload capturing the full proposed action + previous/new values
  payload JSONB DEFAULT '{}'::jsonb,
  previous_value JSONB,
  new_value JSONB,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled','executed')),
  requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  requested_by_role TEXT,
  reason TEXT,
  -- who approved/rejected
  decided_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  decided_by_role TEXT,
  decision_reason TEXT,
  decided_at TIMESTAMPTZ,
  -- threshold that triggered the approval (e.g. amount, policy key)
  threshold_value JSONB,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_approvals_status ON public.admin_approvals(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_approvals_requested_by ON public.admin_approvals(requested_by);

-- ─────────────────────────────────────────────────────────────────────────────
-- security_alerts: real-time security alerting
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.security_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('info','low','medium','high','critical')),
  title TEXT,
  description TEXT,
  -- the admin/profile the alert concerns
  profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  email TEXT,
  ip_address TEXT,
  location TEXT,
  device TEXT,
  -- 'unread' | 'read' | 'resolved' | 'dismissed'
  status TEXT NOT NULL DEFAULT 'unread' CHECK (status IN ('unread','read','resolved','dismissed')),
  -- channels this alert was sent through (array of strings)
  channels JSONB DEFAULT '[]'::jsonb,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_security_alerts_status ON public.security_alerts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_alerts_severity ON public.security_alerts(severity, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_alerts_profile ON public.security_alerts(profile_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- admin_activity: live admin monitoring (heartbeats + current page)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  email TEXT,
  current_page TEXT,
  current_module TEXT,
  last_action TEXT,
  ip_address TEXT,
  user_agent TEXT,
  device TEXT,
  -- a session is "online" if the last heartbeat was within this many seconds
  last_heartbeat TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_activity_profile ON public.admin_activity(profile_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_heartbeat ON public.admin_activity(last_heartbeat DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- security_settings: configurable security posture (single row)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.security_settings (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  two_factor_required BOOLEAN DEFAULT false,
  require_mfa_for_super_admin BOOLEAN DEFAULT true,
  session_timeout_minutes INT DEFAULT 30,
  max_login_attempts INT DEFAULT 5,
  password_expiry_days INT DEFAULT 90,
  ip_allowlist_enabled BOOLEAN DEFAULT false,
  allowed_ips JSONB DEFAULT '[]'::jsonb,
  blocked_ips JSONB DEFAULT '[]'::jsonb,
  block_suspicious_ips BOOLEAN DEFAULT true,
  alert_on_new_device BOOLEAN DEFAULT true,
  alert_on_new_country BOOLEAN DEFAULT true,
  alert_on_failed_logins BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.security_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS: allow service role (backend) full access. The dashboard reads via the
-- backend, so table-level access is mediated by the admin API, not RLS.
-- Use IF EXISTS so a missing table (e.g. partial apply) does not abort the run.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.admin_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.security_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.admin_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.security_settings ENABLE ROW LEVEL SECURITY;

-- Grant service role full access implicitly (service role bypasses RLS).
-- No additional GRANT needed for the service role.
