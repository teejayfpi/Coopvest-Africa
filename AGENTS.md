# Coopvest-Africa (Flutter mobile app + Node backend)

## Authentication — gotrue 2.15.0 API constraints
The lockfile pins `gotrue 2.15.0` (via `supabase_flutter ^2.3.0`). Its
`GoTrueClient` API differs from newer gotrue releases:
- `setSession(String refreshToken)` — ONE positional arg (refresh token only.
  Do NOT pass `(accessToken, refreshToken)` — that 2-arg form does not exist here.

- OTP verification is `verifyOTP({email?, token?, required OtpType type, ...})` —
  capital **OTP**. The lowercase `verifyOtp(...)` does not exist on `GoTrueClient`.
  OTP recovery resets use `verifyOTP(token: code, type: OtpType.recovery)`.



- Deep-link auto-verify (`_verifyFromLink` in
  `lib/presentation/screens/auth/register_step2_screen.dart`) must parse the
  fragment at `#access_token=...&refresh_token=...` manually and call
  `setSession(refreshToken)` + `refreshSession()`. A bare token param goes
  through `verifyOTP`.

## Supabase project
- Project ref: `nyoauzqezpxeonmrxxgi` (region eu-west-1.
- Management API SQL endpoint (no DB password needed):
  `POST https://api.supabase.com/v1/projects/<ref>/database/query`
  with `Authorization: Bearer sbp_...` and body `{"query": "<sql>"}`.
- Migrations live in `backend/migrations/*.sql` (idempotent; apply in the
  numbered pre-fix order). Ones confirmed missing on a fresh clone and
  applied: 009 (payment_type),014 (ticket categories),025 (paystack),028 (realtime).
  The live DB already had everything else (83+ tables, admin-platform 001-003,
  ledger 023, termination 024, loans cancelled 013, mobiles 011-012).

## Flutter analyze
- `flutter analyze` reports many pre-existing errors unrelated to this
  fix (missing `firebase_remote_config`, missing `logger_service.dart`,
  stale `analytics_service.dart`, test Riverpod `ProviderOverride` drift).
  The auth screens themselves are clean after the gotrue fix.



## Contribution method — no duplicate prompt
- `ContributionTypeSelectionScreen` (right after email verification) asks
  direct_deposit vs salary_deduction once. The onboarding `_ContributionStep`
  NO LONGER re-asks it — the `contribution_method` payload is now derived
  from `_data.contributionType` (`salary_deduction`→`'payroll'`, else `'manual'`).
- Removed the unused `_MethodCard` widget from `registration_onboarding_screen.dart`.

## Paystack loan-repayment auto-deduction
- `payments.js` needed the full allocation machinery ported from Latest-Coopvest:
  `ALLOWED_PAYMENT_TYPES` += loan_repayment/fine/fee/mixed, `DB_PAYMENT_TYPE`
  map (fine/fee/mixed stored as `'other'` CHECK-compatible), `normalizeAllocations()`,
  and `applyAllocations(proof)` — which reduces `loans.remaining_balance`,
  inserts a `loan_repayments` row keyed by `reference = proof.id` (idempotent),
  and completes the loan when balance hits 0.
- `/payments/initialize` now accepts `allocation_type` + `allocations`, parks
  them in proof `metadata`, and stores the DB-compatible `payment_type`.
- Manual deposits: admin `PATCH /api/admin/deposits/:id/verify` already reduces
  the loan (alloc.type === 'loan_repayment`) — both repos had it。
- Admin Dashboard reads `loans.remaining_balance` live → reflects automatically.

## Paystack loan repayment — targeted loan (loan_id)
- `/payments/initialize` accepts optional `loan_id`; when present it is carried
  into the `loan_repayment` allocation and persisted in proof `metadata.loan_id`.
- `applyAllocations()` prefers the targeted loan (`alloc.loan_id`, looked up in
  statuses active/approved/repaying) and only falls back to the active loan
  with the highest remaining balance otherwise.
- Mobile (`deposit_screen.dart`): loan repayment now shows a loan picker
  (`_selectedLoanId`), passes `loan_id` to both `/payments/initialize` and
  `/wallet/contribute`, and the Paystack "Pay Instantly" button handles
  loan_repayment (instant, no admin verification).
- `loan_details_screen.dart` "Make Repayment" navigates to DepositScreen with
  `initialAllocationType: 'loan_repayment'` + `initialLoanId`.

## Notifications — live schema column correctness
- The live `notifications` table uses `is_read`/`is_archived` — there is NO
  `read` or `archived` column. `notifications.js` must query
  `.eq('is_read', …)` and update `{ is_read: true }` — never `read`/`archived`.
- The mobile list (`GET /api/v1/notifications`) originally referenced the
   nonexistent `read`/`archived` columns → PostgREST PGRST204 → every fetch
   failed → app showed "No notifications yet" placeholder. Fixed to match
   `is_read` (ported from Latest-Coopvest).
- Realtime: `notifications` must be in the `supabase_realtime` publication
  (and `REPLICA IDENTITY FULL`) or the app's `postgres_changes` channel
  (INSERT on `notifications` with `profile_id = userId`) never fires.
  Migration `029_notifications_realtime.sql` does this (applied via Mgmt API).
- `feature_flag.notifications` = `true` live (fail-open if missing) — not the issue.
## Monthly contribution is the obligations source of truth
`contribution_plans.current_monthly_amount` is the single source of truth for
a member's monthly savings. `savings.monthly_savings` is a denormalised mirror
that can lag. Resolution lives in the pure helper
`src/lib/monthlyContribution.js` (`resolveMonthlyContribution`) and is used by
`GET /wallet/obligations` and `GET /wallet/balance` — plan wins, savings is the
fallback. Registration (`POST /auth/complete-registration`) seeds the plan via
`syncMonthlyContributionPlan()` (never lowers an amount already set, so a
resumed onboarding save can't undo a later increase). A member's contribution
increase/reduction therefore flows straight into "Your obligations this month"
without any further wiring.

## Obligations card is shared
`lib/presentation/widgets/obligations_card.dart` (`ObligationsCard`) renders
"Your obligations this month" with a **Pay Now** action that opens
`DepositScreen` pre-filled with the monthly figure (`initialAmount`). It is
used by both the home dashboard (directly below Quick Actions) and the loan
dashboard. Do not re-add a private per-screen obligations builder — keep the
two surfaces in sync through this widget.

## Withdrawals are request-based, never an instant debit
`POST /api/v1/wallet/withdrawals` (body: `amount`, `bank_account_id`) inserts a
`withdrawal_requests` row and notifies admins; the wallet is **not** debited
until finance confirms the payout. The old `POST /wallet/withdraw`, which
debited immediately and paid nothing out, has been removed — do not reinstate
it, and do not add a payout integration to this route without a finance
approval step. Table + one-pending-per-member unique index:
`backend/migrations/032_withdrawal_requests.sql`. The endpoint returns 503 with
a friendly message when that migration hasn't been applied yet.

## Schema gotchas found against the live DB
- `bank_accounts` uses `is_primary`, **not** `is_default`. The backend routes and
  the mobile bank-account/withdrawal screens must all read/write `is_primary` —
  writing `is_default` fails with "column does not exist" and blocks adding a
  bank account entirely.
- `withdrawal_requests` already existed in production in a legacy shape
  (`user_id` text, `user_name`, no member FK), so a `CREATE TABLE IF NOT EXISTS`
  is a no-op. Migration 032 is therefore additive `ALTER TABLE ... ADD COLUMN IF
  NOT EXISTS profile_id/bank_account_id/description/processed_by/processed_at`.
- `contribution_plans` has a FK to `profiles(id)` and `UNIQUE (profile_id)`, so
  `.upsert(..., { onConflict: 'profile_id' })` is safe.

