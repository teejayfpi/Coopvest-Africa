-- Migration 059: harden row-level security and column grants
--
-- Audit of the live database (project nyoauzqezpxeonmrxxgi) found three classes
-- of exposure, all reachable with the public anon key that ships inside the
-- mobile app and the admin dashboard:
--
--   1. `profiles` granted table-level UPDATE to anon and authenticated, so any
--      signed-in member could set their own `role`, `kyc_verified`,
--      `permissions` or `access_level`. `is_staff()` trusts `profiles.role`,
--      which made that a direct route to administrator.
--   2. 25 policies meant for the service role were applied to PUBLIC. The
--      service role bypasses RLS, so they gave the backend nothing and gave
--      everyone else everything.
--   3. 21 tables had RLS switched off while still granting write access to anon
--      and authenticated.
--
-- Why this is safe for the applications:
--   * the backend connects with the service role, which bypasses RLS;
--   * the mobile app performs no direct database access (auth only);
--   * the admin dashboard reads only its own `profiles` row and writes only
--     its own name/phone/department — both preserved below.

-- ---------------------------------------------------------------------------
-- 1. Members may edit their own details, but not their privileges
-- ---------------------------------------------------------------------------
-- The UPDATE privilege is held at table level, so a column-level REVOKE on its
-- own would be silently ineffective. Revoke the table privilege, then grant
-- back only the columns a member is allowed to change.
REVOKE UPDATE ON public.profiles FROM anon, authenticated;
GRANT UPDATE (
  name,
  full_name,
  phone,
  address,
  gender,
  date_of_birth,
  state,
  lga,
  occupation,
  employer_name,
  employment_type,
  employer_staff_id,
  work_address,
  years_of_employment,
  monthly_amount,
  contribution_method,
  preferred_payment_day,
  contribution_day,
  contribution_type,
  preferred_monthly_contribution,
  nok_name,
  nok_relationship,
  nok_phone,
  nok_address,
  avatar_url,
  profile_picture,
  selfie_url,
  id_document_url,
  id_type,
  id_number,
  department,
  updated_at,
  salary_deduction_consent,
  salary_deduction_consent_date,
  registration_completed,
  completed_at,
  kyc_submitted_at,
  pending_organization_name,
  pending_organization_requested_at
) ON public.profiles TO authenticated;
-- anon gets no UPDATE: a member must be signed in to change their details.

