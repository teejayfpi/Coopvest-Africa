-- Member bank-withdrawal requests.
--
-- `adminApi.js` already treats `withdrawal_requests` as the per-profile table
-- for withdrawals, but no migration ever created it, so the member endpoint
-- had nowhere to write. The table is intentionally additive: a request is
-- recorded here for finance to action, and the wallet is only debited when the
-- payout is confirmed — so no money leaves the system on the member's call.

CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  bank_account_id UUID,
  bank_name TEXT,
  account_number TEXT,
  account_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  description TEXT,
  processed_by UUID,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_profile
  ON withdrawal_requests (profile_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status
  ON withdrawal_requests (status, created_at DESC);

-- At most one pending request per member, matching the guard in
-- POST /api/v1/wallet/withdrawals.
CREATE UNIQUE INDEX IF NOT EXISTS idx_withdrawal_requests_one_pending
  ON withdrawal_requests (profile_id)
  WHERE status = 'pending';
