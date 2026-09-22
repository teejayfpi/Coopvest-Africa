# Coopvest — Latest-Coopvest backend

## ⚠️ TWO REPOS, NOT ONE — read before editing anything
This application exists as **two separate repositories that must be kept in
lockstep**:

| Repo | Contents |
|---|---|
| `coopvestafrica-ops/Latest-Coopvest` | this one — Flutter app + `backend/` |
| `teejayfpi/Coopvest-Africa` | the same app and backend, different git history |

They are **byte-identical** across `lib/`, `android/`, `assets/`, `ios/` and
`backend/` (they diverged into 27 differing files once; do not let that happen
again). They have different histories — a shared initial commit, then separate
commits — so **cherry-picking between them is unreliable. Copy files.**

**Every change must land in both.** A one-sided change ships different behaviour
for the same product, which has already happened twice:
- the LGA fix landed only in a screen so dead it never ran, and
- a branding refresh landed only here, giving the two apps different splash
  screens and icons.

**Before starting work:** `git fetch` both repos. Someone else pushes to these
regularly, and this repo has gained 6+ commits mid-session more than once.

**After finishing work:** confirm parity with
`diff -rq Latest-Coopvest/lib Coopvest-Africa/lib` (expect zero output) and
`diff -rq Latest-Coopvest/backend/src Coopvest-Africa/backend/src`.

**One-sided changes are the single most common source of bugs in this project.**

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


## `handle_payment_proof_approval` never wrote a contribution (fixed, 033)
The trigger inserts into `contributions`
`(profile_id, amount, status, contribution_month, payment_proof_id, notes)`,
but `contributions` had neither `payment_proof_id` nor `notes`. Postgres raised
`column "payment_proof_id" of relation "contributions" does not exist`, and the
trigger's own `exception when others then new_contribution_id := null;` swallowed
it. Approving a monthly contribution therefore never created the contribution
row and `contributions` stayed **empty for the whole install** — members saw a 0
-month contribution history and loan insights fell back to the savings row.
Migration `033_fix_payment_proof_contribution.sql` adds the two columns (and
`payment_proofs.contribution_id`, the write-back target). Verified: the exact
insert now succeeds.
Lesson: the trigger's blanket exception handler hides schema drift. When money
columns or new tables are added, check triggers that write them.

## `obligationsProvider` must be invalidated after a contribution change
`obligationsProvider` is a `FutureProvider` and is otherwise cached for the
lifetime of the app, so the "Monthly Savings" figure kept showing the amount
from launch — a member who raised their contribution only saw the new number
after restarting. It now `watch`es
`contributionPlanProvider.select((s) => s.plan?.currentMonthlyAmount)`, so any
increase/reduction re-fetches it; `home_dashboard_screen._loadData()` and the
loan dashboard's pull-to-refresh also `ref.invalidate(obligationsProvider)`.
Do not remove these — without them the card silently goes stale again.

## Loan totals must exclude never-disbursed loans
Cancelled/rejected applications are not borrowing. The backend leaves
`remaining_balance` NULL for them, which parses to 0, so
`totalRepayment - remainingBalance` reports the **entire** loan as repaid.
"Total Borrowed"/"Total Repaid" now filter through
`isLoanNeverDisbursed(status)` (`lib/data/models/loan_models.dart`) — on the
live test account that removed ₦1.3m of phantom repayments. Covered by
`test/unit/loan_totals_test.dart`.

## Loan eligibility card must use the same savings basis as the application
`loan_eligibility_card.dart` computed its max loan from
`wallet.totalContributions` (0 for most members, so it showed "0 max loan
available") while `loan_application_screen.dart` uses `wallet.totalSavings`
falling back to `wallet.balance`. The card now uses the same expression. It also
had `isEligible = true` hardcoded as a testing bypass, showing "You qualify for
a loan!" regardless of tenure; that is restored to
`monthsDone >= monthsRequired`, with `progress` guarded against a 0-month
requirement (0/0 is NaN and broke the progress ring).


## Never invent a money figure when a fetch fails
`ContributionPlanApiService.getContributionPlan()` used to swallow every error
and return a fabricated `CurrentMonthlyAmount: 5000`. A member on ₦10,000
therefore saw "Current Monthly Contribution ₦5,000" and was offered ₦10,000 as
an "increase" to their own current amount. The model's `fromJson` had the same
`?? 5000.0` fallback. Both now fail loudly: the service propagates, the model
throws a FormatException on a missing `current_monthly_amount`, and the screen
renders a "Could not load your contribution plan / Try Again" state instead of
guessing. The increase/reduction sheets refuse to open without a loaded plan.
General rule: a wrong financial figure is worse than an error message.

PostgREST returns `numeric` columns as JSON **strings** (`"10000.00"`), so
parse money fields defensively (`_toDouble` accepts num or numeric string).
A bare `as num` cast throws on a perfectly valid response.

## Contribution increase/reduction must not fake success
The provider used to "apply optimistically" on failure: it updated local state
and showed a success message even when the request never reached the server.
For a reduction it also invented a local request id and a +90-day effective
date, so the member saw "submitted" with no server record and waited three
months for a change that was never requested. Both paths now report the
server's message (`ApiException.message`, so policy codes such as
REDUCTION_BLOCKED_ACTIVE_LOAN reach the member) via `_errorText`.

