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

### OTP codes are not 6 digits
`GOTRUE_MAILER_OTP_LENGTH` is a **server setting**, not a constant. This
project issues **8-digit** codes, so never hardcode `6` in a client length
check or a fixed-size OTP box. A screen that requires exactly 6 digits
silently rejects every valid code — the user cannot even type one in. Use a
single flexible field (12 chars) and a `>= 6` guard; `verifyOTP` is the
authority. Only change the length in Dashboard → Authentication → Sign In /
Providers → Email if you also want 6-digit codes.

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



## Monthly savings amount — write it AFTER it is chosen

`contribution_plans.current_monthly_amount` is the single source of truth for
"Your obligations this month". Two ways to get it wrong, both of which showed
members the platform minimum instead of the amount they picked:

1. **Ordering.** `/kyc/contribution-type` runs on the contribution-type screen,
   which is *before* `SignupDetailsScreen` collects the amount. Posting the
   amount only from there can never carry the real value — it is read from the
   local hand-off before anything has been stored. The amount must be sent from
   the screen that actually collects it.

2. **Seeding.** A brand-new plan must not default to `MINIMUM_MONTHLY_AMOUNT`.
   A missing row then looks identical to a member who genuinely chose the
   minimum. Seed from `kyc.personal_info.monthly_amount` via `resolveSeedAmount`
   (`backend/src/lib/monthlyContribution.js`), clamped to the minimum floor.

A member with no plan row self-heals on the next `GET /contributions/plan`,
which calls `getOrCreatePlan`.

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

## Admin notifications are push-based now (mobile + website → dashboard)

`notifyService.notifyAdmins()` is the single entry point for anything that
should reach admins. It looks up every `profiles` row whose `role` is in
`['admin','super_admin','superadmin','staff','operator']` (mirrors the
`is_staff()` RLS helper) and fans out in-app + FCM push, with an optional
email (via `alertService`, non-fatal). Never throws — callers have already
persisted the underlying record, so a notification failure must not fail the
request.

Wired to: website contact form (`routes/contact.js` — the enquiry now lights
the bell instead of waiting for the 30s Website-Enquiries poll), support
tickets (`routes/tickets.js`), loan applications (`routes/loans.js`), KYC
submissions (`routes/kyc.js`), the existing org-approval request, instant
Paystack settlements (`routes/payments.js`), member deposits/withdrawals
(`routes/wallet.js`), contribution-schedule edits (`routes/contributions.js`),
rollover requests (`routes/rollover.js`), membership termination
(`routes/termination.js`), investment participation
(`routes/investments.js`), savings withdrawal (`routes/savings.js`), manual
payment-proof submission (`routes/paymentProofs.js`) and document upload
(`routes/documents.js`).

Every new type a caller passes must survive `normalizeNotifType` onto the
`notifications.type` CHECK constraint, or the insert throws 23514 and the
alert is silently swallowed. `__tests__/adminNotificationCoverage.test.js`
pins both the wiring (alert present, fire-and-forget, has `.catch`) and the
type coercion for these events. Deliberately *not* wired: `savings/deposit`
(wallet → savings, self-directed) and `savings/goals` (no money moves).

`GET /api/admin/notifications` is scoped to admin profile_ids and returns a
true `unreadCount`; `POST .../read-all` is scoped the same way. The admin
dashboard (`Admin-Dashboard/src/hooks/use-admin-notifications.ts`) subscribes
to `postgres_changes` on its own `profile_id` for instant bell updates, plays
a sound, and shows an opt-in desktop notification.

### `notifications` has BOTH `message` and `body` — write both

The table has two text columns and they are not interchangeable:

- **`message` is `NOT NULL`** and is what the admin dashboard renders.
- **`body` is nullable**; the Flutter model reads `json['body'] ?? json['message']`.

`sendInApp` (and the `/scheduled-notifications/run-due` sender in `adminApi.js`)
once inserted only `body`. Every insert then failed with Postgres **23502**
(`null value in column "message"`), and because notify failures are treated as
non-fatal (`logger.warn` + `{status:'failed'}`) the error was swallowed — so
**no notification was ever stored**, admin alerts included. When adding an
insert against `notifications`, set `message` as well as `body`. Pinned by
`backend/__tests__/notificationMessageColumn.test.js`.

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

