# Referral Program — Canonical Specification

This document is the single source of truth for the referral program. Every
layer (backend `referralService.js`, mobile `referral_models.dart` /
`referral_provider.dart`, and the Admin Dashboard referral page) must agree with
it. If code and this document disagree, the code is wrong.

## 1. What a member earns

A referral earns the referrer a **percentage discount on loan interest**, not a
cash payout. The discount is tiered by the number of *confirmed* referrals.

There is **no cash bonus** in this program. The Admin Dashboard's
`bonusAmount` field is a *per-referral cash value used only to report the
notional value of the discount in admin analytics*; it does not credit any
wallet. (See §6.)

### Tier table (authoritative)

| Confirmed referrals | Interest discount |
|---------------------|-------------------|
| 0–1                 | 0%                |
| 2–4                 | 0.5%              |
| 5–9                 | 1.0%              |
| 10+                 | 2.0%              |

The discount is applied to the loan's **base interest rate** for the product:

```
effectiveRate = max(baseRate - tierBonus, minimumFloor)
```

`minimumFloor` is **half of the product's base rate** — a referral can never
reduce interest by more than 50%.

### Base rates and floors

| Product                   | Base rate | Floor |
|---------------------------|-----------|-------|
| Quick Loan                | 7.5%      | 3.75% |
| Flexi Loan                | 7.0%      | 3.5%  |
| Stable Loan (12 months)   | 5.0%      | 2.5%  |
| Stable Loan (18 months)   | 7.0%      | 3.5%  |
| Premium Loan              | 14.0%     | 7.0%  |
| Maxi Loan                 | 19.0%     | 9.5%  |
| Micro / Business / Emergency (legacy) | 18 / 20 / 12 | half of base |

### Money formulas (must reconcile exactly)

- **Total repayment** (authoritative, simple interest):
  `total = amount + amount × effectiveRate / 100`
- **Monthly repayment** is *derived* from the total, never a separate
  reducing-balance EMI: `monthly = total / tenureMonths`

The invariant `monthly × tenureMonths === total` must hold to the cent.
`backend/__tests__/referralService.test.js` enforces this.

## 2. Referral lifecycle

```
shared code ──▶ pending event ──▶ qualified ──▶ confirmed ──▶ (counts toward tier)
   │                                 │
   │                                 └─ lock-in: 30 days from event creation
   └─ referred member must sign up with the code
```

1. **Attribution** — when a new member registers with a referral code, the
   backend creates a `referral_events` row (`confirmed = false`). Attribution
   happens server-side at signup; it is never trusted from the client alone.
2. **Lock-in** — an event cannot be confirmed before `lock_in_end_date`
   (creation + 30 days).
3. **Qualification** — the referred member must:
   - have `kyc_verified = true`, and
   - have at least **3 consecutive savings months**
     (`savings.consecutive_months >= 3`).
4. **Confirmation** — only a qualifying event may be confirmed. Confirmation
   sets `confirmed = true`, `confirmed_at`, and recomputes the referrer's
   `confirmed_referral_count` and `current_tier_bonus`.
5. **Consumption** — each confirmed event grants **one** discount, consumed when
   the referrer applies for a loan with `applyReferralBonus = true`. Consumption
   sets `bonus_consumed = true` and `consumed_at`.

### Bonus availability

A bonus is available for a loan application when the referrer has at least one
confirmed, unflagged, unconsumed event **whose lock-in has completed**. The
discount percentage is the referrer's current tier bonus.

## 3. Abuse rules

- **No self-referral**: referrer and referred must differ.
- **One referrer per member**: a member can be referred only once. A second
  attempt returns `Already referred by another user`.
- Flagged events (`is_flagged = true`) never count toward tiers or bonuses.

## 4. Share links

Referral links must point at one host, configured by `APP_BASE_URL`
(fallback `https://coopvestafrica.com`), using the `/join?ref=<CODE>` path:

```
shareLink = ${APP_BASE_URL}/join?ref=<CODE>
```

`GET /referrals/my-code` and `GET /referrals/share-link` must return the same
`shareLink` / `qrCodeUrl` for the same member.

## 5. Referral codes

Format: `CV-` followed by 6 characters from `A-Z0-9` (excluding `O` and `I` to
avoid transcription errors). Generated lazily on first access to any referral
endpoint. Codes are unique.

## 6. Admin dashboard contract

`GET /api/admin/referrals` returns:

- `settings.enabled` — whether the program is on
  (`referral_settings.enabled`).
- `settings.bonusAmount` — the configured **notional cash value per confirmed
  referral**, used only for reporting; it does not credit wallets.
- `settings.maxReferralsPerUser` — informational cap.
- `settings.tiers` — the tier table above, for display.
- `leaderboard[]` — per-referrer `referralsMade`, `confirmedReferrals`,
  `bonusPercent` (current tier), `bonusEarned` (confirmed × `bonusAmount`).
- `analytics` — `totalThisMonth` (confirmed this calendar month),
  `totalBonusPaid` (Σ `bonusEarned`), `conversionRate`
  (`confirmed / total × 100`).

`PUT /api/admin/referrals/settings` persists `enabled`, `bonusAmount` and
`maxReferralsPerUser` to `referral_settings`. When `enabled` is false the
backend should reject new attributions and bonus applications.

## 7. Feature flags

The program is gated by the backend flag `referralSystem`
(`middleware/featureFlags.js`). Missing flags default to enabled. The mobile
`referral_program` flag is a *client-side mirror* only — it must not be the
sole gate.

## 8. Schema

`referral_settings` (single row, id = 1). The flag column is
`program_enabled`, which is what production uses:

```sql
CREATE TABLE IF NOT EXISTS public.referral_settings (
  id INTEGER PRIMARY KEY DEFAULT 1,
  program_enabled BOOLEAN DEFAULT true,
  bonus_per_referral DECIMAL(18, 2) DEFAULT 2000,
  max_referrals_per_user INTEGER DEFAULT 50,
  minimum_deposit_for_bonus DECIMAL(18, 2) DEFAULT 5000,
  bonus_payout_delay_days INTEGER DEFAULT 7,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT referral_settings_single_row CHECK (id = 1)
);
```

`GET /api/admin/referrals` reports this flag as `settings.enabled` in its JSON
response. The API reads and writes `program_enabled`; it falls back to an
`enabled` column if a database has that instead, so the two schemas cannot
drift into a silent save failure again.

`referrals` and `referral_events` are defined in `supabase_schema.sql`.
`referral_events.referral_code` is `NOT NULL` — every insert must supply it.
`referral_events.lock_in_end_date` is added by
`migrations/040_schema_alignment_audit.sql`.
