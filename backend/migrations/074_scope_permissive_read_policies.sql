-- ---------------------------------------------------------------------------
-- 074  Replace six "any logged-in user can read everything" policies
-- ---------------------------------------------------------------------------
-- Six SELECT policies were bound to `authenticated` with a qual of `true`.
-- `true` means no row filter: every signed-in member could read every row.
-- They were almost certainly written as "service role can read" policies and
-- then bound to the wrong role - the backend uses the service-role key, which
-- bypasses RLS entirely, so these granted nothing the API needed.
--
-- Exposure at the time of writing (production is pre-launch):
--   organizations          411 rows, incl. remittance_account_number,
--                          contact_phone, notes, address
--   login_history          149 rows, incl. ip_address, session_id, user_agent
--   admin_audit_logs       0 rows (staff-only anyway)
--   approval_requests      0 rows, incl. previous_value / new_value
--   sensitive_actions_config  4 rows of approval config
--
-- No client reads any of these directly: the Flutter app uses Supabase for
-- `auth` and a realtime subscription on `notifications` only, and the
-- dashboard goes through the API. Verified with grep over both repos.
--
-- Replaced with self-scoped or staff-scoped policies. `is_staff()` is
-- SECURITY DEFINER and checks the caller's own profile row, so it is safe to
-- reference from a policy. Idempotent.

-- login_history: a member may read their own sign-in records; staff may read all.
DROP POLICY IF EXISTS "Authenticated can read" ON public.login_history;
DROP POLICY IF EXISTS "Authenticated users can read login history" ON public.login_history;
DROP POLICY IF EXISTS "login_history_self_select" ON public.login_history;
DROP POLICY IF EXISTS "login_history_staff_select" ON public.login_history;
CREATE POLICY "login_history_self_select" ON public.login_history
  FOR SELECT TO authenticated USING (profile_id = auth.uid());
CREATE POLICY "login_history_staff_select" ON public.login_history
  FOR SELECT TO authenticated USING (public.is_staff());

-- admin_audit_logs: staff only.
DROP POLICY IF EXISTS "authenticated_read_admin_audit_logs" ON public.admin_audit_logs;
DROP POLICY IF EXISTS "admin_audit_logs_staff_select" ON public.admin_audit_logs;
CREATE POLICY "admin_audit_logs_staff_select" ON public.admin_audit_logs
  FOR SELECT TO authenticated USING (public.is_staff());

-- approval_requests: only the initiator, the reviewer, or staff.
DROP POLICY IF EXISTS "authenticated_read_approval_requests" ON public.approval_requests;
DROP POLICY IF EXISTS "approval_requests_participant_select" ON public.approval_requests;
CREATE POLICY "approval_requests_participant_select" ON public.approval_requests
  FOR SELECT TO authenticated
  USING (initiated_by = auth.uid() OR reviewed_by = auth.uid() OR public.is_staff());

-- organizations: staff only - carries remittance bank account details.
DROP POLICY IF EXISTS "organizations_read" ON public.organizations;
DROP POLICY IF EXISTS "organizations_staff_select" ON public.organizations;
CREATE POLICY "organizations_staff_select" ON public.organizations
  FOR SELECT TO authenticated USING (public.is_staff());

-- sensitive_actions_config: staff only.
DROP POLICY IF EXISTS "authenticated_read_sensitive_actions_config" ON public.sensitive_actions_config;
DROP POLICY IF EXISTS "sensitive_actions_config_staff_select" ON public.sensitive_actions_config;
CREATE POLICY "sensitive_actions_config_staff_select" ON public.sensitive_actions_config
  FOR SELECT TO authenticated USING (public.is_staff());
