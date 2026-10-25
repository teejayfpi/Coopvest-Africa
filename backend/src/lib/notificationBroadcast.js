/**
 * Shared helpers for the admin notification broadcast route.
 *
 * Kept separate from the route so the audience/channel mapping can be unit
 * tested without a live Supabase connection or an Express request.
 */

// Channels that are always deliverable. Email joins this set at runtime only
// when a mail transport is actually configured (see `classifyChannels`), since
// without one `notifyService.sendEmail` can only skip.
const SUPPORTED_CHANNELS = ['push', 'in_app'];

/**
 * Split the dashboard's requested channels into those we can really deliver and
 * those that are not implemented yet.
 *
 * An empty/absent selection keeps the historical default of push-only.
 *
 * Email is deliverable only when a transport is configured. The caller passes
 * that in rather than this module reading the environment, so the mapping stays
 * pure and unit-testable.
 *
 * @param {string[]} [channels]
 * @param {{emailAvailable?: boolean}} [opts]
 */
function classifyChannels(channels, { emailAvailable = false } = {}) {
  const requested = (Array.isArray(channels) && channels.length > 0) ? channels : ['push'];
  const supported = emailAvailable ? [...SUPPORTED_CHANNELS, 'email'] : SUPPORTED_CHANNELS;
  return {
    delivered: requested.filter((c) => supported.includes(c)),
    notImplemented: requested.filter((c) => !supported.includes(c)),
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
