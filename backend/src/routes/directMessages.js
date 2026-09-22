/**
 * Direct messaging — one member at a time.
 *
 *   GET  /direct-messages/targets   — the member picker
 *   POST /direct-messages           — send to a single member
 *   GET  /direct-messages/thread/:profileId — what was sent to a member
 *
 * A direct message is stored as a `notifications` row scoped to the member's
 * `profile_id` (the same table the member's in-app inbox reads, and the same
 * one the broadcast path writes). It is NOT an announcement: an announcement is
 * targeted content with its own read tracking, whereas a direct message is
 * personal correspondence that should appear in the member's notification list.
 *
 * The type is `direct_message`, which the notifications_type_check constraint
 * now allows (migration 046). Before that change this insert would have raised
 * 23514 and the send would have looked like it succeeded while writing nothing.
 *
 * The member's app also receives a push, so "send a direct message" actually
 * reaches them rather than waiting for them to open the app.
 */

const express = require('express');
const { Router } = express;
const { body, param, query, validationResult } = require('express-validator');

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const notifyService = require('../services/notifyService');

const router = Router();

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ success: false, error: errors.array()[0].msg });
    return;
  }
  next();
}

async function audit(action, target, metadata, req) {
  try {
    await supabase.from('audit_logs').insert({
      actor_id: req?.user?.id || null,
      actor_role: req?.user?.role || null,
      action,
      target_model: target?.model || null,
      target_id: target?.id || null,
      metadata: { ...metadata, source: 'admin-web' },
      ip_address: req?.ip || null,
      user_agent: req?.headers?.['user-agent'] || null,
    });
  } catch (err) {
    logger.warn('direct message audit failed:', err.message);
  }
}

// ── GET /direct-messages/targets ─────────────────────────────────────────────
router.get(
  '/targets',
  [query('search').optional().isString()],
  validate,
  async (req, res) => {
    try {
      const limit = Math.min(200, Number(req.query.limit) || 50);
      const search = String(req.query.search || '').trim();

      let q = supabase
        .from('profiles')
        .select('id, user_id, name, full_name, email, phone, organization_id, is_active, membership_status')
        .order('name', { ascending: true })
        .limit(limit);

      if (search) {
        q = q.or(`name.ilike.%${search}%,email.ilike.%${search}%,user_id.ilike.%${search}%`);
      }

      const { data, error } = await q;
      if (error) throw error;

      const ids = (data || []).map((p) => p.id);
      const orgIds = [...new Set((data || []).map((p) => p.organization_id).filter(Boolean))];

      const orgMap = new Map();
      if (orgIds.length) {
        const { data: orgs } = await supabase
          .from('organizations').select('id, name').in('id', orgIds);
        for (const o of orgs || []) orgMap.set(o.id, o.name);
      }

      // How many direct messages each member has already received, so a picker
      // can show "2 sent" and the admin does not spam the same person.
      const sentCounts = new Map();
      if (ids.length) {
        const { data: prior } = await supabase
          .from('notifications')
          .select('profile_id')
          .eq('type', 'direct_message')
          .in('profile_id', ids);
        for (const r of prior || []) {
          sentCounts.set(r.profile_id, (sentCounts.get(r.profile_id) || 0) + 1);
        }
      }

      res.json({
        success: true,
        members: (data || []).map((p) => ({
          profileId: p.id,
          memberId: p.user_id || '',
          name: p.name || p.full_name || p.email || '',
          email: p.email || '',
          phone: p.phone || '',
          organization: orgMap.get(p.organization_id) || '',
          isActive: p.is_active !== false,
          membershipStatus: p.membership_status || '',
          directMessagesSent: sentCounts.get(p.id) || 0,
        })),
      });
    } catch (err) {
      logger.error('direct message targets error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── GET /direct-messages/thread/:profileId ───────────────────────────────────
router.get(
  '/thread/:profileId',
  [param('profileId').isUUID().withMessage('profileId must be a valid member id')],
  validate,
  async (req, res) => {
    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('id, title, message, type, is_read, read_at, created_at, data')
        .eq('profile_id', req.params.profileId)
        .eq('type', 'direct_message')
        .order('created_at', { ascending: false })
        .limit(100);
      if (error) throw error;

      res.json({
        success: true,
        messages: (data || []).map((n) => ({
          id: n.id,
          title: n.title,
          message: n.message,
          isRead: n.is_read,
          readAt: n.read_at,
          createdAt: n.created_at,
          sentBy: n.data?.sentBy || null,
        })),
        total: (data || []).length,
      });
    } catch (err) {
      logger.error('direct message thread error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── POST /direct-messages ────────────────────────────────────────────────────
router.post(
  '/',
  [
    body('profileId').isUUID().withMessage('profileId must be a valid member id'),
    body('title').isString().trim().notEmpty().withMessage('title is required'),
    body('message').isString().trim().notEmpty().withMessage('message is required'),
    body('sendPush').optional().isBoolean(),
    body('priority').optional().isIn(['low', 'normal', 'high', 'urgent']),
  ],
  validate,
  async (req, res) => {
    try {
      const { profileId, title, message, sendPush = true, priority = 'normal' } = req.body;

      const { data: member, error: mErr } = await supabase
        .from('profiles')
        .select('id, user_id, name, full_name, email')
        .eq('id', profileId)
        .maybeSingle();
      if (mErr) throw mErr;
      if (!member) {
        res.status(404).json({ success: false, error: 'Member not found' });
        return;
      }

      // 1. The member's in-app notification row. `profile_id` scopes it to them
      //    alone; the member's own inbox query already filters on that.
      const { data: row, error } = await supabase
        .from('notifications')
        .insert({
          profile_id: profileId,
          title,
          message,
          type: 'direct_message',
          category: 'info',
          priority,
          is_read: false,
          data: {
            kind: 'direct_message',
            sentBy: req.user?.email || null,
            sentById: req.user?.id || null,
          },
        })
        .select('*')
        .single();
      if (error) throw error;

      // 2. Push, so it reaches them now rather than on next app open.
      let push = { targeted: 0, errors: 0, status: 'skipped', reason: 'not_requested' };
      if (sendPush) {
        const { data: tokens } = await supabase
          .from('device_tokens')
          .select('token')
          .eq('active', true)
          .eq('profile_id', profileId);
        if (tokens && tokens.length > 0) {
          const result = await notifyService.sendPush({
            tokens: tokens.map((t) => t.token),
            title,
            body: message,
            type: 'direct_message',
            data: { type: 'direct_message', notificationId: row.id },
          });
          push = {
            targeted: tokens.length,
            errors: Number.isFinite(result.failureCount) ? result.failureCount : 0,
            status: result.status,
            reason: result.reason || null,
          };
        }
      }

      await audit('DIRECT_MESSAGE_SENT', { model: 'Profile', id: profileId }, {
        memberId: member.user_id,
        title,
        push,
      }, req);

      res.status(201).json({
        success: true,
        message: {
          id: row.id,
          title: row.title,
          message: row.message,
          createdAt: row.created_at,
        },
        recipient: {
          profileId: member.id,
          memberId: member.user_id || '',
          name: member.name || member.full_name || member.email || '',
        },
        push,
      });
    } catch (err) {
      logger.error('direct message send error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

module.exports = router;