-- ---------------------------------------------------------------------------
-- 2. Move service-role policies off the PUBLIC role
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "service_role_all_admin_permissions" ON public.admin_permissions;
CREATE POLICY "service_role_all_admin_permissions" ON public.admin_permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service_role_all_admin_roles" ON public.admin_roles;
CREATE POLICY "service_role_all_admin_roles" ON public.admin_roles FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on admin_staff" ON public.admin_staff;
CREATE POLICY "Allow all for service role on admin_staff" ON public.admin_staff FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "audit_logs_insert" ON public.audit_logs;
CREATE POLICY "audit_logs_insert" ON public.audit_logs FOR INSERT TO service_role WITH CHECK (true);
DROP POLICY IF EXISTS "excel_uploads_all" ON public.excel_uploads;
CREATE POLICY "excel_uploads_all" ON public.excel_uploads FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "excel_uploads_insert" ON public.excel_uploads;
CREATE POLICY "excel_uploads_insert" ON public.excel_uploads FOR INSERT TO service_role WITH CHECK (true);
DROP POLICY IF EXISTS "excel_uploads_read" ON public.excel_uploads;
CREATE POLICY "excel_uploads_read" ON public.excel_uploads FOR SELECT TO service_role USING (true);
DROP POLICY IF EXISTS "excel_uploads_update" ON public.excel_uploads;
CREATE POLICY "excel_uploads_update" ON public.excel_uploads FOR UPDATE TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on file_uploads" ON public.file_uploads;
CREATE POLICY "Allow all for service role on file_uploads" ON public.file_uploads FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on fraud_alerts" ON public.fraud_alerts;
CREATE POLICY "Allow all for service role on fraud_alerts" ON public.fraud_alerts FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on guarantor_settings" ON public.guarantor_settings;
CREATE POLICY "Allow all for service role on guarantor_settings" ON public.guarantor_settings FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "investment_pools_read" ON public.investment_pools;
CREATE POLICY "investment_pools_read" ON public.investment_pools FOR SELECT TO service_role USING (true);
DROP POLICY IF EXISTS "Allow all for service role on mobile_content" ON public.mobile_content;
CREATE POLICY "Allow all for service role on mobile_content" ON public.mobile_content FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "mobile_features_read_all" ON public.mobile_features;
CREATE POLICY "mobile_features_read_all" ON public.mobile_features FOR SELECT TO service_role USING (true);
DROP POLICY IF EXISTS "Allow all for service role on mobile_slides" ON public.mobile_slides;
CREATE POLICY "Allow all for service role on mobile_slides" ON public.mobile_slides FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on payroll_batches" ON public.payroll_batches;
CREATE POLICY "Allow all for service role on payroll_batches" ON public.payroll_batches FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on referral_settings" ON public.referral_settings;
CREATE POLICY "Allow all for service role on referral_settings" ON public.referral_settings FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service_role_all_role_permissions" ON public.role_permissions;
CREATE POLICY "service_role_all_role_permissions" ON public.role_permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on security_events" ON public.security_events;
CREATE POLICY "Allow all for service role on security_events" ON public.security_events FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on security_sessions" ON public.security_sessions;
CREATE POLICY "Allow all for service role on security_sessions" ON public.security_sessions FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on security_settings" ON public.security_settings;
CREATE POLICY "Allow all for service role on security_settings" ON public.security_settings FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "system_settings_read" ON public.system_settings;
CREATE POLICY "system_settings_read" ON public.system_settings FOR SELECT TO service_role USING (true);
DROP POLICY IF EXISTS "Users can view own investments" ON public.user_investments;
CREATE POLICY "Users can view own investments" ON public.user_investments FOR SELECT TO service_role USING (true);
DROP POLICY IF EXISTS "Allow all for service role on withdrawal_requests" ON public.withdrawal_requests;
CREATE POLICY "Allow all for service role on withdrawal_requests" ON public.withdrawal_requests FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for service role on withdrawal_settings" ON public.withdrawal_settings;
CREATE POLICY "Allow all for service role on withdrawal_settings" ON public.withdrawal_settings FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 3. Enable RLS where it was off, service role only
-- ---------------------------------------------------------------------------
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_admin_notifications" ON public.admin_notifications;
CREATE POLICY "service_role_all_admin_notifications" ON public.admin_notifications FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_admin_permissions" ON public.admin_permissions;
CREATE POLICY "service_role_all_admin_permissions" ON public.admin_permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_admin_roles" ON public.admin_roles;
CREATE POLICY "service_role_all_admin_roles" ON public.admin_roles FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.bank_reconciliation ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_bank_reconciliation" ON public.bank_reconciliation;
CREATE POLICY "service_role_all_bank_reconciliation" ON public.bank_reconciliation FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_bank_transactions" ON public.bank_transactions;
CREATE POLICY "service_role_all_bank_transactions" ON public.bank_transactions FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.contribution_plan_reductions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_contribution_plan_reductions" ON public.contribution_plan_reductions;
CREATE POLICY "service_role_all_contribution_plan_reductions" ON public.contribution_plan_reductions FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.contribution_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_contribution_plans" ON public.contribution_plans;
CREATE POLICY "service_role_all_contribution_plans" ON public.contribution_plans FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.document_access_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_document_access_log" ON public.document_access_log;
CREATE POLICY "service_role_all_document_access_log" ON public.document_access_log FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.fee_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_fee_types" ON public.fee_types;
CREATE POLICY "service_role_all_fee_types" ON public.fee_types FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.interest_rates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_interest_rates" ON public.interest_rates;
CREATE POLICY "service_role_all_interest_rates" ON public.interest_rates FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.ledger_serial ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_ledger_serial" ON public.ledger_serial;
CREATE POLICY "service_role_all_ledger_serial" ON public.ledger_serial FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.loan_agreements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_loan_agreements" ON public.loan_agreements;
CREATE POLICY "service_role_all_loan_agreements" ON public.loan_agreements FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.loan_approval_limits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_loan_approval_limits" ON public.loan_approval_limits;
CREATE POLICY "service_role_all_loan_approval_limits" ON public.loan_approval_limits FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.loan_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_loan_audit_log" ON public.loan_audit_log;
CREATE POLICY "service_role_all_loan_audit_log" ON public.loan_audit_log FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.member_activity_timeline ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_member_activity_timeline" ON public.member_activity_timeline;
CREATE POLICY "service_role_all_member_activity_timeline" ON public.member_activity_timeline FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.member_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_member_documents" ON public.member_documents;
CREATE POLICY "service_role_all_member_documents" ON public.member_documents FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.payment_failed_charges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_payment_failed_charges" ON public.payment_failed_charges;
CREATE POLICY "service_role_all_payment_failed_charges" ON public.payment_failed_charges FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.risk_scores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_risk_scores" ON public.risk_scores;
CREATE POLICY "service_role_all_risk_scores" ON public.risk_scores FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_role_permissions" ON public.role_permissions;
CREATE POLICY "service_role_all_role_permissions" ON public.role_permissions FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.system_emergency_controls ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_system_emergency_controls" ON public.system_emergency_controls;
CREATE POLICY "service_role_all_system_emergency_controls" ON public.system_emergency_controls FOR ALL TO service_role USING (true) WITH CHECK (true);
ALTER TABLE public.system_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all_system_rules" ON public.system_rules;
CREATE POLICY "service_role_all_system_rules" ON public.system_rules FOR ALL TO service_role USING (true) WITH CHECK (true);


-- ---------------------------------------------------------------------------
-- 4. Referral rows are written by the backend only
-- ---------------------------------------------------------------------------
-- The client never touches these tables directly (attribution and confirmation
-- go through the API), but members currently hold INSERT on referral_events,
-- which lets them fabricate pending referrals for themselves. Reads stay open
-- to the member so a future direct read still works.
DROP POLICY IF EXISTS "referral_events_write" ON public.referral_events;
CREATE POLICY "service_role_write_referral_events" ON public.referral_events
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "referrals_self_modify" ON public.referrals;
DROP POLICY IF EXISTS "Users can insert own referrals." ON public.referrals;
DROP POLICY IF EXISTS "Users can update own referrals." ON public.referrals;
CREATE POLICY "service_role_write_referrals" ON public.referrals
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Audit log entries must not be forgeable by the public role.
DROP POLICY IF EXISTS "audit_logs_insert" ON public.audit_logs;
CREATE POLICY "service_role_insert_audit_logs" ON public.audit_logs
  FOR INSERT TO service_role WITH CHECK (true);
