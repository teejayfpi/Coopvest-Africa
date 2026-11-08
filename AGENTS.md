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

## Navigation: a route name is a contract
`Navigator.pushNamed` to a name that is not in `main.dart`'s `routes` map throws
inside the navigation machinery. The global search screen shipped 23 advertised
destinations against a route table that defined fewer than half of them, so most
results were a crash or a dead tap.

- Add a route to `main.dart` in the same change that adds a `pushNamed` call for
  it. `test/unit/route_resolution_test.dart` reads the real route table and the
  real call sites and fails on any unresolved name — run it when you touch
  routing.
- `MaterialApp.onUnknownRoute` renders `RouteNotFoundScreen`. It is a backstop,
  not a licence to leave routes undefined.
- Do not list a feature in the search catalog until a screen exists behind it.

## Loan eligibility lives on the server
The six-month membership + contribution rule is enforced in
`backend/src/routes/loans.js` via `backend/src/lib/loanPolicy.js`. It is **on by
default**. Never re-introduce a client-side `isEligible = true`; the app's check
is a courtesy that mirrors the server, not the gate. Staging can opt out with
`LOAN_MIN_ELIGIBILITY_DISABLED=true`.

## Interest calculation (mobile-aligned)
The backend interest logic in `src/services/referralService.js` MUST mirror the
mobile app (`lib/presentation/screens/loan/loan_application_screen.dart`):

- `BASE_RATES` per loan type: Quick Loan 7.5%, Flexi 7.0%, Stable (12m) 5.0%,
  Stable (18m) 7.0%, Premium 14.0%, Maxi 19.0%. Legacy Micro/Business/Emergency
  kept for old loans.
- `MIN_FLOORS` = half of each base rate.
- Referral tier bonus: 2% / 1% / 0.5% at 10 / 5 / 2 confirmed referrals.
- **Total repayment is the authoritative figure** = SIMPLE interest:
  `amount + (amount * effectiveRate / 100)`. This is what `loans.total_repayment`
  holds and what `remaining_balance` is drawn down against.
- **Monthly repayment is DERIVED from the total**: `totalRepayment / tenureMonths`.

### The invariant: `monthlyRepayment × tenureMonths === totalRepayment`, exactly

These two were once computed independently — a reducing-balance EMI for the
instalment and simple interest for the total — so they disagreed. At ₦900,000 /
5% / 12 months the instalments summed to ₦924,560.76 against a ₦945,000 total
(₦20,439 short); on a ₦1,000,000 Maxi loan they over-repaid by ₦129,617. The
summary, repayment schedule, wallet monthly obligation and admin reports all
read `monthly_repayment`, while arrears and the balance read `total_repayment`,
so the two must reconcile **by construction**. Do not reintroduce a separate
EMI formula here.

`backend/__tests__/referralService.test.js` asserts this invariant across all
six products. It previously did **not** — it defined a private
`ReferralServiceTestHelper` with a different rate table (`PERSONAL: 15,
EMERGENCY: 12, BUSINESS: 18`) and tested that copy, so the real maths had zero
coverage. Always `require('../src/services/referralService')` directly.

### Fixed tenure per product
`isTenureAllowed` (`loanPolicy.js`) pins the tenure to the product: Quick 4,
Flexi 6, Stable 12/18, Premium 24, Maxi 36. `POST /loans/apply` rejects a
mismatch with `INVALID_TENURE`; legacy products (Micro/Business/Emergency) accept
1–60.

### Contribution status vocabulary must match everywhere
`loanPolicy.countContributionMonths` counts the settled set — `successful`,
`completed`, `approved`, `paid`. The app's eligibility check
(`loan_application_screen.dart`) and the wallet balance count the same set. They
once disagreed (server: `successful` only), so a contribution stored as
`completed` made the app say "eligible" and the server answer 403. Note
`bulk/import-contributions` still writes to `transactions`, not `contributions`,
so imported history does not count toward eligibility.

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

## Registration fee: a self-declared employer defers, it does not exempt

`isRegistrationFeeSettled` / `isAdministrativeFeeExempt`
(`backend/src/lib/activationGate.js`) exempt a salary-deduction member whose fee
is recovered from salary, and the SQL twin
`public.member_registration_fee_settled()` (migration 063) mirrors them.

The two kinds of "employer on file" are NOT equivalent, and conflating them was
a live fee-evasion hole:

- **Linked** (`profiles.organization_id`) — an admin approved the enrolment, so
  the fee is exempt indefinitely.
- **Named** (`profiles.pending_organization_name`) — self-declared and
  unverified. It only *defers* the fee, for
  `PENDING_EMPLOYER_FEE_GRACE_DAYS` (default 45) counted from
  `pending_organization_requested_at`. Past that the fee is payable in the app
  again.

Without the bound, a member could register as salary deduction, type any
employer name, and never pay the ₦5,000 registration fee or the ₦1,500 monthly
administrative fee — no payroll batch can recover either from an employer that
was never enrolled, and nothing expired the claim.

