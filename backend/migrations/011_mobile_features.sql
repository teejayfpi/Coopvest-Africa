-- Migration: mobile_features
-- Persists admin-controlled mobile app feature flags in Supabase so toggles
-- survive backend restarts (the previous in-memory store reset on every deploy).
--
-- Used by backend/src/routes/features.js:
--   GET  /api/mobile-features            -> all flags (admin dashboard)
--   PUT  /api/mobile-features            -> toggle a flag (admin dashboard)
--   GET  /api/features/platform/mobile   -> mobile-facing flag shape (Flutter app)
--
-- Seed values mirror the prior in-memory defaults so behaviour is unchanged
-- on first deploy.

CREATE TABLE IF NOT EXISTS mobile_features (
  id            text PRIMARY KEY,
  name          text NOT NULL,
  description   text NOT NULL DEFAULT '',
  enabled       boolean NOT NULL DEFAULT true,
  updated_by    text NOT NULL DEFAULT 'System',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mobile_features_enabled
  ON mobile_features (enabled);

-- Keep updated_at current on edits
CREATE OR REPLACE FUNCTION update_mobile_features_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_mobile_features_updated_at ON mobile_features;
CREATE TRIGGER trg_mobile_features_updated_at
  BEFORE UPDATE ON mobile_features
  FOR EACH ROW EXECUTE FUNCTION update_mobile_features_updated_at();

-- Row-Level Security: the backend uses the service-role key which bypasses RLS,
-- so API access is unaffected. This policy is a defence-in-depth default for
-- any anon/authenticated client that hits the table directly.
ALTER TABLE mobile_features ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mobile_features_read_all ON mobile_features;
CREATE POLICY mobile_features_read_all ON mobile_features
  FOR SELECT USING (true);

-- Seed the default flags (idempotent - ON CONFLICT keeps existing toggles intact).
INSERT INTO mobile_features (id, name, description, enabled, updated_by) VALUES
  ('loan_requests',       'Loan Requests',       'Allow members to submit loan requests via the mobile app',     true,  'System'),
  ('registration',        'Registration',        'Allow new users to register accounts through the mobile app', true,  'System'),
  ('salary_deduction',    'Salary Deduction',    'Enable salary deduction as a contribution method',           true,  'System'),
  ('direct_contribution', 'Direct Contribution', 'Allow members to make direct contributions via the app',      true,  'System'),
  ('wallet_transfers',    'Wallet Transfers',    'Enable wallet-to-wallet transfers between members',           false, 'System'),
  ('investment_pool',     'Investment Pool',     'Allow members to participate in investment pools',            true,  'System'),
  ('guarantor_system',    'Guarantor System',    'Enable the guarantor selection feature for loan applications', true,  'System'),
  ('referral_program',    'Referral Program',    'Allow members to refer others and earn rewards',             true,  'System'),
  ('push_notifications',  'Push Notifications',  'Send push notifications to mobile app users',                true,  'System'),
  ('withdrawals',         'Withdrawals',         'Allow members to withdraw from their wallets',               true,  'System'),
  ('kyc_verification',    'KYC Verification',    'Require identity verification before full platform access',  true,  'System'),
  ('biometric_login',     'Biometric Login',     'Allow members to log in using fingerprint or face ID',        false, 'System')
ON CONFLICT (id) DO NOTHING;
