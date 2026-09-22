/**
 * Shared helpers for the admin notification broadcast route.
 *
 * Kept separate from the route so the audience/channel mapping can be unit
 * tested without a live Supabase connection or an Express request.
 */

// Only these two are actually wired up end to end. SMS/email have no provider
// configured (notifyService.sendEmail/sendSms are logging stubs), so they must
// be reported as unimplemented rather than silently counted as delivered.
const SUPPORTED_CHANNELS = ['push', 'in_app'];

/**
 * Split the dashboard's requested channels into those we can really deliver and
 * those that are not implemented yet.
 *
 * An empty/absent selection keeps the historical default of push-only.
 */
function classifyChannels(channels) {
  const requested = (Array.isArray(channels) && channels.length > 0) ? channels : ['push'];
  return {
    delivered: requested.filter((c) => SUPPORTED_CHANNELS.includes(c)),
    notImplemented: requested.filter((c) => !SUPPORTED_CHANNELS.includes(c)),
  };
}

// The audiences the dashboard offers. 'all' is the safe default.
const AUDIENCE_TYPES = ['all', 'active', 'defaulters', 'organizations', 'loans_pending'];

/**
 * Canonicalise an audience value.
 *
 * Anything unrecognised falls back to 'all' so a typo cannot create a new
 * implicit bucket, but the route also rejects unknown values at validation
 * time — this is the last-resort safety net.
 */
function normalizeAudience(audience) {
  return AUDIENCE_TYPES.includes(audience) ? audience : 'all';
}

module.exports = {
  SUPPORTED_CHANNELS,
  AUDIENCE_TYPES,
  classifyChannels,
  normalizeAudience,
};