The deferral anchor is written once and never moved: `planProfileChannelUpdate`
(`backend/src/lib/contributionChannel.js`) only sets
`pending_organization_requested_at` when it is absent, `/organizations/request-approval`
keeps the existing value, and a switch to direct deposit leaves it in place. A
re-save, a new employer name, or a round-trip through direct deposit must not
restart the window. Linking a verified employer clears it.

An anchor dated in the future must not count either. The elapsed time would be
negative, pass the window check, and defer the fee permanently — and the anchor
is a member-writable column, so that is reachable without privileged access. A
future anchor beyond a few minutes of clock skew is rejected in both the JS and
the SQL.

Clients must not be able to write the columns the exemption is derived from.
Migration 063 revokes `UPDATE` on `contribution_method`, `contribution_type`,
`pending_organization_name` and `pending_organization_requested_at` from `anon`
and `authenticated`, and asserts the revoke so a later migration cannot silently
undo it.

**This revoke is load-bearing, not tidiness.** Verified against production
(project `nyoauzqezpxeonmrxxgi`) on 2026-11-03: `authenticated` held column-level
`UPDATE` on exactly those four columns (plus `name`, `phone`, `department`), and
a member-writable `profiles` UPDATE policy (`auth.uid() = id`) exists. So a
signed-in member could `PATCH /rest/v1/profiles?id=eq.<self>` with the anon key
that ships in the app and set `contribution_method='payroll'` and
`pending_organization_name='anything'` directly — bypassing the
active-organisation check in `/kyc/contribution-type` entirely. That is why the
exemption must not depend on the *value* of a member-writable column alone: the
grace window and the future-anchor check both bound it even if a write succeeds.
The only `profiles` writer using the anon-key path is the admin dashboard, and it
writes only `name`, `phone`, `department`, `updated_at` (none revoked). The
Flutter app uses Supabase for auth only — no table writes. The backend uses the
service role, which bypasses these grants.

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

### OTP codes are not 6 digits
`GOTRUE_MAILER_OTP_LENGTH` is a **server setting**, not a constant. This
project issues **8-digit** codes, so never hardcode `6` in a client length
check or a fixed-size OTP box. A screen that requires exactly 6 digits
silently rejects every valid code — the user cannot even type one in. Use a
single flexible field (12 chars) and a `>= 6` guard; `verifyOTP` is the
authority. Only change the length in Dashboard → Authentication → Sign In /
Providers → Email if you also want 6-digit codes.

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
`ContributionTypeSelectionScreen` (post-email-verification) asks
direct_deposit vs salary_deduction once. The onboarding `_ContributionStep`
no longer re-asks it — `contribution_method` is derived from `contributionType`
(`salary_deduction`→`'payroll'`, else `'manual'`). Removed `_MethodCard`.

## Notifications realtime
`notifications` must be in the `supabase_realtime` publication + `REPLICA
IDENTITY FULL` (see `backend/migrations/029_notifications_realtime.sql`),
or the app's `postgres_changes` INSERT channel (filter profile_id =
userId) never fires. Migration 029 handles it (applied via Mgmt API).

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
(wallet → savings, self-directed) and `savings/goals` (no money moves) — they
would be noise, not signal.

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

## Money movements are single database functions

Never move a balance with a read-then-write. `const b = row.balance; update({ balance: b + delta })`
loses updates under concurrency, and a sequence of such statements leaves the
wallet, the ledger and the owning record disagreeing when one step fails.

Every balance change goes through one `SECURITY DEFINER` function that locks the
rows it touches (`SELECT ... FOR UPDATE`) and does the whole movement — balance,
ledger row, owning record — in a single transaction. Migration 062 adds:

| Function | Purpose |
|---|---|
| `wallet_transfer` | member-to-member transfer; locks both wallets |
| `wallet_loan_repayment` | wallet → loan; rejects a repayment above the balance |
| `savings_move` | wallet ↔ savings, `p_direction` = `deposit`/`withdraw` |
| `verify_deposit_request` | admin deposit approval; locks the request |

Two rules follow from this:

- **Lock order is fixed** (e.g. wallets ordered by `id`) so opposite-direction
  transfers cannot deadlock. Keep any new multi-row function consistent.
- **These functions do not check `auth.uid()`** — they trust the profile id they
  are handed. So `EXECUTE` is revoked from `PUBLIC, anon, authenticated` and
  granted to `service_role` only. A new function must do the same, and the route
  must pass the *authenticated caller's* id, never an id from the request body.
  `backend/__tests__/securityReviewFixes.test.js` asserts both.

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
- `transactions.category` only permits `'credit'` and `'debit'`. The *kind* of
  movement belongs in `type` (`savings_deposit`, `loan_repayment`, …). Writing
  `category: 'savings_deposit'` violates `transactions_category_check` and
  throws — and in the savings routes it threw *after* the wallet and savings
  balances had already been moved, so every deposit/withdrawal broke silently.
