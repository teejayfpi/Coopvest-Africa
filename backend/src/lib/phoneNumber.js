/**
 * Phone-number identity.
 *
 * A member may only register a phone number once, so the platform needs a
 * single answer to "are these two inputs the same number?". String equality is
 * not that answer. The live database already holds the counter-example:
 *
 *   ayanlowo89@gmail.com        +2347038193753
 *   coopvestafrica@gmail.com    07038193753
 *
 * Those are the same Nigerian line typed two ways. A uniqueness rule written
 * against the raw column would let both through and call the constraint
 * satisfied.
 *
 * `normalizePhone` reduces any Nigerian mobile number to E.164 (`+234` plus the
 * ten-digit national significant number). `phoneLookupKey` produces the
 * comparison key stored in `profiles.phone_normalized` and used by the unique
 * index (migration 066). Two inputs collide if and only if their keys match.
 *
 * Numbers that cannot be resolved to a Nigerian mobile line return a key
 * derived from the digits as typed. That keeps the column non-null and the
 * index enforceable without silently equating unrelated values; the API
 * rejects unparseable numbers before they reach it.
 */

const NIGERIAN_COUNTRY_CODE = '234';

/** Local prefixes that map onto the 10-digit national significant number. */
const LOCAL_PREFIXES = ['0', '+234', '234'];

/**
 * Reduce a phone number to E.164 (+234XXXXXXXXXX) when it is a Nigerian number,
 * or to `+`-prefixed digits otherwise. Returns null for empty input.
 */
function normalizePhone(raw) {
  if (raw === null || raw === undefined) return null;
  const text = String(raw).trim();
  if (!text) return null;

  // Keep a leading +, drop every other separator (spaces, dashes, dots,
  // brackets) that people type between digit groups.
  const hadPlus = text.startsWith('+');
  const digits = text.replace(/\D/g, '');
  if (!digits) return null;

  for (const prefix of LOCAL_PREFIXES) {
    const p = prefix.replace(/\D/g, '');
    if (!p) continue;
    if (digits.length === p.length + 10 && digits.startsWith(p)) {
      return `+${NIGERIAN_COUNTRY_CODE}${digits.slice(p.length)}`;
    }
  }

  // A bare 10-digit number: treat as the national significant number. This is
  // what an operator typing "8031234567" means, and it is what the local
  // prefixes above collapse to.
  if (digits.length === 10) {
    return `+${NIGERIAN_COUNTRY_CODE}${digits}`;
  }

  // Anything else: preserve the caller's intent so two identical inputs still
  // collide, without guessing a country.
  return `${hadPlus ? '+' : ''}${digits}`;
}

/**
 * The value stored in `profiles.phone_normalized` and compared by the unique
 * index: the ten-digit national significant number, so every notation of one
 * Nigerian line collapses to one key.
 *
 * Must agree exactly with `normalize_phone_key()` in migration 066 — the API
 * checks with this, the database enforces with that, and a disagreement would
 * mean a number the API calls free is rejected by the index.
 */
function phoneLookupKey(raw) {
  const normalized = normalizePhone(raw);
  if (!normalized) return null;
  const nigerian = /^\+234(\d{10})$/.exec(normalized);
  if (nigerian) return nigerian[1];
  return normalized.replace(/^\+/, '');
}

/**
 * True when the input is a usable Nigerian mobile number. Registration rejects
 * anything else, because an unresolvable number cannot be deduplicated
 * reliably.
 */
function isNigerianMobile(raw) {
  const normalized = normalizePhone(raw);
  if (!normalized) return false;
  const match = /^\+234(\d{10})$/.exec(normalized);
  if (!match) return false;
  // Nigerian mobile numbers start 70, 80, 81, 90 or 91.
  return /^[789]/.test(match[1]);
}

/**
 * Every textual form a Nigerian number is commonly stored in, so a lookup can
 * match a row written before normalisation existed.
 *
 * The unique key in the database is the real rule; this exists because the
 * migration that adds it has to be applied by an operator, and registration
 * must not start failing (or silently allowing duplicates) in the window
 * before that happens.
 */
function phoneVariants(raw) {
  const normalized = normalizePhone(raw);
  if (!normalized) return [];
  const match = /^\+234(\d{10})$/.exec(normalized);
  if (!match) return [normalized, normalized.replace(/^\+/, '')];
  const nsn = match[1];
  return [`+234${nsn}`, `234${nsn}`, `0${nsn}`, nsn];
}

/**
 * Last four digits, for messages that need to name the number without echoing
 * it in full. Returns an empty string when there is nothing to show.
 */
function lastFour(raw) {
  const digits = String(raw ?? '').replace(/\D/g, '');
  return digits.length >= 4 ? digits.slice(-4) : '';
}

module.exports = {
  normalizePhone,
  phoneLookupKey,
  phoneVariants,
  isNigerianMobile,
  lastFour,
  NIGERIAN_COUNTRY_CODE,
};
