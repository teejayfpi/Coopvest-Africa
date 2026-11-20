/**
 * Who owns a phone number.
 *
 * One number, one member: a phone used to register may not be used again. The
 * rule is enforced in three places, and all three must agree on what "the same
 * number" means — see lib/phoneNumber.js.
 *
 *   1. GET /auth/phone-availability  — the sign-up form checks before it
 *      creates an auth user, so the member sees the error on the phone field.
 *   2. POST /auth/register, /auth/sync, PUT /user/profile — the guard, which
 *      runs even when a client skips the pre-check.
 *   3. profiles.phone_normalized + its unique index (migration 066) — the
 *      backstop, which holds when two requests race past 1 and 2.
 *
 * This module is the lookup that 1 and 2 share, so they cannot disagree about
 * which row is the owner.
 */

const { phoneLookupKey, phoneVariants } = require('./phoneNumber');

const PHONE_TAKEN_MESSAGE =
  'This phone number has already been used to register. Please use a different number, or log in to your existing account.';

/**
 * The profile holding a phone number, or null when it is free.
 *
 * Throws on a database error so a caller never mistakes "could not check" for
 * "not taken" — that would let a duplicate through on a transient failure.
 *
 * Two lookups, because `phone_normalized` only exists once migration 066 has
 * been applied. The fallback compares every notation the number is stored in,
 * which is how the rule holds before the migration lands. Once the column
 * exists the first query answers and the second never runs.
 */
async function findPhoneOwner(supabase, rawPhone) {
  const key = phoneLookupKey(rawPhone);
  if (!key) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('id, email')
    .eq('phone_normalized', key)
    .maybeSingle();

  if (!error) return data || null;

  // 42703 = undefined_column: migration 066 is not applied yet.
  const missingColumn = error.code === '42703' || /phone_normalized/.test(error.message || '');
  if (!missingColumn) {
    throw new Error(`phone look up failed: ${error.message}`);
  }

  const { data: legacy, error: legacyError } = await supabase
    .from('profiles')
    .select('id, email')
    .in('phone', phoneVariants(rawPhone))
    .limit(1);

  if (legacyError) throw new Error(`phone look up failed: ${legacyError.message}`);
  return legacy && legacy.length ? legacy[0] : null;
}

module.exports = { findPhoneOwner, PHONE_TAKEN_MESSAGE };
