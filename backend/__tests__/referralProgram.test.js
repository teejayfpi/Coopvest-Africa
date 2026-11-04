/**
 * Tests for the referral program rules and wiring.
 *
 * The reward model, tier table, lock-in, qualification and attribution flow
 * are specified in REFERRAL.md. These exercise the real service and assert
 * that the routes actually call it — the previous code defined the tier table
 * in three places that disagreed (backend 0.5/1/2 @ 2/5/10, mobile
 * 2/3/4 @ 2/4/6, and the admin dashboard a flat cash bonus), and the
 * confirmation route could not refresh a tier at all.
 */

const fs = require('fs');
const path = require('path');
const referralService = require('../src/services/referralService');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');

describe('referral tier table (single source of truth)', () => {
  it('matches REFERRAL.md: 0.5% / 1% / 2% at 2 / 5 / 10 confirmed', () => {
    const cases = [
      [0, 0],
      [1, 0],
      [2, 0.5],
      [4, 0.5],
      [5, 1],
      [9, 1],
      [10, 2],
      [25, 2],
    ];
    for (const [count, bonus] of cases) {
      expect(referralService.calculateTierBonus(count)).toBe(bonus);
    }
  });

  it('treats a missing or non-numeric count as zero', () => {
    expect(referralService.calculateTierBonus(undefined)).toBe(0);
    expect(referralService.calculateTierBonus(null)).toBe(0);
    expect(referralService.calculateTierBonus('nonsense')).toBe(0);
  });

  it('reports progress toward the next tier', () => {
    expect(referralService.tierProgress(3)).toMatchObject({
      bonusPercent: 0.5,
      nextTierAt: 5,
      nextTierBonus: 1,
      referralsToNextTier: 2,
      isMaxTier: false,
    });
    expect(referralService.tierProgress(10)).toMatchObject({
      bonusPercent: 2,
      nextTierAt: null,
      referralsToNextTier: 0,
      isMaxTier: true,
    });
  });

  it('exposes the tier table for the admin dashboard', () => {
    expect(referralService.getTierTable()).toEqual([
      { minConfirmed: 10, bonusPercent: 2.0 },
      { minConfirmed: 5, bonusPercent: 1.0 },
      { minConfirmed: 2, bonusPercent: 0.5 },
      { minConfirmed: 0, bonusPercent: 0 },
    ]);
  });

  it('caps the maximum bonus at 2%', () => {
    expect(referralService.calculateTierBonus(1000)).toBe(2);
  });
});

describe('lock-in and consumability', () => {
  const now = new Date('2026-06-01T00:00:00Z');

  it('treats a missing lock_in_end_date as complete (legacy rows)', () => {
    expect(referralService.isLockInComplete({}, now)).toBe(true);
  });

  it('is incomplete before the lock-in date and complete after', () => {
    expect(referralService.isLockInComplete({ lock_in_end_date: '2026-06-02T00:00:00Z' }, now)).toBe(false);
    expect(referralService.isLockInComplete({ lock_in_end_date: '2026-05-31T00:00:00Z' }, now)).toBe(true);
  });

  it('only spends confirmed, unflagged, unconsumed, past-lock-in events', () => {
    const base = {
      confirmed: true,
      is_flagged: false,
      bonus_consumed: false,
      lock_in_end_date: '2026-05-01T00:00:00Z',
    };
    expect(referralService.isEventConsumable(base, now)).toBe(true);
    expect(referralService.isEventConsumable({ ...base, confirmed: false }, now)).toBe(false);
    expect(referralService.isEventConsumable({ ...base, is_flagged: true }, now)).toBe(false);
    expect(referralService.isEventConsumable({ ...base, bonus_consumed: true }, now)).toBe(false);
    expect(referralService.isEventConsumable({ ...base, lock_in_end_date: '2026-07-01T00:00:00Z' }, now)).toBe(false);
    expect(referralService.isEventConsumable(null, now)).toBe(false);
  });
});

describe('qualification rules', () => {
  it('requires KYC and 3 consecutive savings months', () => {
    const ok = referralService.evaluateQualification({ kycVerified: true, consecutiveSavingsMonths: 3 });
    expect(ok).toMatchObject({
      qualified: true,
      kycVerified: true,
      savingsCriteriaMet: true,
      requiredSavingsMonths: 3,
    });
  });

  it('fails without KYC even when savings are enough', () => {
    const r = referralService.evaluateQualification({ kycVerified: false, consecutiveSavingsMonths: 12 });
    expect(r.qualified).toBe(false);
    expect(r.savingsCriteriaMet).toBe(true);
  });

  it('fails with insufficient savings even when KYC is done', () => {
    const r = referralService.evaluateQualification({ kycVerified: true, consecutiveSavingsMonths: 2 });
    expect(r.qualified).toBe(false);
    expect(r.kycVerified).toBe(true);
  });

  it('coerces a missing savings count to zero', () => {
    expect(referralService.evaluateQualification({ kycVerified: true }).qualified).toBe(false);
  });
});

