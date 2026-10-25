/**
 * Fraud & AML rule engine.
 *
 * The platform already had a "fraud detection" endpoint, but it was derived on
 * the fly from three unrelated lists (flagged profiles, failed logins, defaulted
 * loans) and had no case management: an alert could not be acknowledged,
 * investigated, or dismissed, and re-running it produced a different set of
 * pseudo-ids every time.
 *
 * This module is the missing half — a fixed rule set that runs over the ledger
 * and produces *findings* with a stable dedupe key, so the same suspicion is
 * never raised twice and every finding can be tracked to a resolution.
 *
 * `evaluateRules` is pure: it takes already-fetched datasets and returns
 * findings, which makes every rule unit-testable without a database. The worker
 * and the admin "scan now" endpoint both call `runFraudScan`, which fetches the
 * data and persists findings as cases.
 *
 * A finding is never an accusation and never moves money. It is a queue item for
 * a human.
 */

const LARGE_DEBIT = 500000; // ₦ — a single debit large enough to review
const STRUCTURING_FLOOR = 450000; // debits kept just under the large threshold
const STRUCTURING_WINDOW_HOURS = 24;
const RAPID_WINDOW_HOURS = 24;
const RAPID_MIN_COUNT = 3;
const GUARANTEE_WINDOW_DAYS = 30;
const GUARANTEE_MIN_COUNT = 3;
const NEW_ACCOUNT_DAYS = 30;
const NEW_ACCOUNT_HIGH_VALUE = 1000000; // ₦ — first-month activity this large

function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function money(n) {
  return Math.round(toNumber(n) * 100) / 100;
}

function isSettled(t) {
  return t && t.status === 'completed';
}

function isDebit(t) {
  if (t.category === 'debit') return true;
  if (t.category === 'credit') return false;
  return toNumber(t.amount) < 0;
}

function dayKey(iso) {
  return new Date(iso).toISOString().slice(0, 10);
}

/**
 * Sliding-window grouping: return the items that fall inside any window of
 * `windowMs` containing at least `minCount` items. Items must be pre-sorted
 * ascending by `created_at`.
 */
function slidingWindows(items, windowMs, minCount) {
  const hits = [];
  for (let i = 0; i < items.length; i += 1) {
    const start = new Date(items[i].created_at).getTime();
    const group = [];
    for (let j = i; j < items.length; j += 1) {
      const at = new Date(items[j].created_at).getTime();
      if (at - start > windowMs) break;
      group.push(items[j]);
    }
    if (group.length >= minCount) hits.push(group);
  }
  return hits;
}

/** The same bank account number linked to more than one member. */
function ruleSharedBankAccount({ bankAccounts = [] }) {
  const byAccount = new Map();
  for (const a of bankAccounts) {
    if (!a || !a.account_number) continue;
    const list = byAccount.get(a.account_number) || new Set();
    if (a.profile_id) list.add(a.profile_id);
    byAccount.set(a.account_number, list);
  }
  const findings = [];
  for (const [accountNumber, profiles] of byAccount.entries()) {
    if (profiles.size > 1) {
      findings.push({
        ruleId: 'shared_bank_account',
        severity: 'critical',
        profileId: [...profiles][0],
        title: 'One bank account is linked to several members',
        details: { accountNumber, profileIds: [...profiles], memberCount: profiles.size },
        amount: null,
        dedupeKey: `shared_bank_account:${accountNumber}`,
      });
    }
  }
  return findings;
}

/** Several large debits from one member in a short window (takeover / draining). */
function ruleRapidLargeDebits({ transactions = [] }, { windowHours = RAPID_WINDOW_HOURS, minCount = RAPID_MIN_COUNT, threshold = LARGE_DEBIT } = {}) {
  const byProfile = new Map();
  for (const t of transactions) {
    if (!isSettled(t) || !isDebit(t) || !t.created_at) continue;
    if (toNumber(t.amount) < threshold) continue;
    const list = byProfile.get(t.profile_id) || [];
    list.push(t);
    byProfile.set(t.profile_id, list);
  }
  const findings = [];
  for (const [profileId, items] of byProfile.entries()) {
    items.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
    const windows = slidingWindows(items, windowHours * 3600 * 1000, minCount);
    if (windows.length === 0) continue;
    const group = windows[0];
    findings.push({
      ruleId: 'rapid_large_debits',
      severity: 'critical',
      profileId,
      title: `${group.length} large debits within ${windowHours}h`,
      details: {
        count: group.length,
        threshold,
        transactionIds: group.map((t) => t.id).filter(Boolean),
        firstAt: group[0].created_at,
        lastAt: group[group.length - 1].created_at,
      },
      amount: money(group.reduce((s, t) => s + toNumber(t.amount), 0)),
      dedupeKey: `rapid_large_debits:${profileId}:${dayKey(group[0].created_at)}`,
    });
  }
  return findings;
}

/** Repeated debits kept just under the large-debit threshold — structuring. */
function ruleStructuring({ transactions = [] }, { windowHours = STRUCTURING_WINDOW_HOURS, minCount = RAPID_MIN_COUNT, floor = STRUCTURING_FLOOR, ceiling = LARGE_DEBIT } = {}) {
  const byProfile = new Map();
  for (const t of transactions) {
    if (!isSettled(t) || !isDebit(t) || !t.created_at) continue;
    const amount = toNumber(t.amount);
    if (amount < floor || amount >= ceiling) continue;
    const list = byProfile.get(t.profile_id) || [];
    list.push(t);
    byProfile.set(t.profile_id, list);
  }
  const findings = [];
  for (const [profileId, items] of byProfile.entries()) {
    items.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
    const windows = slidingWindows(items, windowHours * 3600 * 1000, minCount);
    if (windows.length === 0) continue;
    const group = windows[0];
    findings.push({
      ruleId: 'structuring',
      severity: 'warning',
      profileId,
      title: `${group.length} debits just under the review threshold within ${windowHours}h`,
      details: {
        count: group.length,
        floor,
        ceiling,
        transactionIds: group.map((t) => t.id).filter(Boolean),
        firstAt: group[0].created_at,
      },
      amount: money(group.reduce((s, t) => s + toNumber(t.amount), 0)),
      dedupeKey: `structuring:${profileId}:${dayKey(group[0].created_at)}`,
    });
  }
  return findings;
}

