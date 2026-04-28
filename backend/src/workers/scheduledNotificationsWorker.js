/**
 * Lightweight in-process worker that periodically delivers due scheduled
 * notifications. Runs inside the main Node process so no separate worker
 * deployment is required. Disable by setting
 * SCHEDULED_NOTIFICATIONS_DISABLED=1.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');

const POLL_INTERVAL_MS = 60 * 1000;

async function processDue() {
  try {
    const now = new Date().toISOString();
    const { data: due, error } = await supabase
      .from('scheduled_notifications')
      .select('*')
      .eq('status', 'scheduled')
      .lte('scheduled_for', now)
      .limit(100);
    if (error) throw error;
    if (!due || due.length === 0) return;

    for (const row of due) {
      try {
        let targets = [];
        if (row.audience === 'specific' && Array.isArray(row.target_profile_ids)) {
          targets = row.target_profile_ids;
        } else {
          let q = supabase.from('profiles').select('id');
          if (row.audience === 'active') q = q.eq('is_active', true);
          const { data: all } = await q;
          targets = (all || []).map((p) => p.id);
        }

        await notifyService.broadcast({
          profileIds: targets,
          channels: row.channels || ['in_app'],
          title: row.title,
          body: row.body,
        });

        await supabase
          .from('scheduled_notifications')
          .update({ status: 'sent', sent_at: new Date().toISOString(), sent_count: targets.length })
          .eq('id', row.id);
      } catch (inner) {
        await supabase
          .from('scheduled_notifications')
          .update({ status: 'failed', error: inner.message })
          .eq('id', row.id);
      }
    }
  } catch (err) {
    logger.warn('scheduledNotificationsWorker: tick failed:', err.message);
  }
}

function start() {
  if (process.env.SCHEDULED_NOTIFICATIONS_DISABLED === '1') {
    logger.info('scheduledNotificationsWorker: disabled via env');
    return null;
  }
  logger.info('scheduledNotificationsWorker: started (poll 60s)');
  const handle = setInterval(processDue, POLL_INTERVAL_MS);
  // Run once on startup so anything already due is flushed quickly.
  processDue().catch(() => {});
  return handle;
}

module.exports = { start, processDue };
