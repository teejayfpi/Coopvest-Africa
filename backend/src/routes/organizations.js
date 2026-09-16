/**
 * Member-facing organisation routes.
 *
 * Why this file exists
 * --------------------
 * The mobile app has always called `POST /organizations/request-approval` when a
 * member's employer is not yet enrolled, but no route ever answered it — the
 * request 404'd silently and the member saw the flow appear to succeed. There
 * was also no way to fetch the enrolled-organisation list, so the app shipped a
 * hardcoded list of ~18 generic strings ("Federal Universities", "Commercial
 * Banks", …) that could never match a real `organizations` row and could not be
 * updated without an app release.
 *
 * Both endpoints are member-scoped and deliberately read-only apart from the
 * approval request. They expose only the fields a member needs to identify their
 * employer — never remittance bank details or internal notes.
 */

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const { notifyAdminsOrganizationApprovalRequest } = require('../services/notifyService');

/** Fields safe to show a member choosing their employer. */
const SELECTABLE_FIELDS = 'id, name, code, type, remittance_cycle, deduction_enabled, status';

/**
 * GET /api/v1/organizations/selectable
 *
 * The enrolled employers a member can pick for salary deduction. Deliberately
 * unpaginated: this backs a searchable picker and the list is small, and a
 * member must be able to find their employer without paging.
 *
 * Only organisations that are active AND have deduction enabled are offered —
 * pointing a member at an employer that is not set up to remit would leave them
 * unable to contribute at all.
 */
router.get('/selectable', authenticate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('organizations')
      .select(SELECTABLE_FIELDS)
      .eq('status', 'active')
      .eq('deduction_enabled', true)
      .order('name', { ascending: true });

    if (error) throw error;

    const search = String(req.query.search || '').trim().toLowerCase();
    const rows = (data || []).filter((o) => {
      if (!search) return true;
      return (
        String(o.name || '').toLowerCase().includes(search) ||
        String(o.code || '').toLowerCase().includes(search)
      );
    });

    res.json({
      success: true,
      organizations: rows.map((o) => ({
        id: o.id,
        name: o.name,
        code: o.code || null,
        type: o.type || null,
        remittanceCycle: o.remittance_cycle || 'monthly',
      })),
      total: rows.length,
    });
  } catch (err) {
    logger.error('organizations selectable error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/v1/organizations/request-approval
 *
 * A member asks us to enrol their employer. Recorded on their profile so an
 * admin can see who is waiting, and surfaced to admins via a notification.
 *
 * Idempotent: re-requesting while a request is already open returns the existing
 * request rather than creating duplicates for the admin queue.
 */
router.post('/request-approval', authenticate, async (req, res) => {
  try {
    const organizationName = String(req.body?.organization_name || '').trim();

    if (!organizationName) {
      return res.status(400).json({
        success: false,
        error: 'organization_name is required',
      });
    }
    if (organizationName.length > 200) {
      return res.status(400).json({
        success: false,
        error: 'organization_name is too long',
      });
    }

    const now = new Date().toISOString();

    const { data: profile, error: profileErr } = await supabase
      .from('profiles')
      .select('id, name, email, pending_organization_name')
      .eq('id', req.user.id)
      .maybeSingle();
    if (profileErr) throw profileErr;
    if (!profile) {
      return res.status(404).json({ success: false, error: 'Profile not found' });
    }

    // Already waiting on this exact employer — nothing to do.
    if (
      profile.pending_organization_name &&
      profile.pending_organization_name.toLowerCase() === organizationName.toLowerCase()
    ) {
      return res.json({
        success: true,
        status: 'pending',
        organization_name: profile.pending_organization_name,
        message: 'Your request is already with our team.',
      });
    }

    // If the employer is in fact already enrolled and enabled, tell the member
    // to pick it instead of queueing a redundant request.
    const { data: existing } = await supabase
      .from('organizations')
      .select('id, name, deduction_enabled, status')
      .ilike('name', organizationName)
      .maybeSingle();

    if (existing && existing.status === 'active' && existing.deduction_enabled) {
      return res.json({
        success: true,
        status: 'enrolled',
        organization: { id: existing.id, name: existing.name },
        message: `${existing.name} is already enrolled — you can select it now.`,
      });
    }

    const { error: updateErr } = await supabase
      .from('profiles')
      .update({
        pending_organization_name: organizationName,
        pending_organization_requested_at: now,
        updated_at: now,
      })
      .eq('id', req.user.id);
    if (updateErr) throw updateErr;

    // Non-fatal: the request is recorded either way, and the admin queue in the
    // dashboard is the durable record.
    try {
      await notifyAdminsOrganizationApprovalRequest({
        profileId: req.user.id,
        memberName: profile.name || profile.email || 'A member',
        organizationName,
      });
    } catch (notifyErr) {
      logger.warn('organization approval notify failed (non-fatal):', notifyErr.message);
    }

    logger.info(`Organization approval requested: "${organizationName}" by ${req.user.id}`);
    res.status(201).json({
      success: true,
      status: 'pending',
      organization_name: organizationName,
      message:
        'Request received. We will contact your employer, and salary deduction will be enabled once they are enrolled.',
    });
  } catch (err) {
    logger.error('organization request-approval error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/organizations/me
 *
 * The member's own organisation plus their deduction status, so the app can
 * label the contribution screen ("Salary deduction via …") without guessing.
 */
router.get('/me', authenticate, async (req, res) => {
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('organization_id, contribution_method, contribution_type, pending_organization_name, salary_deduction_consent')
      .eq('id', req.user.id)
      .maybeSingle();
    if (error) throw error;

    let organization = null;
    if (profile?.organization_id) {
      const { data: org } = await supabase
        .from('organizations')
        .select(SELECTABLE_FIELDS)
        .eq('id', profile.organization_id)
        .maybeSingle();
      if (org) {
        organization = {
          id: org.id,
          name: org.name,
          code: org.code || null,
          type: org.type || null,
          remittanceCycle: org.remittance_cycle || 'monthly',
        };
      }
    }

    res.json({
      success: true,
      organization,
      pendingOrganizationName: profile?.pending_organization_name || null,
      contributionMethod: profile?.contribution_method || null,
      contributionType: profile?.contribution_type || null,
      salaryDeductionConsent: profile?.salary_deduction_consent === true,
      // True when this member contributes via employer payroll deduction.
      onSalaryDeduction: Boolean(
        organization &&
          ['payroll', 'salary_deduction'].includes(
            profile?.contribution_method || profile?.contribution_type,
          ),
      ),
    });
  } catch (err) {
    logger.error('organizations me error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
