/**
 * Ticket Service (Supabase-backed)
 *
 * Current routes (`routes/tickets.js`, `routes/adminTickets.js`) talk to
 * Supabase directly and no longer go through this service. It is kept as
 * a thin set of helpers for older callers and new background jobs.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

const TICKET_RATE_LIMIT = parseInt(process.env.TICKET_RATE_LIMIT, 10) || 5;

class TicketService {
  async checkRateLimit(profileId) {
    const since = new Date();
    since.setHours(0, 0, 0, 0);
    const { count, error } = await supabase
      .from('tickets')
      .select('id', { count: 'exact', head: true })
      .eq('profile_id', profileId)
      .gte('created_at', since.toISOString());
    if (error) throw error;
    const used = count || 0;
    return {
      allowed: used < TICKET_RATE_LIMIT,
      remaining: Math.max(0, TICKET_RATE_LIMIT - used),
      reason: used >= TICKET_RATE_LIMIT ? 'Daily ticket limit reached' : null,
    };
  }

  async getUserTickets(profileId, { status, page = 1, limit = 20 } = {}) {
    let q = supabase
      .from('tickets')
      .select('*', { count: 'exact' })
      .eq('profile_id', profileId)
      .order('created_at', { ascending: false })
      .range((page - 1) * limit, page * limit - 1);
    if (status) q = q.eq('status', status);
    const { data, error, count } = await q;
    if (error) throw error;
    return {
      success: true,
      tickets: data || [],
      pagination: { page, limit, total: count || 0 },
    };
  }

  async logAudit(ticketId, actorId, action, metadata = {}) {
    try {
      await supabase.from('audit_logs').insert({
        actor_id: actorId,
        action,
        target_model: 'Ticket',
        target_id: ticketId,
        metadata,
      });
    } catch (err) {
      logger.warn('audit_logs insert failed:', err.message);
    }
  }
}

module.exports = new TicketService();
