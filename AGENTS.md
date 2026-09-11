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