- `handle_new_user` (trigger on `auth.users`) derives `user_id` as
  `USR-` + the first 8 characters of the profile UUID, and `user_id` is UNIQUE.
  When seeding two test users, give them UUIDs with **different first-8
  prefixes** or the second insert fails on `profiles_user_id_key`. The trigger
  also auto-creates the profile, wallet, savings and user_settings rows, so do
  not insert a `profiles` row by hand for a freshly inserted `auth.users` row.


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

## Money formatting must stay grouped
`Formatters.formatCurrency` (core/utils/utils.dart) groups thousands and keeps
2dp. Several screens used `toStringAsFixed(2)` directly, rendering
`₦100150000.00` next to the header's `₦100,150,000`. Use the shared formatter —
import it with `show Formatters` in files that also need string extensions, to
avoid an ambiguous-extension clash with `capitalize`.

## Admin notification broadcast actually sends push now
`POST /api/admin/notifications/broadcast` (adminApi.js) used to only insert
`notifications` rows and return `{success, sent}` — it never called FCM, so
the admin dashboard's "push" channel delivered nothing to devices while the
UI reported success. The response had no `push` field, so the dashboard toast
always rendered "Push was not delivered — no registered devices or Firebase is
not configured", which was also factually wrong (13 active device_tokens
existed). The route now sends FCM via `notifyService.sendPush({tokens, ...})`
(one batched multicast), returns
`push: {targeted, errors, status, reason}`, and honours the `audience` and
`channels` it is sent. Only `push`/`in_app` are deliverable — `sendEmail`/
`sendSms` are stubs with no provider, so they come back in `notImplemented`
rather than being counted as sent. Audience/channel mapping lives in
`src/lib/notificationBroadcast.js` (unit tested) and reuses the same bucket
definitions as `GET /dashboard/summary`. Push needs
FIREBASE_PROJECT_ID/CLIENT_EMAIL/PRIVATE_KEY on Render; without them the send
is skipped as `no_firebase_credentials` and now says so in the UI.

## Sandbox notes for this backend
`npm install` then `npx jest --coverage=false` runs in ~1s. Do NOT delete
`backend/package-lock.json` while cleaning build artifacts — it is tracked.
The single-device session policy means an admin API token is rejected with
`SESSION_REPLACED` until `POST /api/auth/sync` is called; the dashboard does
this after login.
## Flutter toolchain — use a current stable
`pubspec.yaml` declares `sdk: '>=3.2.0 <4.0.0'`, but the code already uses APIs
that only exist in recent Dart: `Color.withValues`, `Color.toARGB32`,
`RadioGroup`, `Switch.activeThumbColor`, and `CardThemeData`. On an old SDK
(3.24.x / Dart 3.5) `flutter analyze` reports ~400 phantom errors such as
"The method 'withValues' isn't defined for the type 'Color'" — these are SDK
gaps, not code defects. Use Flutter 3.47.x (Dart 3.13) or newer; there the
project analyzes with 0 errors / 0 warnings.

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

### Report fixtures must not pin loan due dates to calendar dates
`default_report` and `default_statistics` classify a loan as overdue by
comparing `next_due_date` to "now", so a test fixture with a hardcoded due date
is a time bomb: it reads "not yet due" the day it is written and "overdue"
once real time passes it, failing a test whose code is correct. Use a relative
date (`daysFromNow(n)` in `__tests__/reporting.test.js`), not a literal, for
any fixture date the report logic compares against the clock.

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

## The anon key is PUBLIC — RLS is the only boundary (migration 047)
The Supabase anon key is embedded in the mobile app bundle AND in the admin
dashboard's shipped JS, so treat it as public. Anything without RLS is readable
by anyone who extracts it, bypassing the app and the API entirely.

This was not theoretical: device_tokens (13 FCM push tokens), profiles (BVN,
NIN, bank numbers), contributions, member_fees and organizations (411
remittance account numbers) were all readable with the anon key and no login.

Root causes worth remembering:
* `device_tokens`, `contributions`, `member_fees` had RLS **disabled entirely**
  (relrowsecurity = false) — a table with no RLS is world-readable.
* `profiles` had **three permissive `USING (true)` policies**. Postgres ORs
  permissive policies, so ONE such policy defeats every restrictive policy
  beside it. When adding a targeted policy, first DROP the broad ones — this
  bit twice (also on `announcements`).
* `organizations` had a single `FOR ALL USING (true)`.

The API is unaffected by RLS because it connects with the service role, which
bypasses RLS. So "the API works" proves nothing about exposure — probe with the
anon key directly (`/rest/v1/<table>?select=id`) to check.

Also note `req.path` vs route mounting, and that probing a table returning `[]`
can mean RLS-filtered OR genuinely empty; check `relrowsecurity` in pg_class to
tell them apart.

## Beware PRs whose title understates their scope
`fix/artifact-storage-quota-fix` presented as a small CI workflow change but was
318 files, +52,865/-30,011. It committed `backend/.env`, `android/keystore/
release-keystore.jks`, `android/key.properties` and OAuth client secrets into a
PUBLIC repo, and — being based on a stale commit — would have DELETED the
reporting suite, RBAC, comparative analytics, org finance and AGENTS.md.

