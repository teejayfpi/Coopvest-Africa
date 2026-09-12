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