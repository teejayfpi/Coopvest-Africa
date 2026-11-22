/**
 * Audit-log writes: one implementation, and the actor can never be forgotten.
 *
 * There were four copies of `logAdminAction`, with two different signatures
 * (`target` vs `resource`) and two different column sets. `audit_logs` has both
 * column families, so every write "succeeded" and nothing looked wrong — but
 * only `adminApi`'s copy read the actor from the request, and it took `req` as
 * an *optional fourth* argument that 44 of 60 call sites omitted. The result was
 * 174 of the last 200 audit rows with `actor_id = NULL`, and the dashboard
 * papered over it by rendering the literal string "Administrator".
 *
 * `auditFor(req)` returns a logger bound to that request, so attribution is not
 * something a call site can forget. Prefer it over the module-level `logAction`:
 *
 *     const audit = auditFor(req);
 *     await audit('LOAN_APPROVED', { model: 'Loan', id }, { adminId });
 *
 * Writes the union of both column families (actor_id/actor_role/target_model/
 * metadata and resource/resource_id/details) so the audit screen, the ledger
 * views and any existing SQL keep working. The request body is never stored.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const CLIENT_IP_HEADERS = ['x-forwarded-for', 'x-real-ip', 'cf-connecting-ip'];

function clientIp(req) {
  if (!req) return null;
  for (const h of CLIENT_IP_HEADERS) {
    const v = req.headers?.[h];
    if (v) {
      const first = String(v).split(',')[0].trim();
      if (first) return first;
    }
  }
  return req.ip || null;
}

function clientUserAgent(req) {
  return req?.headers?.['user-agent'] || null;
}

/**
 * Write one audit row.
 *
 * `target` accepts `{ model, id }` (adminApi shape) or `{ resource, resourceId,
 * profileId }` (kycAdmin shape); both are written so either reader works.
 *
 * @param {object|null} req     the Express request, for actor + client metadata
 * @param {string} action       e.g. 'LOAN_APPROVED'
 * @param {object|null} target  what was acted on
 * @param {object} metadata     extra context (never the request body)
 */
async function logAction(req, action, target = null, metadata = {}) {
  const actorId = req?.user?.id || null;
  const actorRole = req?.user?.role || null;

  if (!actorId) {
    // Loud on purpose: an unattributed admin action is a governance defect, and
    // silently writing a NULL actor is how 174 rows went unnoticed.
    logger.warn(
      `audit: "${action}" recorded without an actor (no req.user.id); ` +
        'call it as auditFor(req)(...) so the actor is captured'
    );
  }

  // A few call sites pass the resource name as a bare string rather than an
  // object; normalise so both shapes are recorded consistently.
  const t = typeof target === 'string' ? { model: target } : target || {};

  const row = {
    actor_id: actorId,
    actor_role: actorRole,
    action,
    // adminApi column family
    target_model: t.model || null,
    target_id: t.id || null,
    metadata: { ...metadata, source: 'admin-web' },
    // kycAdmin/paymentProof column family
    resource: t.resource || t.model || null,
    resource_id: t.resourceId || t.id || null,
    target_profile_id: t.profileId || null,
    details: { ...metadata, source: 'admin-web' },
    ip_address: clientIp(req),
    user_agent: clientUserAgent(req),
  };

  try {
    const { error } = await supabase.from('audit_logs').insert(row);
    if (error) throw error;
  } catch (err) {
    // An audit failure must not break the operation that was being audited,
    // but it must be visible in the logs.
    logger.warn('audit_logs insert failed:', err.message);
  }
}

/**
 * Bind the request once and get back an actor-attributing logger.
 *
 * The returned function takes `(action, target, metadata)` — there is no `req`
 * argument to omit.
 */
function auditFor(req) {
  return (action, target, metadata) => logAction(req, action, target, metadata);
}

module.exports = { logAction, auditFor };