/** A guarantor consenting to many loans in a short window (guarantor collusion). */
function ruleGuaranteeBurst({ guarantees = [] }, { windowDays = GUARANTEE_WINDOW_DAYS, minCount = GUARANTEE_MIN_COUNT } = {}) {
  const byGuarantor = new Map();
  for (const g of guarantees) {
    if (!g || g.status !== 'consented') continue;
    // `guarantor_profile_id` and `guarantor_id` both exist on loan_guarantors
    // (migrations 040 and kyc_sync_001) and either may be populated, so accept
    // whichever the caller supplied.
    const guarantorProfileId = g.guarantor_profile_id || g.guarantor_id;
    if (!guarantorProfileId) continue;
    const at = g.consented_at || g.created_at;
    if (!at) continue;
    const list = byGuarantor.get(guarantorProfileId) || [];
    list.push({ ...g, _at: at });
    byGuarantor.set(guarantorProfileId, list);
  }
  const findings = [];
  for (const [profileId, items] of byGuarantor.entries()) {
    items.sort((a, b) => new Date(a._at) - new Date(b._at));
    const windows = slidingWindows(
      items.map((i) => ({ ...i, created_at: i._at })),
      windowDays * 24 * 3600 * 1000,
      minCount,
    );
    if (windows.length === 0) continue;
    const group = windows[0];
    findings.push({
      ruleId: 'guarantee_burst',
      severity: 'warning',
      profileId,
      title: `Guaranteed ${group.length} loans within ${windowDays} days`,
      details: {
        count: group.length,
        loanIds: group.map((g) => g.loan_id).filter(Boolean),
        firstAt: group[0]._at,
      },
      amount: null,
      dedupeKey: `guarantee_burst:${profileId}:${dayKey(group[0]._at)}`,
    });
  }
  return findings;
}

/** A recently-created account with first-month activity above a high value. */
function ruleNewAccountHighValue({ profiles = [], transactions = [] }, { now = new Date(), accountDays = NEW_ACCOUNT_DAYS, threshold = NEW_ACCOUNT_HIGH_VALUE } = {}) {
  const cutoff = new Date(now.getTime() - accountDays * 24 * 3600 * 1000);
  const newProfiles = new Map();
  for (const p of profiles) {
    if (!p || !p.created_at) continue;
    if (new Date(p.created_at) >= cutoff) newProfiles.set(p.id, p);
  }
  if (newProfiles.size === 0) return [];

  const totals = new Map();
  for (const t of transactions) {
    if (!isSettled(t) || !newProfiles.has(t.profile_id)) continue;
    totals.set(t.profile_id, (totals.get(t.profile_id) || 0) + Math.abs(toNumber(t.amount)));
  }

  const findings = [];
  for (const [profileId, total] of totals.entries()) {
    if (total >= threshold) {
      findings.push({
        ruleId: 'new_account_high_value',
        severity: 'warning',
        profileId,
        title: 'New account with high-value activity',
        details: { total, threshold, accountDays, profileCreatedAt: newProfiles.get(profileId).created_at },
        amount: money(total),
        dedupeKey: `new_account_high_value:${profileId}`,
      });
    }
  }
  return findings;
}

const RULES = [
  { id: 'shared_bank_account', title: 'One bank account linked to several members', severity: 'critical', run: ruleSharedBankAccount },
  { id: 'rapid_large_debits', title: 'Several large debits in a short window', severity: 'critical', run: ruleRapidLargeDebits },
  { id: 'structuring', title: 'Repeated debits just under the review threshold', severity: 'warning', run: ruleStructuring },
  { id: 'guarantee_burst', title: 'Guarantor activity burst', severity: 'warning', run: ruleGuaranteeBurst },
  { id: 'new_account_high_value', title: 'New account with high-value activity', severity: 'warning', run: ruleNewAccountHighValue },
];

/**
 * Run every rule over the provided datasets. Pure.
 *
 * @returns {Array} findings, each with a stable `dedupeKey`
 */
function evaluateRules(datasets = {}, options = {}) {
  const findings = [];
  for (const rule of RULES) {
    let produced = [];
    try {
      produced = rule.run(datasets, options) || [];
    } catch (err) {
      // A single malformed dataset must not abort the whole scan.
      produced = [];
    }
    for (const f of produced) findings.push({ ...f, ruleId: rule.id });
  }
  return findings;
}

module.exports = {
  evaluateRules,
  RULES,
  // exported for targeted tests
  ruleSharedBankAccount,
  ruleRapidLargeDebits,
  ruleStructuring,
  ruleGuaranteeBurst,
  ruleNewAccountHighValue,
  constants: {
    LARGE_DEBIT,
    STRUCTURING_FLOOR,
    RAPID_WINDOW_HOURS,
    RAPID_MIN_COUNT,
    GUARANTEE_WINDOW_DAYS,
    GUARANTEE_MIN_COUNT,
    NEW_ACCOUNT_DAYS,
    NEW_ACCOUNT_HIGH_VALUE,
  },
};