## Due contribution reductions are applied on read
Nothing ever applied the 3-month reduction notice, so a pending request stayed
pending forever and the member never got the lower amount. `getOrCreatePlan()`
now calls `applyDueReduction()`, which, when `effective_date <= now()`, sets the
plan to `requested_amount` and marks the request `applied`. It is best-effort
and never throws, so plan reads cannot break. `status` has no CHECK constraint,
so `applied` is safe.

## Money formatting must stay grouped
`Formatters.formatCurrency` (core/utils/utils.dart) groups thousands and keeps
2dp. Several screens used `toStringAsFixed(2)` directly, rendering
`₦100150000.00` next to the header's `₦100,150,000`. Use the shared formatter —
import it with `show Formatters` in files that also need string extensions, to
avoid an ambiguous-extension clash with `capitalize`.

## Loans table has NO `disbursed_at` column
Only `disbursed_by` exists. Selecting `disbursed_at` makes PostgREST reject
the ENTIRE query, so a report silently reads zero rows and looks like it
worked. `approved_at` is the populated timestamp marking when a loan became
live (see `loanRecoveryWorker.js`, which documents the same trap). This has
bitten twice — check `approved_at` first, and never trust a "0 rows" result
without confirming the query did not 400.

## Reports come from the transaction ledger, not derived tables
`transactions` is the central ledger. `contributions` is derived and has
drifted in production: it holds a ₦100,000,000 row that no transaction
supports. Comparative/reporting code uses the ledger and returns a
`dataQuality` warning naming the discrepancy. Do NOT "switch back" to
`contributions` — a headline figure must be traceable to real transactions.
The stray rows still need deleting from the DB.

## Comparative analytics module
`src/lib/reportPeriods.js` (UTC periods, ISO weeks), `comparativeMetrics.js`
(ledger-backed flow vs stock metrics), `comparisonEngine.js` (abs + % change,
insights), `src/routes/comparative.js` (compare / export / drilldown).
Rules that are easy to regress: a zero base yields `percent: null` (never
Infinity%); rates compare in percentage POINTS; `higherIsBetter` per metric so
a falling default rate is not coloured as a decline; stock metrics
(outstanding, overdue) are rewound to the period END by adding back later
repayments, because `loans.remaining_balance` is live-only. ISO week 1 can
start in the previous calendar year — enumerate by ISO week-year or you get
zero weeks. `ledger_entries` is NOT summed alongside `transactions`; they
overlap and unioning them double-counts.

Reporting branches stack: `feat/reporting-suite` → `feat/comparative-analytics`.

## Organization finance + member linkage
`src/lib/organizationFinance.js` (expected/remitted/outstanding per org),
`src/routes/organizationFinance.js` (positions, pending requests, assign,
detail, trend), mounted at `/api/admin/organizations` BEFORE adminApi so its
sub-paths win (adminApi keeps its own GET/POST /organizations and has no
catch-all).

Money model: **Expected** = Σ linked members' `monthly_amount`; **Remitted** =
Σ `payroll_batches.total_contribution_amount` for the month; **Outstanding** =
Expected − Remitted. Remittance is read from `payroll_batches`, NOT from member
transactions — summing transactions double-counts a direct payment made
alongside a payroll deduction and cannot represent a remittance that arrived
before members were allocated.

Rules pinned by tests: over-remittance reports NEGATIVE outstanding (a surplus
must be reconciled, not clamped); a member with no `monthly_amount` is
`no_expectation`, not `lapsed`; unlinked members are counted and surfaced (the
live project has 0 of 6 linked against 411 organizations, so a report built
only from linked members reads zero and looks broken);
`organizations.member_count` is a stale counter (0 for every org) — use the
live count and report the drift; rows sort by what is owed.

The member app could always request an employer
(`POST /organizations/request-approval`) but nothing could APPROVE it and set
`profiles.organization_id`. That linkage is now
`POST /pending-requests/:id/approve` plus `POST /assign|/unassign`. All linkage
writes go to `audit_logs` with before/after values.

Branch chain: `feat/reporting-suite` → `feat/comparative-analytics` →
`feat/organization-finance`.