## A failed charge that debited the member must not vanish

Paystack can fail a card charge *after* the member's bank authorised or debited
it (`charge.failed` debit-on-hold, and `transfer.reversed`). The old flow only
understood `charge.success`, so those references sat at
`payment_proofs.status = 'pending'` forever, the app showed an indefinite
"Payment not confirmed yet", and nothing recorded that money may have left the
member's account. Support could not tell "never paid" from "debited but not
credited".

`handleFailedCharge` (`backend/src/routes/payments.js`) is now shared by the
webhook, `GET /payments/verify/:reference`, and the reconcile sweep
(`failedChargeReconcileWorker.js`, every 30 min). Rules that must not regress:

* `classifyFailure` (`src/lib/paystackCharge.js`) is the single source of truth:
  `reversed`/`failed` ⇒ `possibleDebit = true` and an admin alert; `abandoned`
  ⇒ recorded, member told, **no** admin alarm (no money moved).
* A charge already `approved` is never flipped to `failed` — a failure event
  trailing a real success would tell the member their credited money is gone. It
  raises a "failure after credit" admin alert instead.
* `verifyCharge` returning `ok = false` means Paystack was unreachable, **not**
  that the payment failed. Leave the row pending and retry; never treat a
  transport error as a decline.
* Every failure writes to `payment_failed_charges` (migration 050), unique on
  reference+status. Admins work the queue at `GET /api/admin/payments/failed`
  and close it with `PATCH /api/admin/payments/failed/:id/resolve` (a note is
  required — this touches member money).
* Nothing auto-refunds. Whether to credit or refund is a human/policy decision;
  the system's job is to surface it and never lose it.
## "Paid this month" must count wallet deposits, and new members are not overdue
Wallet deposits (`wallet_deposit`/manual deposit flow) do **not** write a
`contributions` row — they update `savings.last_savings_date` and mirror a
`transactions` credit. Detecting a paid month from `contributions` alone
therefore reported every wallet-deposit payer as still owing, which drove the
recurring false notification "your contribution of ₦X is N days overdue".
`hasPaidThisSavingsMonth` (`backend/src/routes/wallet.js`) now treats either a
paid `contributions` row for the current month **or** a
`savings.last_savings_date` inside the current month as settled. `applyPaidMonthRule`
also zeroes the savings due when `joinedThisMonth`, so a brand-new account is
not instantly in arrears. The app reads `month_paid_savings` /
`joined_this_month` / `last_savings_date` from `GET /wallet/obligations` and
passes them into `evaluateContributionReminder`
(`lib/core/services/contribution_reminder_service.dart`), which is pure and
unit-tested. `ObligationsCard` honours `joined_this_month` the same way.
Do not reintroduce a client-side "overdue" decision that trusts only the
contributions list — it will nag paid and new members again.

The daily push is now sent by `backend/src/workers/contributionReminderWorker.js`
(started in `server.js`), which calls `computeObligations` and therefore applies
the exact same paid/new/payroll rule as the obligations card — push and app can
never disagree. It de-dupes with a `reminder:YYYY-MM` tag written into the
notification body, so a restart cannot repeat a month's reminder.

It replaced the Supabase edge function `process-contribution-reminders`, which
was **never deployed** (both `functions/v1/process-contribution-reminders` and
`send-contribution-reminder` return 404 on the live project) and could not have
worked anyway: it called the legacy `fcm.googleapis.com/fcm/send` API, which
Google shut down in June 2024. It also read `user_settings.user_id` /
`fcm_token` / `preferred_day` / `monthly_amount`, none of which exist on that
table. The copy is left in the repo for reference; do not deploy it. Real push
uses `firebase-admin` (FCM v1) through `notifyService`, which works.

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

## KYC status is never null — guard drafts on `isUntouchedServerRow`