describe('canConfirm', () => {
  const now = new Date('2026-06-01T00:00:00Z');
  const qualified = { qualified: true };
  const unqualified = { qualified: false };
  const openEvent = {
    confirmed: false,
    is_flagged: false,
    lock_in_end_date: '2026-05-01T00:00:00Z',
  };

  it('allows a qualified event whose lock-in has elapsed', () => {
    expect(referralService.canConfirm(openEvent, qualified, now).ok).toBe(true);
  });

  it('refuses while the lock-in is still running', () => {
    const gate = referralService.canConfirm({ ...openEvent, lock_in_end_date: '2026-07-01T00:00:00Z' }, qualified, now);
    expect(gate.ok).toBe(false);
    expect(gate.reason).toMatch(/lock-in/i);
  });

  it('refuses an unqualified referred member', () => {
    const gate = referralService.canConfirm(openEvent, unqualified, now);
    expect(gate.ok).toBe(false);
    expect(gate.reason).toMatch(/qualification/i);
  });

  it('refuses a flagged or already-confirmed event', () => {
    expect(referralService.canConfirm({ ...openEvent, is_flagged: true }, qualified, now).ok).toBe(false);
    expect(referralService.canConfirm({ ...openEvent, confirmed: true }, qualified, now).ok).toBe(false);
  });

  it('refuses a missing event', () => {
    expect(referralService.canConfirm(null, qualified, now).ok).toBe(false);
  });
});

describe('signup attribution wiring', () => {
  it('auth.js attributes the referral server-side', () => {
    const src = read('src/routes/auth.js');
    expect(src).toContain("require('../services/referralService')");
    expect(src).toContain('attributeReferral');
    // The referred profile id must be the created profile, not client input.
    expect(src).toMatch(/referredProfileId:\s*profile\.id/);
  });

  it('attribution is best-effort and cannot fail a registration', () => {
    const src = read('src/routes/auth.js');
    const idx = src.indexOf('attributeReferral');
    const region = src.slice(idx - 200, idx + 400);
    expect(region).toContain('try {');
    expect(region).toContain('catch');
  });
});

