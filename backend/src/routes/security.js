/**
 * /api/security/* — routes consumed by the Admin Dashboard "Security & Access"
 * page (src/pages/security-access). Backed by the governance tables, with
 * in-memory IP blocklist persisted to security_settings.
 *
 * All routes require an admin JWT (requireAdmin) so the page's bearer token
 * works.
 */

const express = require('express');
const router = express.Router();

const supabase = require('../config/supabase');
const { requireAdmin } = require('../middleware/auth');

router.use(requireAdmin);

async function getSettings() {
  const { data } = await supabase.from('security_settings').select('*').eq('id', 1).maybeSingle();
  return data || {
    two_factor_required: false,
    require_mfa_for_super_admin: true,
    session_timeout_minutes: 30,
    max_login_attempts: 5,
    password_expiry_days: 90,
    ip_allowlist_enabled: false,
    allowed_ips: [],
    blocked_ips: [],
    block_suspicious_ips: true,
    alert_on_new_device: true,
    alert_on_new_country: true,
    alert_on_failed_logins: true,
  };
}

/**
 * GET /api/security/sessions — active sessions (recent login_history rows)
 */
router.get('/sessions', async (req, res) => {
  try {
    const limit = Math.min(200, parseInt(req.query.limit, 10) || 50);
    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { data, error } = await supabase.from('login_history')
      .select('id, profile_id, email, ip_address, location, device_type, os, browser, success, created_at, logout_at, session_duration_seconds')
      .gte('created_at', since)
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;

    const ids = [...new Set((data || []).map((r) => r.profile_id).filter(Boolean))];
    let nameMap = {};
    if (ids.length) {
      const { data: profiles } = await supabase.from('profiles').select('id, name, email, role').in('id', ids);
      (profiles || []).forEach((p) => { nameMap[p.id] = p; });
    }

    const sessions = (data || []).map((r) => {
      const p = nameMap[r.profile_id] || {};
      const stillActive = r.success && !r.logout_at;
      return {
        id: String(r.id),
        userId: String(r.profile_id || ''),
        userName: p.name || r.email || 'Unknown',
        role: p.role || 'member',
        ipAddress: r.ip_address || '0.0.0.0',
        device: r.device_type || 'Unknown',
        os: r.os || 'Unknown',
        browser: r.browser || 'Unknown',
        location: r.location || 'Unknown',
        loginTime: r.created_at,
        logoutAt: r.logout_at,
        sessionDurationSeconds: r.session_duration_seconds,
        success: !!r.success,
        isCurrentSession: false,
        active: stillActive,
      };
    });
    res.json({ sessions, total: sessions.length, activeSessions: sessions.filter((s) => s.active).length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/security/events — security events (security_alerts + suspicious logins)
 */
router.get('/events', async (req, res) => {
  try {
    const limit = Math.min(200, parseInt(req.query.limit, 10) || 50);
    const hours = Math.max(1, parseInt(req.query.hours, 10) || 72);
    const since = new Date(Date.now() - hours * 3600 * 1000).toISOString();

    const [alertsRes, suspiciousRes] = await Promise.all([
      // persisted alerts live in security_events (security_alerts needs a
      // DB-password migration we cannot run); exclude approval-tagged rows.
      supabase.from('security_events').select('id, event, username, ip_address, severity, details, resolved, created_at').not('event', 'like', '[approval] %').gte('created_at', since).order('created_at', { ascending: false }).limit(limit),
      supabase.from('login_history').select('id, profile_id, email, ip_address, location, device_type, failure_reason, created_at').eq('success', false).gte('created_at', since).order('created_at', { ascending: false }).limit(limit),
    ]);

    const ids = [...new Set((suspiciousRes.data || []).map((a) => a.profile_id).filter(Boolean))];
    let nameMap = {};
    if (ids.length) {
      const { data: profiles } = await supabase.from('profiles').select('id, name, email').in('id', ids);
      (profiles || []).forEach((p) => { nameMap[p.id] = p.name || p.email; });
    }

    const events = [
      ...(alertsRes.data || []).map((a) => ({
        id: String(a.id),
        event: a.event,
        user: a.username || 'System',
        ipAddress: a.ip_address || '—',
        severity: a.severity,
        timestamp: a.created_at,
        details: a.details,
        resolved: !!a.resolved,
      })),
      ...(suspiciousRes.data || []).map((s) => ({
        id: `login:${s.id}`,
        event: 'Failed login',
        user: s.email || nameMap[s.profile_id] || 'Unknown',
        ipAddress: s.ip_address || '0.0.0.0',
        severity: 'medium',
        timestamp: s.created_at,
        details: s.failure_reason || 'Login attempt failed',
        resolved: false,
      })),
    ].sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()).slice(0, limit);

    res.json({ events, total: events.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/security/settings
 */
router.get('/settings', async (_req, res) => {
  try {
    const s = await getSettings();
    res.json({
      settings: {
        twoFactorRequired: !!s.two_factor_required,
        requireMfaForSuperAdmin: s.require_mfa_for_super_admin !== false,
        sessionTimeoutMinutes: s.session_timeout_minutes || 30,
        maxLoginAttempts: s.max_login_attempts || 5,
        passwordExpiryDays: s.password_expiry_days || 90,
        ipAllowlistEnabled: !!s.ip_allowlist_enabled,
        allowedIPs: s.allowed_ips || [],
        blockedIPs: s.blocked_ips || [],
        blockSuspiciousIPs: s.block_suspicious_ips !== false,
        alertOnNewDevice: s.alert_on_new_device !== false,
        alertOnNewCountry: s.alert_on_new_country !== false,
        alertOnFailedLogins: s.alert_on_failed_logins !== false,
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * PUT /api/security/settings
 */
router.put('/settings', async (req, res) => {
  try {
    const b = req.body || {};
    const s = await getSettings();
    const merged = {
      two_factor_required: b.twoFactorRequired ?? s.two_factor_required,
      require_mfa_for_super_admin: b.requireMfaForSuperAdmin ?? s.require_mfa_for_super_admin,
      session_timeout_minutes: b.sessionTimeoutMinutes ?? s.session_timeout_minutes,
      max_login_attempts: b.maxLoginAttempts ?? s.max_login_attempts,
      password_expiry_days: b.passwordExpiryDays ?? s.password_expiry_days,
      ip_allowlist_enabled: b.ipAllowlistEnabled ?? s.ip_allowlist_enabled,
      allowed_ips: b.allowedIPs ?? s.allowed_ips,
      blocked_ips: b.blockedIPs ?? s.blocked_ips,
      block_suspicious_ips: b.blockSuspiciousIPs ?? s.block_suspicious_ips,
      alert_on_new_device: b.alertOnNewDevice ?? s.alert_on_new_device,
      alert_on_new_country: b.alertOnNewCountry ?? s.alert_on_new_country,
      alert_on_failed_logins: b.alertOnFailedLogins ?? s.alert_on_failed_logins,
      updated_at: new Date().toISOString(),
    };
    const { error } = await supabase.from('security_settings').upsert({ id: 1, ...merged }).eq('id', 1);
    if (error) throw error;
    res.json({ success: true, settings: merged });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /api/security/ip-block — block/unblock an IP
 */
router.post('/ip-block', async (req, res) => {
  try {
    const { ip, action } = req.body || {};
    if (!ip) return res.status(400).json({ error: 'ip is required' });
    const s = await getSettings();
    let blocked = Array.isArray(s.blocked_ips) ? [...s.blocked_ips] : [];
    if (action === 'block') {
      if (!blocked.includes(ip)) blocked.push(ip);
    } else if (action === 'unblock') {
      blocked = blocked.filter((x) => x !== ip);
    } else {
      return res.status(400).json({ error: 'action must be block or unblock' });
    }
    const { error } = await supabase.from('security_settings').update({ blocked_ips: blocked, updated_at: new Date().toISOString() }).eq('id', 1);
    if (error) throw error;

    try {
      await supabase.from('audit_logs').insert({
        actor_id: req.user?.id || null,
        actor_role: req.user?.role || null,
        action: `ip_${action}`,
        target_model: 'security_settings',
        metadata: { ip, action },
      });
    } catch (_) {}

    res.json({ success: true, blockedIPs: blocked });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * DELETE /api/security/sessions/:id — terminate a session (sign out user)
 */
router.delete('/sessions/:id', async (req, res) => {
  try {
    const { id } = req.params;
    // Mark the login_history row as logged out (best-effort remote logout).
    const { data: row } = await supabase.from('login_history').select('profile_id, logout_at').eq('id', id).maybeSingle();
    if (row) {
      await supabase.from('login_history').update({ logout_at: new Date().toISOString() }).eq('id', id);
      try {
        await supabase.from('audit_logs').insert({
          actor_id: req.user?.id || null, actor_role: req.user?.role || null,
          action: 'SESSION_TERMINATE', target_model: 'login_history', target_id: id,
          metadata: { targetProfile: row.profile_id },
        });
      } catch (_) {}
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