Before merging someone else's PR here: check `changed_files` and `additions`,
list the files, and look for `.env`, `*.jks`, `*keystore*`, `*client_secret*`,
`google-services.json`. A `.gitignore` diff that REDUCES ignore coverage is a
red flag.

## RBAC: server-side permissions (feat/rbac-permissions)
`src/lib/permissions.js` (role + permission catalog, resolution) and
`src/middleware/requirePermission.js` (ordered path→permission table + guard),
mounted ONCE at the `/api/admin` prefix before every router so `req.path` is
the full sub-path and one table covers all admin routes.

Before this, `requireAdmin` admitted admin/superadmin/staff alike and only 8 of
67 write endpoints had a further check — a `staff` token could delete
contributions and reset member passwords. The dashboard's permission map is
frontend-only; never treat it as the boundary.

Rules: unclassified WRITE fails closed to `settings.write`; unclassified READ
needs only `dashboard.read` (so tightening writes cannot lock anyone out);
unknown role = no permissions; unknown permission name = denied even for the
apex role; row-level grants are additive and validated against the catalog.

`superadmin`/`super_admin` MUST resolve to `ceo` — mapping them anywhere lower
strips access from the only admin account in production. Dropping a role's
tier must take the MOST RESTRICTIVE limit, never the highest, or collapsing
`staff`+`admin` into `manager` would hand a staff approver admin's ceiling.

`approvalMatrix` had to become role-aware for the same reason: it compared raw
strings, so a user stored as `ceo`/`manager` matched no level and got a limit
of ZERO (the apex account would route its own loans to the Approval Center).
Every role holding `loan.approve` needs a configured limit or all its loans
get routed — a silent operational break caught by a test.

**Path trap:** the RBAC catalog is at `/rbac/catalog`, NOT `/permissions`.
`adminApi` does `router.use(governance)` and governance owns `/permissions`
with a legacy display-only list, so a new route at that path is unreachable.

Branch chain: `feat/reporting-suite` → `feat/comparative-analytics` →
`feat/organization-finance` → `feat/rbac-permissions`.

## Copying files between the two repos
`backend/src/server.js` DIFFERS between Latest-Coopvest and Coopvest-Africa by
~142 lines of legitimate divergence. NEVER `cp` it across repos — that silently
destroyed Coopvest-Africa's `requireActivated` guards and public login-recorder
once. Apply the specific edit with an editor and verify with
`git diff | grep "^-"` that only intended lines were removed.

## Verification email / OTP flow

Supabase mints a **new OTP on every send**, and the older code is not removed
from the inbox. So any path that sends twice leaves the user with two emails
holding two different codes, and no way to tell which to use.

`RegisterStep2Screen` used to resend on open whenever it was reached without a
deep link. Every sign-up path arrives there straight from a step that already
sent (signUp, or an explicit resend), so registration produced exactly that
duplicate. The screen now takes `emailAlreadySent`, passed through the
`/register-step2` route args as `email_already_sent: 'true'` by the callers
that have already sent. Only the login `EMAIL_NOT_VERIFIED` path, where nothing
is in flight, auto-sends.

Email bodies live in the Supabase dashboard, not this repo, so template changes
(keeping the mail code-only, with no links) cannot be made from here.

`teejayfpi/Coopvest-Africa` Actions can run; `coopvestafrica-ops/Latest-Coopvest`
Actions have been billing-blocked since 2026-09-24 (jobs never start, so a red
check there means nothing about the code), so use the public repo's `build-apk`
job to verify Dart changes actually compile.

## Registration-fee exemption (salary deduction)

The ₦5,000 registration fee is waived only for a member whose channel is
payroll/salary deduction **and** who has an employer on file. The rule lives in
three places and they must agree:

- `backend/src/lib/activationGate.js` → `isRegistrationFeeSettled` (what the API
  enforces; dependency-free so it can be unit tested standalone)
- `member_registration_fee_settled()` in the SQL migrations
- `User.hasSettledRegistrationFee` in `lib/data/models/auth_models.dart`, which
  reads the server's `activation_gate` flags rather than re-deriving the rule

An employer counts if it is linked (`organization_id`) or only requested
(`pending_organization_name`); the second case matters because withholding the
exemption until an admin approves the enrolment request locks the member out
over admin latency.

`profiles.contribution_method` / `contribution_type` are read by the gate, the
middleware and several routes but were created by no migration, so a fresh
environment fails the gate query. Migration 048 creates them and backfills the
channel from `kyc.personal_info`.

### Both sign-up routes must write the channel, not just the shortened one
The channel is written to `profiles` in exactly two places, and they must agree:

- `POST /kyc/contribution-type` — the shortened path;
- `POST /auth/complete-registration` — the full wizard, which posts the whole
  profile and never calls the former.

