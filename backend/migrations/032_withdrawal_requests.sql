-- Align `withdrawal_requests` with the member withdrawal flow.
--
-- The table already existed in production with a legacy shape
-- (`user_id` text, `user_name`, no member FK). CREATE TABLE IF NOT EXISTS was
-- therefore a no-op, and the member endpoint could not write to it. This
-- migration is additive and idempotent: it only adds the columns the API needs
-- and leaves the legacy columns in place.

ALTER TABLE withdrawal_requests
  ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES bank_accounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS processed_by UUID,
  ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ;

-- updated_at predates this migration on some installs; add it if absent.
ALTER TABLE withdrawal_requests
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_profile
  ON withdrawal_requests (profile_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status
  ON withdrawal_requests (status, created_at DESC);

-- At most one pending request per member, matching the guard in
-- POST /api/v1/wallet/withdrawals. Partial, so settled history is unaffected
-- and legacy rows with a NULL profile_id never collide.
CREATE UNIQUE INDEX IF NOT EXISTS idx_withdrawal_requests_one_pending
  ON withdrawal_requests (profile_id)
  WHERE status = 'pending';