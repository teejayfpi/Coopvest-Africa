# Coopvest — Latest-Coopvest backend

## Interest calculation (mobile-aligned)
The backend interest logic in `src/services/referralService.js` MUST mirror the
mobile app (`lib/presentation/screens/loan/loan_application_screen.dart`):

- `BASE_RATES` per loan type: Quick Loan 7.5%, Flexi 7.0%, Stable (12m) 5.0%,
  Stable (18m) 7.0%, Premium 14.0%, Maxi 19.0%. Legacy Micro/Business/Emergency
  kept for old loans.
- `MIN_FLOORS` = half of each base rate.
- Referral tier bonus: 2% / 1% / 0.5% at 10 / 5 / 2 confirmed referrals.
- Monthly repayment = EMI (reducing balance): `P * r * (1+r)^n / ((1+r)^n - 1)`,
  `r = effectiveRate / 100 / 12`.
- Total repayment = SIMPLE interest: `amount + (amount * effectiveRate / 100)`.
  (NOT EMI * tenure — the mobile app uses simple interest for total.)

`src/routes/loans.js` `LOAN_TYPES` accepts the mobile app's loan type names, and
`total_repayment` stores the simple-interest value from the calc object.

`src/routes/adminApi.js` GET `/loans` recomputes interest via
`referralService.calculateInterestWithBonus(loanType, amount, tenure, bonus)`
so legacy loans created under the old rate table display the same figures the
member sees in the app.

## Deploy
- Backend deploys automatically on push to `main` (Render).
- Admin dashboard is a separate Vite/React app in
  `../Admin-Dashboard` deployed on Vercel.

## Registration / onboarding (mobile)
- `POST /api/auth/complete-registration` (auth) saves onboarding data to the
  `kyc` table. `date_of_birth` and `address` are top-level columns; everything
  else lives in `personal_info` / `employment_info` JSONB (bank fields inside
  `personal_info`).
- Validation and the write both merge the request body over the existing KYC
  row via `services/registrationMerge.js` (`buildRegistrationCandidates`,
  `mergeStoredPersonalInfo`): body values win when present, stored values fill
  gaps. This lets a member resume an interrupted registration without losing
  already-saved fields, and prevents the earlier bug where a partial resubmit
  wiped `personal_info`/`employment_info`.
- Required-field rules are in `REGISTRATION_FIELDS` (`routes/auth.js`); the
  same `checkCompletion()` drives the POST endpoint, `GET
  /complete-registration/status`, and `GET /profile-completeness`.
- Age gate: members must be 18+. `POST /complete-registration` and
  `POST /api/v1/kyc/submit` both reject an under-18 `date_of_birth` with 422
  (`ageInYears`/`MIN_AGE_YEARS` in `services/registrationMerge.js`, exact
  calendar math). The app's DOB picker caps selection at the 18th birthday.

## Auth for live API
- API base: `https://coopvest-api.onrender.com`
- Admin login: POST `/api/auth/login` with the admin email/password.
- Admin loans: GET `/api/admin/loans` with `Authorization: Bearer <token>`.

## Admin Platform Extensions (financial-ops modules)
`src/routes/adminPlatform.js` is mounted under `/api/admin` (via `router.use` in
`adminApi.js`, so it inherits `requireAdmin`). Sensitive mutations require the
Super Admin role (`requireSuperAdmin` from `middleware/auth.js`).

Modules (all additive, no migration required for the core — config is stored in
the `system_settings` key/value jsonb table):
1. **Emergency Control Center** — `GET/PUT /api/admin/emergency-controls`,
   `POST /api/admin/emergency-controls/disable-admin`. Toggles stored as
   `emergency.*` keys. `middleware/systemStatus.js` reads the same keys (with a
   15s cache) and blocks matching member-facing writes with HTTP 423. Admin
   routes are bypassed so a freeze can be lifted.
2. **Financial Ledger** (source of truth) — `GET /api/admin/ledger` (filters:
   `id`=txn_no, `profileId`, `reference`, `memberName`, `paymentMethod`,
   `status`, `from`/`to`), `/ledger/member/:id` (running balance),
   `POST /api/admin/ledger/:id/reverse` (append-only reversal). Migration 023
   adds serialized `txn_no` (CV-YYYY-NNNNNN via `next_ledger_txn_no()`),
   enrichment columns (member/organization/payment-method/bank, `approved_by`,
   `loan_id`, `payment_proof_id`, `allocation`), `bank_transactions` +
   `bank_reconciliation` tables, and auto-posts an inflow ledger credit from
   `handle_payment_proof_approval()` on every verified payment proof. Section 2b
   of `adminPlatform.js` exposes `/ledger/dashboard` totals + reconciliation
   status, audited `/ledger/adjust`, `/ledger/export.csv`, and the bank
   statement import/reconciliation endpoints. The ledger responses UNION
   stored `ledger_entries` rows (admin-posted: reversals, adjustments,
   payment-proof auto-posts) with a computed view over `transactions`
   (`services/ledgerMerge.js`), deduped by `reference`. Union is required:
   `ledger_entries` exists in production but holds no mirrored activity, so
   querying it alone renders the ledger empty. Migration:
   `supabase/migrations/20260814000000_admin_platform.sql`.