Both call `planProfileChannelUpdate()` in
`backend/src/lib/contributionChannel.js`, which is the single definition of the
write. It used to live only in `/kyc/contribution-type`, so a member who came
through the wizard (reachable when Supabase email confirmation is off — step 1
routes straight to `/register-step3`) kept a NULL channel: the fee exemption
could not fire and `contributionChannel()` classified them as direct deposit,
which also breaks guarantor eligibility. Migration 051 backfills those members.
Keep the two call sites on the one helper rather than re-deriving the mapping.

### Changing employer must not require a channel switch
`ContributionMethodScreen` used to save only when the channel *changed*, so a
member already on salary deduction had no way to move to a new employer.
`organization_id` drives both payroll deduction and the same-organisation
guarantor rule, so a member who changed jobs stayed attached to the employer
they left — payroll kept deducting for the old organisation and their guarantors
were matched against it. The screen now also saves on an employer-only edit
(`_employerChanged`), and the helper clears the previous `organization_id` when
a named employer does not resolve to an active organisation, so the old link
cannot linger. The route already re-flags KYC as `submitted` on any salary
update, so a new employer still goes through admin review.

Note the channel write is deliberately *not* cleared when salary deduction is
saved with no employer named: a settings toggle that collects no employer must
not erase the one already on file.

The screen picks the employer from the enrolled list (`_EmployerPickerSheet` →
`GET /organizations/selectable`) so the profile stores a real `organization_id`
rather than a free-text name. An employer that is not enrolled goes through
`requestOrganizationApproval` and is saved as a pending name. Keep sending the
id only for a picked employer — the backend re-checks it is a real, active
organisation before linking, and falls back to a pending name otherwise.

### The gate must be reachable-proof, not just present
A Direct Deposit member who had not paid could reach the dashboard by pressing
Back, relaunching, or re-logging in. Two things caused it, and both need to stay
fixed:

- **`/home` must be wrapped in `AuthGuard`** (`lib/main.dart`). It used to render
  `MainContainer` directly, so *every* `pushNamed('/home')` — notification tap,
  deep link, a button on a screen that had already checked the gate — skipped the
  guard entirely. `AuthGuard.signedOutChild` (defaults to `child`) is the
  welcome screen on the `/home` route so sign-out does not flash the dashboard.
- **The guard reads the server, not the cached profile** (`GET /app/home-status`).
  The profile's `registration_fee_paid` is exactly what goes stale on a
  back-press, which is the case the gate exists for. `AuthGuard` shows a spinner
  until the answer arrives and only falls back to the profile after two failed
  attempts, so a cold Render start does not strand a paying member.

Route the client on `registration_fee_settled`, **not** `activated`: the latter
also requires KYC approval, and re-using it re-blocks members who paid but are
awaiting KYC review. That split mirrors `requireRegistrationPaid` vs
`requireActivated` in `middleware/auth.js`.

### Every gate needs the test that would have caught the bypass
`backend/__tests__/registrationFeeEnforcement.test.js` and the
`registration-fee bypass (Direct Deposit)` group in
`test/unit/registration_gate_test.dart` pin the route-level and payload-level
shapes. The bug was a *reachability* gap, not a wrong boolean, so a test that
only asserts the exemption rule would not have caught it — assert the entry
point, too.

### Offline is "unknown", never "unpaid" — the false payment screen
Members with no network (or an unstable one) were landing on the ₦5,000 payment
screen for a fee they had already settled. The cause was the gate's fallback:
when `GET /app/home-status` failed, `AuthGuard` fell back to the cached profile's
fee flags, and those default to `false` on a cold start. The app was answering
"unpaid" when it meant "I could not ask".

The fix is an asymmetry, and it must stay asymmetric:

- **Settled is sticky.** `RegistrationFeeStatusStore` records a *server
  confirmation* of settlement on the device (keyed by member id). Offline, that
  is believed, so a paying member reaches the dashboard.
- **Unsettled is never cached.** There is deliberately no `markUnsettled`. A
  local "unpaid" would let a member clear the gate by going offline, which is the
  exact bypass the server re-check exists to stop.
- **When nothing permissive is known, the result is `GateDecision.unreachable`**
  — a retry screen (`OfflineGateScreen`), not the payment screen. An unreachable
  server may resolve to `active` or `unreachable`, **never** to `feePending`.

The decision is a pure function, `decideRegistrationFeeGate` in
`lib/presentation/widgets/auth_guard.dart`, so each rule is one testable call.
`test/unit/registration_fee_gate_test.dart` pins it, including an exhaustive
check that no offline combination yields `feePending`; reverting the fix makes
that test fail, which is how it was validated. The store is pinned separately in
`test/unit/registration_fee_status_store_test.dart` (survives relaunch, does not
leak between accounts on a shared device).

This is a UX false-negative, not a security hole: the backend still enforces
`requireRegistrationPaid`, so the dashboard this unlocks is refused by every
gated endpoint for a genuinely unpaid member.

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

## Deployment

