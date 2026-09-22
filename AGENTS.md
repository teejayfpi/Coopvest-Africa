# Coopvest-Africa (Flutter mobile app + Node backend)

## ⚠️ TWO REPOS, NOT ONE — read before editing anything
This application exists as **two separate repositories that must be kept in
lockstep**:

| Repo | Contents |
|---|---|
| `teejayfpi/Coopvest-Africa` | this one — Flutter app + `backend/` |
| `coopvestafrica-ops/Latest-Coopvest` | the same app and backend, different git history |

They are **byte-identical** across `lib/`, `android/`, `assets/`, `ios/` and
`backend/` (they diverged into 27 differing files once; do not let that happen
again). They have different histories — a shared initial commit, then separate
commits — so **cherry-picking between them is unreliable. Copy files.**

**Every change must land in both.** A one-sided change ships different behaviour
for the same product, which has already happened twice:
- the LGA fix landed only in a screen so dead it never ran, and
- a branding refresh landed only HERE, giving the two apps different splash
  screens and icons.

**Before starting work:** `git fetch` both repos. Someone else pushes to these
regularly, and `Latest-Coopvest` gained 6+ commits mid-session more than once.

**After finishing work:** confirm parity with
`diff -rq Coopvest-Africa/lib Latest-Coopvest/lib` (expect zero output) and
`diff -rq Coopvest-Africa/backend/src Latest-Coopvest/backend/src`.

**One-sided changes are the single most common source of bugs in this project.**

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