describe('confirmation and claim wiring', () => {
  it('confirm routes delegate to the gated service method', () => {
    const src = read('src/routes/referrals.js');
    expect(src).toContain('confirmReferralEvent');
    // Neither confirm route may set `confirmed` directly — that would skip
    // lock-in and qualification.
    const code = src
      .split('\n')
      .filter((l) => !l.trim().startsWith('*') && !l.trim().startsWith('//'))
      .join('\n');
    expect(code).not.toMatch(/\.update\(\{\s*confirmed:\s*true/);
  });

  it('the literal /events/:id/confirm route is declared before /:referralId', () => {
    const src = read('src/routes/referrals.js');
    const eventsIdx = src.indexOf("'/events/:id/confirm'");
    const genericIdx = src.indexOf("'/:referralId/confirm'");
    expect(eventsIdx).toBeGreaterThan(-1);
    expect(genericIdx).toBeGreaterThan(-1);
    expect(eventsIdx).toBeLessThan(genericIdx);
  });

  it('the claim endpoint uses the shared attribution helper', () => {
    const src = read('src/routes/referrals.js');
    expect(src).toMatch(/router\.post\(\s*'\/claim'/);
    expect(src).toContain('attributeReferral');
  });

  it('every referral_events insert supplies the NOT NULL referral_code', () => {
    const src = read('src/services/referralService.js');
    const inserts = src.split('.insert(').slice(1);
    const eventInserts = inserts.filter((chunk) => chunk.includes('referrer_id'));
    expect(eventInserts.length).toBeGreaterThan(0);
    for (const chunk of eventInserts) {
      expect(chunk).toContain('referral_code:');
    }
  });
});

describe('share-link consistency', () => {
  it('share links use one host and the /join path', () => {
    const src = read('src/services/referralService.js');
    expect(src).toContain('APP_BASE_URL');
    expect(src).toContain('/join?ref=');
    expect(src).not.toContain('coopvest.app');
  });

  it('my-code and share-link build the same URL', () => {
    const routes = read('src/routes/referrals.js');
    expect(routes).toMatch(/qrCodeUrl:\s*`\$\{baseUrl\}\/join\?ref=\$\{referralCode\}`/);
  });
});

describe('admin referral settings', () => {
  it('the settings table is defined in the base schema and a migration', () => {
    expect(read('supabase_schema.sql')).toContain('public.referral_settings');
    expect(fs.existsSync(path.join(__dirname, '..', 'migrations', '058_referral_settings.sql'))).toBe(true);
  });

  it('the settings write persists the enabled flag to the real column', () => {
    const src = read('src/routes/adminApi.js');
    const idx = src.indexOf("router.put('/referrals/settings'");
    const region = src.slice(idx, idx + 1600);
    // Persisted via the production column name, with a fallback probe.
    expect(region).toContain('program_enabled');
    expect(region).toContain('flagColumn');
  });

  it('the admin overview reports the tier table, not just a cash bonus', () => {
    const src = read('src/routes/adminApi.js');
    const idx = src.indexOf("router.get('/referrals'");
    const region = src.slice(idx, idx + 2500);
    expect(region).toContain('getTierTable');
    expect(region).toContain('bonusPercent');
  });
});

describe('member summary contract (must match the Flutter client)', () => {
  const src = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'referralService.js'),
    'utf8'
  );

  it('getReferralSummary returns the snake_case keys the app reads', () => {
    // ReferralSummary.fromJson reads these exact keys; anything else parses to
    // an all-zero summary and the dashboard shows "None / 0% discount".
    for (const key of [
      'user_id:',
      'referral_code:',
      'pending_referrals:',
      'confirmed_referrals:',
      'total_referrals:',
      'current_tier_bonus:',
      'current_tier_description:',
      'is_bonus_available:',
      'next_bonus_unlock_date:',
      'recent_referrals:',
    ]) {
      expect(src).toContain(key);
    }
  });

  it('does not leak the old camelCase summary keys', () => {
    expect(src).not.toContain('myReferralCode:');
    expect(src).not.toContain('spendableReferrals:');
  });

  it('applyBonusToLoan reads the same keys it writes', () => {
    const idx = src.indexOf('async applyBonusToLoan');
    const region = src.slice(idx, idx + 400);
    expect(region).toContain('summary.current_tier_bonus');
    expect(region).toContain('summary.is_bonus_available');
  });

  it('every recent referral carries the non-nullable fields the client casts', () => {
    const idx = src.indexOf('recent_referrals: recentReferrals');
    const region = src.slice(src.indexOf('recentReferrals = ('), idx);
    for (const key of ['referrer_name:', 'referred_name:', 'referral_code:', 'created_at:', 'updated_at:']) {
      expect(region).toContain(key);
    }
  });

  it('describeTier labels every tier', () => {
    expect(referralService.describeTier(2)).toContain('Gold');
    expect(referralService.describeTier(1)).toContain('Silver');
    expect(referralService.describeTier(0.5)).toContain('Bronze');
    expect(referralService.describeTier(0)).toContain('No Bonus');
  });

  it('the list endpoint returns the pagination keys ReferralListResponse reads', () => {
    const routes = fs.readFileSync(
      path.join(__dirname, '..', 'src', 'routes', 'referrals.js'),
      'utf8'
    );
    for (const key of ['referrals:', 'total:', 'page,', 'limit,']) {
      expect(routes).toContain(key);
    }
  });
});

describe('referral_settings uses the production column name', () => {
  const service = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'referralService.js'),
    'utf8'
  );
  const admin = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'routes', 'adminApi.js'),
    'utf8'
  );

  it('reads the program_enabled flag', () => {
    expect(service).toContain('program_enabled');
  });

  it('writes program_enabled, not a bare enabled column', () => {
    const idx = admin.indexOf("router.put('/referrals/settings'");
    const region = admin.slice(idx, idx + 1600);
    expect(region).toContain("program_enabled");
    // `enabled` must only appear as the fallback probe, never as a literal
    // payload key — writing it raised "column does not exist" in production.
    expect(region).not.toMatch(/payload\s*=\s*\{\s*\n\s*enabled:/);
  });

  it('the migration and base schema agree with production', () => {
    const migration = fs.readFileSync(
      path.join(__dirname, '..', 'migrations', '058_referral_settings.sql'),
      'utf8'
    );
    expect(migration).toContain('program_enabled');
    expect(migration).toContain('INTEGER PRIMARY KEY');
    expect(fs.readFileSync(path.join(__dirname, '..', 'supabase_schema.sql'), 'utf8'))
      .toContain('program_enabled');
  });
});