`coopvest-api` on Render auto-deploys on every commit to `main`
(`autoDeployTrigger: commit`), so merging is deploying — the failing
`deploy-backend.yml` job is not what ships the backend. Migrations in this repo
are not run by CI, so a backend change goes live without anyone applying them:
check whether a new migration is load-bearing before relying on it.

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

A *present* key is not necessarily a *working* key. `paystackConfigured()`
(`backend/src/lib/paystackCharge.js`) checks the shape (present, `sk_` prefix,
not truncated) and logs the result at boot; a bad key otherwise shows up only
as an opaque "Online payment failed" at checkout. `POST /payments/initialize`
returns `503 { code: 'PAYMENT_UNAVAILABLE' }` with a member-safe message when
the gateway is not usable, so the app never surfaces the raw internal string.
Both backends (Render `coopvest-api` and the Vercel host) serve the same code
and share this behaviour.

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

## Fees & monthly obligations (mobile)
The member monthly obligation = savings contribution + loan repayment +
outstanding fines + outstanding fees. `GET /api/v1/wallet/obligations`
(`backend/src/routes/wallet.js` `computeObligations`) is the single source of
"amount due"; the app never derives it from the wallet balance.

- The monthly administrative charge is NGN1,500 = Administrative charges
  NGN1,000 + Development levy NGN500 (`AppConfig.totalMonthlyLevies`;
  `administrativeCharges`/`developmentLevy` are the parts). The `fee_types`
  catalogue calls it **Administrative Fee** (renamed from "Mobile App Fee" in
  migration 055). `member_fees.label` copies the catalogue name at assignment
  time, so a rename must relabel existing rows too.
- The registration fee (NGN5,000, one-time, non-refundable) is a charge payable
  to the cooperative. It is **not** added to, or collected with, the member's
  monthly contribution — that wording appeared in the disclosure and was wrong.
  A member's contribution is their own savings; the fee sits outside it. The
  disclosure must say so, and `feeDisclosure.test.js` fails if the bundling
  wording returns to the terms document, the served schedule, or the bundled
  Flutter copy.
- **Pay Now** (`lib/presentation/widgets/obligations_card.dart`) must charge
  `savingsDue + monthlyLoanRepayment + finesTotal + feesTotal` and pass a
  per-obligation `initialAllocations` breakdown to `DepositScreen`. Charging the
  headline while passing a single allocation type silently drops the fee - the
  whole payment lands in savings. Regression:
  `test/widget/obligations_payment_test.dart`.
- A split payment carries `fee_id` per allocation so the backend settles the
  exact `member_fees` row shown as due, not merely the oldest outstanding one.

### Salary-deduction members are exempt from the in-app administrative fee
A member whose contributions are withheld by an employer has the monthly
administrative fee recovered from their salary, so `computeObligations`
(`backend/src/routes/wallet.js`) omits it from `fees` and sets
`administrative_fee_exempt: true`. Same mechanism as the registration-fee
exemption (`isAdministrativeFeeExempt` in `backend/src/lib/activationGate.js`):
the channel must be payroll AND an employer must be on file
(`organization_id` or `pending_organization_name`) - without an employer there
is no deduction to recover from, so the in-app obligation stands. Only the
identified administrative-fee row is hidden (matched on `fee_type_id`, with the
label as fallback); fines and other fees stay payable. Tests:
`backend/__tests__/administrativeFeeExemption.test.js`.

## Client IP must come from Express, and `trust proxy` must be a hop count
The rate limiters, the admin IP whitelist and the login-history recorder all
depend on the client IP. Two ways that was wrong, both now pinned by
`backend/__tests__/ipWhitelist.test.js` and `routeExposure.test.js`:

- `app.set('trust proxy', true)` trusts the entire `X-Forwarded-For` chain and
  resolves `req.ip` to its **left-most** entry, which any caller can forge. A
  client could then send a fresh fake IP per request and bypass the limiters.
  Render's load balancer is a single hop, so the setting is the hop count `1`
  (override with `TRUST_PROXY`). Never set it to `true`.