3. **System-Wide Search** — `GET /api/admin/search?q=`.
4. **Super Admin Attention Required** — `GET /api/admin/attention` (aggregate
   of pending approvals, payment proofs, fraud flags, overdue loans, KYC,
   tickets).
5. **Loan Approval Matrix** — `GET/PUT /api/admin/loan-approval-matrix`,
   `GET /loan-approval-matrix/my-limit`. Stored as `loan_approval.thresholds`.
6. **Notification Template Manager** — `GET /api/admin/notification-templates`,
   `PUT /notification-templates/:key`. Stored as `notification_template.*`.
7. **Document Vault** — `GET /api/admin/documents`, `POST /documents/:id/access`
   (view/download audit-logged).
8. **Payroll Reconciliation** — `GET /api/admin/payroll/:orgId/reconciliation`
   (expected vs actual variance).

The Approval Center (maker-checker) lives in `src/routes/governance.js` under
`/api/admin/approvals` (uses `security_events` with the `APPROVAL_` prefix).

## Auth — gotrue 2.15.0 API constraints
The lockfile pins `gotrue 2.15.0` (`supabase_flutter ^2.3.0`). Its
`GoTrueClient` differs from newer releases:
- `setSession(String refreshToken)` — ONE positional arg. Do not pass the
  2-arg `(accessToken, refreshToken)` form.
- OTP verification is `verifyOTP({email?, token?, required OtpType type, ...})` —
  capital OTP. Lowercase `verifyOtp(...)` does not exist here.
- `_verifyFromLink` in `register_step2_screen.dart` uses
  `setSession(refreshToken)` + `refreshSession()` for fragment links,
  `verifyOTP` for bare token params.

## Contribution method — no duplicate prompt
`ContributionTypeSelectionScreen` (post-email-verification) asks
direct_deposit vs salary_deduction once. The onboarding `_ContributionStep`
no longer re-asks it — `contribution_method` is derived from `contributionType`
(`salary_deduction`→`'payroll'`, else `'manual'`). Removed `_MethodCard`.

## Notifications realtime
`notifications` must be in the `supabase_realtime` publication + `REPLICA
IDENTITY FULL` (see `backend/migrations/029_notifications_realtime.sql`),
or the app's `postgres_changes` INSERT channel (filter profile_id =
userId) never fires. Migration 029 handles it (applied via Mgmt API).

## Role note
The DB uses both `superadmin` and `super_admin` spellings; treat both as Super
Admin everywhere.

## Gotcha: Express sub-mounts strip the prefix
Never mount a whole router at a deep path to "expose one route early" (e.g.
`app.use('/api/v1/bank-accounts/verify', bankAccountRoutes)`): Express strips
the mount prefix, so `POST .../verify` hits the router's `/` route instead.
Gate per-route inside the router (see `src/routes/bankAccounts.js`: `gated =
requireActivated` on every route except POST `/verify`, fixed in ee41ba17).

## Bank verification
`POST /api/v1/bank-accounts/verify` (and legacy `/api/bank-accounts/verify`)
resolves account holder names via Paystack (`PAYSTACK_SECRET_KEY`, 503 when
unconfigured, 422 when Paystack can't resolve). Reachable pre-activation
because members use it during KYC onboarding.

## Instant Paystack for all payment allocations (mobile)
`POST /api/v1/payments/initialize` accepts `allocation_type` + `allocations`
(values: monthly_contribution, loan_repayment, fine, fee, registration_fee,
mixed). `payment_proofs.payment_type` CHECK only allows monthly_contribution/
loan_repayment/registration_fee/investment/other, so `payments.js` maps
fine/fee/mixed → stored `other` and parks the breakdown in proof
`metadata.allocations/allocation_type`. On Paystack success, settle calls
`applyAllocations`: savings→wallet credit (skipped when proof is monthly_contribution —
DB trigger credits it), loan_repayment→loan reduction + `loan_repayments`
row keyed by `reference = proof.id` (idempotent), fine/fee→member_fees paid. Mirrors admin deposit-verification loop in adminApi.js. Keep the
`proof.status === 'approved'` early-return guard to avoid double settles.