`GET /kyc/status` calls getOrCreateKyc, so it always returns a provisional
`pending` row; the response is non-nullable. A guard written as
`submission ??= await _restoreDraft()` can therefore never run, which silently
disables the "resume my KYC draft" feature. Use
`KYCSubmission.isUntouchedServerRow` (`lib/data/models/kyc_models.dart`) instead:
a locally saved draft is restored only while the server row is still `pending`
*and* empty on every member-entered field, so stale local values can never mask
data the server already holds. Covered by
`test/unit/kyc_draft_resume_test.dart`.

## Money formatting must stay grouped
`Formatters.formatCurrency` (core/utils/utils.dart) groups thousands and keeps
2dp. Several screens used `toStringAsFixed(2)` directly, rendering
`₦100150000.00` next to the header's `₦100,150,000`. Use the shared formatter —
import it with `show Formatters` in files that also need string extensions, to
avoid an ambiguous-extension clash with `capitalize`.

## Live payment + push config (as of 2026-09-28)

`coopvest-api` (srv-d735htpr0fns73996big) now has `PAYSTACK_SECRET_KEY` and the
`FIREBASE_PROJECT_ID`/`FIREBASE_CLIENT_EMAIL`/`FIREBASE_PRIVATE_KEY` trio set —
16 vars total. Before that, `POST /payments/initialize` and
`bank-accounts/verify` returned 503 "Paystack is not configured on the server"
and every push was skipped as `no_firebase_credentials`. Firebase project is
`coopvest-africa-46a86` (same one the mobile `google-services.json` points at).

Still unset (feature coded but dormant): `CONTACT_NOTIFY_TO` (website-enquiry
heads-up email — `RESEND_API_KEY` already works so this is the only missing
piece), `ALERT_EMAIL_RECIPIENTS` (security alerts; and that path uses SMTP,
which the Render free plan blocks anyway), `CONTACT_INGEST_TOKEN`. Firebase is
set but push still needs a member to sign into the mobile app so
`POST /api/v1/notifications/fcm-token` writes a `device_tokens` row.

Quick liveness probe for the Paystack key without credentials: `POST
/api/v1/payments/webhook` returns 401 (key loaded → signature mismatch) when
configured, 503 when not.


## Render env vars are replaced, not merged

`PUT /v1/services/{id}/env-vars` replaces the whole set. Sending only the keys
you want to add silently deletes every other variable — and the service keeps
running on the old values until the next deploy, so the damage only surfaces
after a deploy or restart. Read the current set first and send the union:

```bash
curl -s "https://api.render.com/v1/services/$SVC/env-vars?limit=100" -H "Authorization: Bearer $RENDER_TOKEN"
```

Before adding a variable there, confirm you can re-derive every existing one:
`SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_ANON_KEY` are recoverable from the
Supabase management API, but `PAYSTACK_SECRET_KEY` and the `FIREBASE_*` pair
exist *only* in Render and cannot be recovered once overwritten.

## Admin replies need a mail transport, and Render's free plan blocks SMTP

An admin reply to a website enquiry is always recorded in `contact_messages`,
but it only reaches the enquirer when a mail transport is configured on the
backend. `src/services/mailer.js` picks one in this order:

1. `RESEND_API_KEY` - Resend HTTP API. Goes over 443.
2. `SMTP_HOST` + `SMTP_USER` + `SMTP_PASS` - nodemailer.

**Prefer Resend.** Free Render web services block outbound traffic to SMTP ports
25, 465 and 587 (Render changelog, 26 September 2025), so an SMTP send from
`coopvest-api` fails with `Connection timeout` however correct the credentials
are. Port 25 stays blocked even on paid instances; 465/587 work once the service
is on a paid plan. This is why the mailer defaults to an HTTPS API rather than
SMTP.

`CONTACT_FROM` sets the from-address. With Resend and no from-address the
sandbox sender `onboarding@resend.dev` is used, which only delivers to the
account's own address until a sending domain is verified - so a domain must be
verified before members receive replies.

The Gmail app password for `coopvestafrica@gmail.com` is not in this repo and
not in `render.yaml`; only the key name is there, with no value. Supabase's
`smtp_pass` is *not* a substitute: the management API returns it encrypted and
the plaintext is rejected by Gmail. Do not paste a password into a commit or a
shell command; set it in the Render dashboard, then confirm a reply reports
`emailed: true`.