- The code read `req.headers['x-forwarded-for']` directly in several places
  (both limiters, the whitelist's `getClientIP`, the login recorder). Those must
  use `req.ip`. The whitelist's header fallback takes the **right-most** entry
  (what the trusted proxy appended), never the left-most.

`cleanIP` had a latent bug: `!ip.startsWith['[']` indexed the function with
`'['` (always `undefined`), so the port-strip branch never excluded bracketed
IPv6. Fixed to `!ip.startsWith('[')`.

## The public login recorder is unauthenticated by design - keep it bounded
`POST /api/admin/login-history/log` cannot require a JWT: a *failed* login has no
session, and the dashboard calls it before sign-in completes. It is therefore
rate-limited (`PUBLIC_LOG_RATE_LIMIT_MAX`, keyed on `req.ip`) and attributes the
event by the submitted **email only** - the body's `profile_id` is ignored, so a
caller cannot attach a forged login event or a disabled-account alert to an
arbitrary profile. Do not reintroduce trust in a body-supplied profile id here.

## CI runs the suite from a backend-only checkout under Node 22
The test suite is run by `.github/workflows/backend-tests.yml` on `push` to
`main`. Three constraints, each learned from a red run:

- **Node 22, not 20.** `@supabase/realtime-js` throws at `createClient` without
  a native `WebSocket`, which Node 20 lacks. Every suite that imports the
  Supabase client failed to load under Node 20 — while passing locally and in
  production, both of which run Node 22+. If you pin Node in a workflow, pin 22.
- **Only this repository is checked out.** Suites must not read files from a
  sibling checkout at module load. `adminWalletOperations.test.js` read the
  Admin-Dashboard page and `clientEndpointContracts.test.js` read the Flutter
  loan screen; both threw `ENOENT` at require time and failed the whole suite.
  Guard such reads with `fs.existsSync` and `describe.skip`, or the assertions
  will never run in CI. Do not add a cross-repo read without a guard.
- **`npm ci` against the committed lockfile.** A test that passes against a
  local `node_modules` can still fail here. Reproduce with a clean install in a
  copy of `backend/` before trusting a local green.

`deploy-backend.yml` (Render) depends on the Backend Tests job, so a failing
suite blocks the deploy.

## Production serves every dependency version - the app is Node 22+
`render.yaml` pins no Node version, so Render uses its current default (22+).
This is why the app works in production but the suite failed under Node 20.
If you ever need to lower the Node version, `ws` is already a dependency and
must be passed to `createClient` as the Realtime transport.

## The Admin-Dashboard deploys through Vercel's Git integration, not Actions
Vercel builds every push to `main` for `coopvestafrica-ops/Admin-Dashboard`
(the project `admin-dashboard-api-server` is Git-linked to that repo). The
GitHub Actions workflow does **not** deploy: it previously ran `vercel --prod`
with a `VERCEL_TOKEN` secret that is invalid, so it failed on every run from at
least 2026-10-28 while the site kept deploying normally.

Consequences to preserve:
- The deploy gate lives in `vercel.json` as
  `buildCommand: npm run typecheck && npm run build`. Putting a gate in the
  Actions workflow does nothing for this repo — it is not on the deploy path.
  `vite build` uses esbuild, which strips types without checking them, so
  without the typecheck in the build command a type error deploys happily.
- Do not reintroduce a second deploy path. Two paths race and the one inside
  Vercel cannot be skipped.

The `VERCEL_TOKEN` in the repository is valid (account `coopvestafrica-ops`);
the stored GitHub secret is stale. Update it only if a Vercel API call from
Actions is actually needed.

## Server errors alert operators over the webhook
`errorHandler` calls `alertService.sendSystemErrorAlert` for 5xx responses.
This uses the existing `ALERT_WEBHOOK_URL` channel, not email, so it does not
depend on SMTP. Alerts are throttled to one per `SYSTEM_ALERT_MIN_INTERVAL_MS`
(default 5 minutes) and the next alert reports how many were suppressed — a
failing dependency makes every request fail at once, and an unthrottled channel
gets muted exactly when it is needed. The method never throws: it runs on the
error path, so a failed alert must not become a second error. 4xx does not
alert — a bad request is not an incident.

## The secret scanner must match the real leak, not a longer shape
The connection-string pattern in `.github/workflows/secret-scanning.yml` is
`postgresql://postgres\.[A-Za-z0-9_.%-]{12,}@`. It previously required 100+
characters, which is longer than a real leaked password, so it never fired. The
same shape is in the history scan, which otherwise only looked for a JWT-style
service key. Test a new pattern against the actual value before committing it,
and confirm it does not match `governanceSchema.js`, which builds the URL from
`encodeURIComponent(DB_PASSWORD)` and must not be flagged.

## Supabase grants every table to anon and authenticated - revoke per table
`ALTER DEFAULT PRIVILEGES` in `public` grants INSERT/UPDATE/DELETE to `anon` and
`authenticated`, so **every new table arrives client-writable**. A table is only
safe once its grants are revoked; enabling RLS alone does not do it, because a
permissive policy on a row the caller owns still lets the caller rewrite every
column in that row.

Migration 059 fixed `profiles` by revoking table-level UPDATE and granting back
only the columns a member may change. Migration 061 generalises that: it revokes
write grants on all tables except a short list of user-owned, non-financial ones,
drops the now-inert write policies, and clears the default privileges.

The live audit found 96 tables still client-writable. On `wallets`,
`transactions`, `savings` and `loans` the policy is
`FOR ALL USING/WITH CHECK (profile_id = auth.uid())`, which a caller satisfies
with a row they own — so a signed-in member could set their own `balance` and
insert a `completed` deposit. Verified on the live database before the fix.

When adding a table, or a column that holds money or a privilege:
- do not assume RLS protects it; check `has_table_privilege('authenticated', ...)`;
- a `FOR ALL` policy on an owned row is a write grant to that row, not a guard;
- guard money columns with a trigger or a `SECURITY DEFINER` function if a client
  ever needs to write the row.

Verify a change the way migration 061 was verified: `SET LOCAL role authenticated`
plus `set_config('request.jwt.claims', ...)` inside a transaction that is rolled
back, so the assertion runs under the real policy without changing data.

## Only migrations listed in MIGRATIONS are applied automatically
`backend/src/config/governanceSchema.js` applies the files in its `MIGRATIONS`
array on every boot, using the `postgres` owner role. Every other file in
`backend/migrations/` has to be applied by hand, so a new table a route depends
on will not exist in production just because its SQL was merged. Add the file to
the array, and keep it idempotent - it runs on each start.

**The runner does not currently run in production.** It needs
`SUPABASE_DB_PASSWORD` or `SUPABASE_DB_URL`, and Render has neither set (only
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_ANON_KEY`). On boot it
logs `governance schema bootstrap skipped` and returns, so every migration to
date was applied by hand. Merging a migration therefore changes nothing in
production until someone runs it. Setting either variable activates the runner on
the next deploy, which would apply all four listed files at once.

Until that is decided, apply migrations explicitly and verify the result against
the live database, rather than assuming a merge deployed them.

`pg_default_acl` in `public` has two entries: one owned by `postgres`, one by
`supabase_admin`. `postgres` can change its own and not the other's, so a table
created from the Supabase dashboard still arrives client-writable. The migration
warns rather than fails on that, and its assertion catches the result.

## Published charges must equal levied charges

Every charge a member bears is declared once, in
`backend/src/config/feeDisclosure.js`. The routes and workers that levy a charge
import the amount from there, and the member-facing disclosure
(`backend/src/config/terms.json`, section `fees_and_charges`) is checked against
the same constants by `backend/__tests__/feeDisclosure.test.js`.

The reason for the indirection is that the two sides get edited separately for
different reasons - someone tunes the penalty, someone rewrites the leaflet -
and they drift. A disclosure that says ₦3,000 while the code charges ₦5,000 is
worse than no disclosure: the member relied on it.

So when a charge changes:

1. Change the constant in `feeDisclosure.js`.
2. Update the `fees_and_charges` body in `terms.json` to match, and bump its
   `version`.
3. Mirror the same edit into `lib/data/models/terms_content.dart` (the offline
   fallback) and bump its bundled `version` to match.
4. `npx jest feeDisclosure` must pass. It fails if any published figure is not a
   known charge, or if a levied amount is not published.

Do not hardcode an amount at a call site. `loans.js` and `loanRecoveryWorker.js`
both read `LATE_REPAYMENT_FINE`; the worker's notification text interpolates
`FINE_LABEL` rather than quoting a figure, so a change cannot leave a stale
number in a member's inbox. A test asserts no template literal in the worker
contains a hardcoded naira amount.

Charges the member does **not** bear do not go in the disclosure - and the
disclosure says so explicitly, because a member reading a fee list reasonably
wonders about the ones that are absent. Today it states there is no withdrawal
fee, no early-repayment penalty, and no account-maintenance charge beyond the
monthly administrative fee. Those negatives are verified, not assumed: the
savings, termination and loan routes apply no fee.

### The disclosure must reach existing members, not only new ones

Onboarding requires every terms section to be opened and accepted, so a new
member meets the disclosure. A member who joined earlier does not - and there is
no re-acceptance mechanism keyed on `terms_version`, so bumping the version does
not pull anyone back through onboarding. The entry point for them is
Profile → Settings → About → **Fees & Charges**, which reads the same document
the backend serves rather than the bundled copy, so they see current figures.

If a change to charges should be actively acknowledged by existing members, that
is a separate piece of work: nothing today compares the stored `terms_version`
against the current one.

### The corporate website publishes the same figures, from the same source

`GET /api/v1/fees` (`backend/src/routes/fees.js`) serves the schedule as JSON,
derived entirely from `feeDisclosure.js`. It is public, like `/api/v1/terms`.

The website repository (`coopvestafrica-ops/coopvest-website-`) builds its
Schedule of Charges page from that response. `tools/sync_fee_schedule.py` fetches
it into `src/data/fee-schedule.json`, and `build.py` renders the page from that
file - no figure is typed into the page, and `tools/check_charges.py` fails the
build if one is.

Two consequences worth knowing:

- **A change to a charge now lands in three places, not two.** After editing
  `feeDisclosure.js`, run `python3 tools/sync_fee_schedule.py && python3 build.py`
  in the website repository and commit the result. The website's Verify job
  rebuilds and fails if the committed pages are stale.
- **The website deploy fetches this endpoint before building**, and that step is
  fatal on failure. If the backend is unreachable the website deploy stops rather
  than publishing a stale price. `build.py` itself makes no network call, because
  it runs offline in CI.

So the endpoint's shape is a contract with a repository outside this one. Adding a
field is safe; renaming or removing `charges[].amount`, `charges[].label`,
`loan_interest_rates` or `not_charged` breaks the website build. If the shape must
change, change both repositories in the same session.
