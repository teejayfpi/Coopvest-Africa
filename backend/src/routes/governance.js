/**
 * Super Admin governance routes.
 *
 * Implements the Super Admin governance surface consumed by the Admin Dashboard:
 *   - Login monitoring        GET/POST  /login-events, /login-history (enriched)
 *   - Audit trail             (enriched logAdminAction lives in adminApi.js)
 *   - Approval workflow       GET/POST  /approvals[/:id/:action]
 *   - Security alerts         GET/POST  /security-alerts[/:id/:action]
 *   - Live admin monitoring   GET/POST  /activity[ /online ]
 *   - Activity dashboard      GET       /stats
 *   - Permissions             GET       /permissions, /roles/:id/permissions
 *
 * Mounted under /api/admin (and /api/v2/admin). All routes are protected by
 * requireAdmin (applied in adminApi.js router). This sub-router is itself
 * requireAdmin-guarded when mounted.
 *
 * Data is persisted to the governance tables created by
 * migrations/012_super_admin_governance.sql (admin_approvals, security_alerts,
 * admin_activity, security_settings, login_history enrichment).
 */

const express = require('express');
const router = express.Router();

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function clientMeta(req) {
  const ua = req.headers['user-agent'] || '';
  return {
    ip: (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim(),
    userAgent: ua,
    browser: parseBrowser(ua),
    os: parseOS(ua),
    device: parseDevice(ua),
  };
}

function parseBrowser(ua) {
  if (!ua) return 'Unknown';
  if (/edg/i.test(ua)) return 'Edge';
  if (/chrome|crios/i.test(ua)) return 'Chrome';
  if (/firefox|fxios/i.test(ua)) return 'Firefox';
  if (/safari/i.test(ua)) return 'Safari';
  return 'Unknown';
}
function parseOS(ua) {
  if (!ua) return 'Unknown';
  if (/windows nt 10/i.test(ua)) return 'Windows 10/11';
  if (/windows/i.test(ua)) return 'Windows';
  if (/mac os x|iphone|ipad/i.test(ua)) return /iphone|ipad/i.test(ua) ? 'iOS' : 'macOS';
  if (/android/i.test(ua)) return 'Android';
  if (/linux/i.test(ua)) return 'Linux';
  return 'Unknown';
}
function parseDevice(ua) {
  if (!ua) return 'Unknown';
  if (/iphone|ipad|android.*mobile/i.test(ua)) return 'Mobile';
  if (/android|tablet|ipad/i.test(ua)) return 'Tablet';
  return 'Desktop';
}

// Approximate location from a string. Real geo-IP requires a lookup service
// (MaxMind/IPAPI); we keep it best-effort and let the frontend record GPS.
function approxLocation(ip) {
  if (!ip || ip === '::1' || ip.startsWith('127.') || ip.startsWith('10.')) return 'Local network';
  return 'Unknown — configure a geo-IP provider for city/country';
}

async function profileById(id) {
  if (!id) return null;
  const { data } = await supabase
    .from('profiles')
    .select('id, user_id, name, email, role, is_active')
    .eq('id', id)
    .maybeSingle();
  return data || null;
}

// Insert a security alert. Never throws (best-effort).
async function raiseSecurityAlert({ alertType, severity = 'medium', title, description, profileId = null, email = null, ip = null, location = null, device = null, metadata = {} }) {
  try {
    await supabase.from('security_alerts').insert({
      alert_type: alertType,
      severity,
      title: title || alertType,
      description,
      profile_id: profileId,
      email,
      ip_address: ip,
      location,
      device,
      status: 'unread',
      channels: ['dashboard'],
      metadata,
    });
  } catch (err) {
    logger.warn('security alert insert failed:', err.message);
  }
}

// Record a login event to login_history (best-effort, never throws).
async function recordLogin({ profileId, email, success, failureReason, req, mfaUsed = false, loginMethod = 'password', sessionId = null }) {
  try {
    const m = clientMeta(req);
    const now = new Date();
    const { error } = await supabase.from('login_history').insert({
      profile_id: profileId || null,
      email: email || null,
      success: !!success,
      failure_reason: success ? null : failureReason || null,
      ip_address: m.ip || null,
      user_agent: m.userAgent || null,
      device_type: m.device,
      device_name: m.device,
      os: m.os,
      browser: m.browser,
      app_version: req.headers['app-version'] || null,
      location: approxLocation(m.ip),
      login_method: loginMethod,
      mfa_used: !!mfaUsed,
      session_id: sessionId,
      created_at: now.toISOString(),
    });
    if (error) logger.warn('login_history insert failed:', error.message);
  } catch (err) {
    logger.warn('recordLogin error:', err.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login monitoring — record + read
// ─────────────────────────────────────────────────────────────────────────────

/**
 * POST /api/admin/login-events
 * Called by the dashboard frontend immediately after a Supabase auth attempt
 * (success or failure). Records device/IP/UA/metadata into login_history and,
 * on failure or anomaly, raises a security_alert.
 */
router.post('/login-events', async (req, res) => {
  try {
    const { email, success, failureReason, profileId, mfaUsed, loginMethod, sessionId } = req.body || {};
    const m = clientMeta(req);
    const profile = profileId ? await profileById(profileId) : (email ? (await supabase.from('profiles').select('id, role, is_active').ilike('email', email).maybeSingle()).data : null);

    // Disabled-account login attempt → critical alert
    if (profile && profile.is_active === false && !success) {
      await raiseSecurityAlert({
        alertType: 'disabled_account_login',
        severity: 'critical',
        title: 'Disabled account login attempt',
        description: `Account ${email || profile.id} attempted to log in while disabled.`,
        profileId: profile.id, email, ip: m.ip, location: approxLocation(m.ip), device: m.device,
        metadata: { ua: m.userAgent, browser: m.browser, os: m.os },
      });
    }

    await recordLogin({ profileId: profile?.id || profileId, email, success, failureReason, req, mfaUsed, loginMethod, sessionId });

    // Failed-login burst detection (≥3 failures in 10 min from same IP)
    if (!success && m.ip) {
      const since = new Date(Date.now() - 10 * 60 * 1000).toISOString();
      const { count } = await supabase.from('login_history').select('id', { count: 'exact', head: true }).eq('ip_address', m.ip).eq('success', false).gte('created_at', since);
      if ((count || 0) >= 3) {
        await raiseSecurityAlert({
          alertType: 'multiple_failed_logins',
          severity: 'high',
          title: 'Multiple failed login attempts',
          description: `${count} failed logins from ${m.ip} in the last 10 minutes.`,
          profileId: profile?.id || null, email, ip: m.ip, location: approxLocation(m.ip), device: m.device,
          metadata: { count, ua: m.userAgent },
        });
      }
    }

    // New-device / new-country detection for successful logins
    if (success && profile) {
      const { data: prior } = await supabase.from('login_history')
        .select('ip_address, location, device_type')
        .eq('profile_id', profile.id).eq('success', true)
        .lt('created_at', new Date(Date.now() - 30000).toISOString())
        .order('created_at', { ascending: false }).limit(50);
      const priorSet = prior || [];
      const knownDevice = priorSet.some((r) => (r.device_type || '') === m.device);
      if (!knownDevice) {
        await raiseSecurityAlert({
          alertType: 'new_device_login',
          severity: 'medium',
          title: 'Login from a new device',
          description: `${email} logged in from a new ${m.device} (${m.browser}/${m.os}).`,
          profileId: profile.id, email, ip: m.ip, location: approxLocation(m.ip), device: m.device,
          metadata: { ua: m.userAgent },
        });
      }
    }

    res.json({ success: true });
  } catch (err) {
    logger.error('login-events error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/admin/logout-events
 * Records a logout (closes the most recent open login for this profile).
 */
router.post('/logout-events', async (req, res) => {
  try {
    const { profileId, sessionId } = req.body || {};
    if (!profileId) return res.status(400).json({ success: false, error: 'profileId required' });
    const { data: last } = await supabase.from('login_history')
      .select('id, created_at')
      .eq('profile_id', profileId).is('logout_at', null)
      .order('created_at', { ascending: false }).limit(1);
    const row = (last || [])[0];
    if (row) {
      const duration = Math.max(0, Math.floor((Date.now() - new Date(row.created_at).getTime()) / 1000));
      await supabase.from('login_history').update({ logout_at: new Date().toISOString(), session_duration_seconds: duration }).eq('id', row.id);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Live admin monitoring (heartbeats)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * POST /api/admin/activity
 * Heartbeat from the dashboard. Upserts current page/module/action so the
 * Super Admin can see who is online and what they are doing.
 */
router.post('/activity', async (req, res) => {
  try {
    if (!req.user?.id) return res.status(401).json({ success: false, error: 'Not authenticated' });
    const { page, module: mod, action } = req.body || {};
    const m = clientMeta(req);
    const { error } = await supabase.from('admin_activity').upsert({
      profile_id: req.user.id,
      email: req.user.email,
      current_page: page || null,
      current_module: mod || null,
      last_action: action || null,
      ip_address: m.ip,
      user_agent: m.userAgent,
      device: m.device,
      last_heartbeat: new Date().toISOString(),
    }, { onConflict: 'profile_id' });
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/admin/online
 * Admins with a heartbeat in the last N minutes (default 5).
 */
router.get('/online', async (req, res) => {
  try {
    const minutes = Math.max(1, parseInt(req.query.minutes, 10) || 5);
    const since = new Date(Date.now() - minutes * 60 * 1000).toISOString();
    const { data, error } = await supabase.from('admin_activity')
      .select('id, profile_id, email, current_page, current_module, last_action, ip_address, device, last_heartbeat, created_at')
      .gte('last_heartbeat', since)
      .order('last_heartbeat', { ascending: false });
    if (error) throw error;
    const admins = (data || []).map((a) => ({
      id: a.id,
      profileId: a.profile_id,
      email: a.email,
      currentPage: a.current_page,
      currentModule: a.current_module,
      lastAction: a.last_action,
      ipAddress: a.ip_address,
      device: a.device,
      lastHeartbeat: a.last_heartbeat,
      isOnline: true,
    }));
    res.json({ success: true, data: admins, total: admins.length, onlineCount: admins.length });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Approval workflow
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /api/admin/approvals
 * Approval queue (default: pending only).
 */
router.get('/approvals', async (req, res) => {
  try {
    let q = supabase.from('admin_approvals')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false })
      .limit(Math.min(200, parseInt(req.query.limit, 10) || 100));
    if (req.query.status !== 'all') q = q.eq('status', req.query.status || 'pending');
    if (req.query.type) q = q.eq('request_type', req.query.type);
    const { data, error, count } = await q;
    if (error) throw error;

    const requestedIds = [...new Set((data || []).map((r) => r.requested_by).filter(Boolean))];
    const decidedIds = [...new Set((data || []).map((r) => r.decided_by).filter(Boolean))];
    const nameMap = await profileNameMap([...requestedIds, ...decidedIds]);

    const rows = (data || []).map((r) => ({
      id: r.id,
      requestType: r.request_type,
      title: r.title,
      payload: r.payload,
      previousValue: r.previous_value,
      newValue: r.new_value,
      status: r.status,
      requestedBy: r.requested_by,
      requestedByName: nameMap[r.requested_by] || 'Unknown',
      requestedByRole: r.requested_by_role,
      reason: r.reason,
      decidedBy: r.decided_by,
      decidedByName: nameMap[r.decided_by] || null,
      decidedByRole: r.decided_by_role,
      decisionReason: r.decision_reason,
      decidedAt: r.decided_at,
      thresholdValue: r.threshold_value,
      metadata: r.metadata,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
    res.json({ success: true, data: rows, total: count || rows.length, pending: rows.filter((r) => r.status === 'pending').length });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/admin/approvals
 * Staff/admin submits a request that requires Super Admin approval.
 * Body: { requestType, title?, payload?, previousValue?, newValue?, reason?, thresholdValue? }
 */
router.post('/approvals', async (req, res) => {
  try {
    if (!req.user?.id) return res.status(401).json({ success: false, error: 'Not authenticated' });
    const { requestType, title, payload, previousValue, newValue, reason, thresholdValue } = req.body || {};
    if (!requestType) return res.status(400).json({ success: false, error: 'requestType is required' });

    const { data, error } = await supabase.from('admin_approvals').insert({
      request_type: requestType,
      title: title || requestType,
      payload: payload || {},
      previous_value: previousValue ?? null,
      new_value: newValue ?? null,
      reason: reason || null,
      threshold_value: thresholdValue ?? null,
      requested_by: req.user.id,
      requested_by_role: req.user.role,
      status: 'pending',
      metadata: { source: 'admin-web' },
    }).select('*').single();
    if (error) throw error;

    // Financial / policy requests are also surfaced as a security alert.
    if (/loan|contribution|financial|policy|fee|export|member_delete/i.test(requestType)) {
      await raiseSecurityAlert({
        alertType: 'approval_requested',
        severity: 'medium',
        title: `Approval requested: ${requestType}`,
        description: `${req.user.email} requested approval for "${title || requestType}".`,
        profileId: req.user.id, email: req.user.email,
        metadata: { approvalId: data.id, requestType },
      });
    }
    res.status(201).json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

async function decideApproval(req, res, decision) {
  try {
    if (!['superadmin', 'super_admin'].includes(req.user?.role || '')) {
      return res.status(403).json({ success: false, error: 'Only the Super Admin can approve or reject requests' });
    }
    const { id } = req.params;
    const { reason } = req.body || {};
    const { data: existing, error: fetchError } = await supabase.from('admin_approvals').select('*').eq('id', id).maybeSingle();
    if (fetchError) throw fetchError;
    if (!existing) return res.status(404).json({ success: false, error: 'Approval request not found' });
    if (existing.status !== 'pending') return res.status(400).json({ success: false, error: `Request already ${existing.status}` });

    const { data, error } = await supabase.from('admin_approvals').update({
      status: decision,
      decided_by: req.user.id,
      decided_by_role: req.user.role,
      decision_reason: reason || null,
      decided_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq('id', id).select('*').single();
    if (error) throw error;

    // Audit record
    try {
      await supabase.from('audit_logs').insert({
        actor_id: req.user.id,
        actor_role: req.user.role,
        action: `approval.${decision}`,
        target_model: 'admin_approval',
        target_id: id,
        metadata: { requestType: existing.request_type, title: existing.title, reason: reason || null, decidedBy: req.user.email },
      });
    } catch (_) {}

    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

router.post('/approvals/:id/approve', (req, res) => decideApproval(req, res, 'approved'));
router.post('/approvals/:id/reject', (req, res) => decideApproval(req, res, 'rejected'));

// ─────────────────────────────────────────────────────────────────────────────
// Security alerts
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /api/admin/security-alerts
 * Returns persisted alerts + computed anomalies (failed-login bursts,
 * suspicious logins) from login_history/audit_logs so the Super Admin sees a
 * full picture even before a writer exists for every event.
 */
router.get('/security-alerts', async (req, res) => {
  try {
    const limit = Math.min(200, parseInt(req.query.limit, 10) || 50);
    const sinceHours = Math.max(1, parseInt(req.query.hours, 10) || 72);
    const since = new Date(Date.now() - sinceHours * 3600 * 1000).toISOString();

    const [alertsRes, suspiciousRes, failedRes] = await Promise.all([
      supabase.from('security_alerts').select('*').gte('created_at', since).order('created_at', { ascending: false }).limit(limit),
      supabase.from('login_history').select('id, profile_id, email, ip_address, location, device_type, os, browser, success, failure_reason, created_at').eq('success', false).gte('created_at', since).order('created_at', { ascending: false }).limit(25),
      // permission/financial changes recorded as audit_logs
      supabase.from('audit_logs').select('id, actor_id, actor_role, action, target_model, target_id, metadata, ip_address, user_agent, created_at').or('action.ilike.%permission%,action.ilike.%financial%,action.ilike.%loan%,action.ilike.%contribution%').gte('created_at', since).order('created_at', { ascending: false }).limit(25),
    ]);

    const nameMap = await profileNameMap([
      ...((alertsRes.data || []).map((a) => a.profile_id).filter(Boolean)),
      ...((suspiciousRes.data || []).map((a) => a.profile_id).filter(Boolean)),
      ...((failedRes.data || []).map((a) => a.actor_id).filter(Boolean)),
    ]);

    const alerts = (alertsRes.data || []).map((a) => ({
      id: a.id, type: a.alert_type, alertType: a.alert_type, severity: a.severity,
      title: a.title, description: a.description,
      profileId: a.profile_id, email: a.email, ipAddress: a.ip_address,
      location: a.location, device: a.device, status: a.status, channels: a.channels,
      metadata: a.metadata, createdAt: a.created_at, resolvedAt: a.resolved_at, resolvedBy: a.resolved_by,
    }));
    const computed = (suspiciousRes.data || []).map((s) => ({
      id: `computed:${s.id}`, type: 'failed_login', alertType: 'failed_login', severity: 'low',
      title: 'Failed login', description: s.failure_reason || 'Login attempt failed',
      profileId: s.profile_id, email: s.email, user: nameMap[s.profile_id] || s.email || 'Unknown',
      ipAddress: s.ip_address, location: s.location, device: s.device_type, status: 'unread',
      createdAt: s.created_at, computed: true,
    }));
    const financial = (failedRes.data || []).map((f) => ({
      id: `audit:${f.id}`, type: 'financial_change', alertType: 'financial_change', severity: 'medium',
      title: f.action, description: `${f.action} on ${f.target_model || ''} ${f.target_id || ''}`,
      profileId: f.actor_id, user: nameMap[f.actor_id] || 'Unknown', ipAddress: f.ip_address,
      status: 'unread', createdAt: f.created_at, computed: true, metadata: f.metadata,
    }));

    const all = [...alerts, ...computed, ...financial]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, limit);

    res.json({
      success: true,
      data: all,
      total: all.length,
      unread: all.filter((a) => a.status === 'unread').length,
      critical: all.filter((a) => a.severity === 'critical' || a.severity === 'high').length,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/security-alerts/:id/resolve', async (req, res) => {
  try {
    if (!['superadmin', 'super_admin'].includes(req.user?.role || '')) {
      return res.status(403).json({ success: false, error: 'Super Admin only' });
    }
    const { data, error } = await supabase.from('security_alerts').update({
      status: 'resolved', resolved_at: new Date().toISOString(), resolved_by: req.user.id,
    }).eq('id', req.params.id).select('*').maybeSingle();
    if (error) throw error;
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Super Admin activity dashboard stats
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /api/admin/stats
 * Live Super Admin dashboard statistics.
 */
router.get('/stats', async (req, res) => {
  try {
    const startOfToday = new Date();
    startOfToday.setUTCHours(0, 0, 0, 0);
    const todayIso = startOfToday.toISOString();

    const since15 = new Date(Date.now() - 15 * 60 * 1000).toISOString();

    const [
      adminsOnline, failedToday, pendingApprovals, suspicious,
      financialToday, loanApprovalsToday, contributionApprovalsToday, suspendedToday,
      totalAdmins,
    ] = await Promise.all([
      supabase.from('admin_activity').select('id', { count: 'exact', head: true }).gte('last_heartbeat', since15),
      supabase.from('login_history').select('id', { count: 'exact', head: true }).eq('success', false).gte('created_at', todayIso),
      supabase.from('admin_approvals').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
      supabase.from('login_history').select('id', { count: 'exact', head: true }).eq('success', false).gte('created_at', new Date(Date.now() - 24 * 3600 * 1000).toISOString()),
      supabase.from('audit_logs').select('id', { count: 'exact', head: true }).or('action.ilike.%loan%,action.ilike.%contribution%,action.ilike.%financial%').gte('created_at', todayIso),
      supabase.from('audit_logs').select('id', { count: 'exact', head: true }).ilike('action', '%loan%approve%').gte('created_at', todayIso),
      supabase.from('audit_logs').select('id', { count: 'exact', head: true }).ilike('action', '%contribution%create%').gte('created_at', todayIso),
      supabase.from('audit_logs').select('id', { count: 'exact', head: true }).ilike('action', '%member%suspend%').gte('created_at', todayIso),
      supabase.from('profiles').select('id', { count: 'exact', head: true }).in('role', ['admin', 'superadmin', 'super_admin', 'staff']),
    ]);

    res.json({
      success: true,
      data: {
        adminsOnline: adminsOnline.count || 0,
        failedLoginAttemptsToday: failedToday.count || 0,
        pendingApprovalRequests: pendingApprovals.count || 0,
        suspiciousActivitiesDetected: suspicious.count || 0,
        recentFinancialChanges: financialToday.count || 0,
        loanApprovalsToday: loanApprovalsToday.count || 0,
        contributionApprovalsToday: contributionApprovalsToday.count || 0,
        accountsSuspendedToday: suspendedToday.count || 0,
        totalAdmins: totalAdmins.count || 0,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Permissions
// ─────────────────────────────────────────────────────────────────────────────

const PERMISSION_CATALOG = [
  { key: 'view_contributions', label: 'View contributions', category: 'Finance' },
  { key: 'approve_payments', label: 'Approve payments', category: 'Finance' },
  { key: 'delete_transactions', label: 'Delete transactions', category: 'Finance' },
  { key: 'change_policies', label: 'Change policies', category: 'Finance' },
  { key: 'review_loans', label: 'Review loans', category: 'Loans' },
  { key: 'recommend_approval', label: 'Recommend loan approval', category: 'Loans' },
  { key: 'approve_loans', label: 'Approve loans', category: 'Loans' },
  { key: 'edit_financial_settings', label: 'Edit financial settings', category: 'Loans' },
  { key: 'view_member_profiles', label: 'View member profiles', category: 'Support' },
  { key: 'respond_to_enquiries', label: 'Respond to enquiries', category: 'Support' },
  { key: 'view_bank_details', label: 'View bank details', category: 'Support' },
  { key: 'access_financial_reports', label: 'Access financial reports', category: 'Reports' },
  { key: 'export_sensitive_data', label: 'Export sensitive financial data', category: 'Reports' },
  { key: 'manage_admins', label: 'Create/edit/suspend admin accounts', category: 'Administration' },
  { key: 'manage_permissions', label: 'Assign/revoke permissions', category: 'Administration' },
  { key: 'toggle_mobile_features', label: 'Toggle major mobile app features', category: 'Administration' },
  { key: 'change_security_settings', label: 'Change security settings', category: 'Administration' },
  { key: 'force_password_reset', label: 'Force password resets', category: 'Administration' },
  { key: 'remote_lock_admin', label: 'Lock or log out an admin remotely', category: 'Administration' },
];

router.get('/permissions', async (_req, res) => {
  res.json({ success: true, data: PERMISSION_CATALOG, permissions: PERMISSION_CATALOG, total: PERMISSION_CATALOG.length });
});

router.get('/roles/:id/permissions', async (req, res) => {
  try {
    // role_permissions stores role_id (uuid) + permission_id (uuid). We map by
    // permission_key via a join to a permissions table if present; otherwise we
    // fall back to a metadata field on the role row.
    const role = String(req.params.id);
    const { data: rp } = await supabase.from('role_permissions').select('permission_id, roles!inner(id)').eq('roles.id', role);
    const ids = (rp || []).map((r) => r.permission_id).filter(Boolean);
    let keys = [];
    if (ids.length) {
      const { data: perms } = await supabase.from('permissions').select('id, permission_key').in('id', ids);
      keys = (perms || []).map((p) => p.permission_key);
    }
    res.json({ success: true, data: keys, permissions: keys });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper: profile name map
// ─────────────────────────────────────────────────────────────────────────────
async function profileNameMap(ids) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (!unique.length) return {};
  const { data } = await supabase.from('profiles').select('id, name, email').in('id', unique);
  const map = {};
  (data || []).forEach((p) => { map[p.id] = p.name || p.email || 'Unknown'; });
  return map;
}

module.exports = router;
module.exports.PERMISSION_CATALOG = PERMISSION_CATALOG;
module.exports.recordLogin = recordLogin;
module.exports.clientMeta = clientMeta;
module.exports.raiseSecurityAlert = raiseSecurityAlert;
module.exports.profileNameMap = profileNameMap;
