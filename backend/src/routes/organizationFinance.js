/**
 * Organization finance routes — the employer/institution view.
 *
 *   GET  /organizations/finance                     — position for every org
 *   GET  /organizations/finance/export.:format      — xlsx/csv of the above
 *   GET  /organizations/pending-requests            — members waiting to join
 *   POST /organizations/assign                      — link members to an org
 *   POST /organizations/pending-requests/:id/approve
 *   POST /organizations/pending-requests/:id/reject
 *   GET  /organizations/:id/finance                 — one org, with members
 *   GET  /organizations/:id/trend                   — month-by-month expected vs remitted
 *
 * The linkage endpoints exist because the member app has always been able to
 * *request* an employer (`POST /organizations/request-approval`) but nothing in
 * the admin surface could approve it and set `profiles.organization_id`. Every
 * member therefore stayed unlinked, which is why the organization reports read
 * zero members while 411 organizations sat in the table.
 *
 * Mounted before the adminApi router (which has no catch-all) and guarded by
 * requireAdmin.
 */

const express = require('express');
const { Router } = express;
const { body, param, validationResult } = require('express-validator');

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const periods = require('../lib/reportPeriods');
const orgFinance = require('../lib/organizationFinance');
const spreadsheet = require('../lib/spreadsheet');

const router = Router();

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ success: false, error: errors.array()[0].msg });
    return;
  }
  next();
}

/** Audit helper: record who changed a member's organization. */
async function logOrgAction(action, target, metadata, req) {
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
    // Never fail the operation because the audit write failed, but do record it.
    logger.warn('orgFinance: audit_logs insert failed:', err.message);
  }
}

/**
 * Resolve the reporting period. Defaults to the current month so a caller that
 * only wants "this month" does not have to supply a period at all.
 */
function resolvePeriodOrCurrentMonth(query) {
  if (!query.periodMonth && !query.month) return periods.resolvePeriod({
    type: 'month',
    year: new Date().getUTCFullYear(),
    month: new Date().getUTCMonth() + 1,
  });
  const m = String(query.periodMonth || query.month);
  const parsed = /^(\d{4})-(\d{1,2})$/.exec(m);
  if (!parsed) {
    throw new periods.PeriodError(`Invalid periodMonth: ${m} (expected YYYY-MM)`);
  }
  return periods.resolvePeriod({ type: 'month', year: Number(parsed[1]), month: Number(parsed[2]) });
}

// ── GET /organizations/finance ───────────────────────────────────────────────
router.get('/finance', async (req, res) => {
  try {
    const range = resolvePeriodOrCurrentMonth(req.query);
    const result = await orgFinance.buildOrganizationPosition({ db: supabase, range, logger });

    // Optional filtering, applied after the full build so totals stay meaningful.
    let rows = result.rows;
    if (req.query.search) {
      const q = String(req.query.search).toLowerCase();
      rows = rows.filter((r) =>
        r.organization.toLowerCase().includes(q) || r.code.toLowerCase().includes(q));
    }
    if (req.query.onlyEnabled === 'true') rows = rows.filter((r) => r.deductionEnabled);
    if (req.query.onlyWithMembers === 'true') rows = rows.filter((r) => r.members > 0);
    if (req.query.minOutstanding) {
      const min = Number(req.query.minOutstanding);
      rows = rows.filter((r) => r.outstanding >= min);
    }

    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(500, Number(req.query.limit) || 100);
    const from = (page - 1) * limit;

    res.json({
      success: true,
      period: result.period,
      totals: result.totals,
      unlinked: result.unlinked,
      rows: rows.slice(from, from + limit),
      pagination: { page, limit, total: rows.length },
      generatedAt: new Date().toISOString(),
    });
  } catch (err) {
    if (err instanceof periods.PeriodError) {
      res.status(400).json({ success: false, error: err.message });
      return;
    }
    logger.error('org finance error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /organizations/finance/export.:format ────────────────────────────────
router.get('/finance/export.:format', async (req, res) => {
  try {
    const range = resolvePeriodOrCurrentMonth(req.query);
    const result = await orgFinance.buildOrganizationPosition({ db: supabase, range, logger });

    const columns = [
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'code', label: 'Code', type: 'text' },
      { key: 'deductionType', label: 'Deduction Type', type: 'text' },
      { key: 'remittanceCycle', label: 'Cycle', type: 'text' },
      { key: 'members', label: 'Members', type: 'number' },
      { key: 'expectedMonthly', label: 'Expected (₦)', type: 'currency' },
      { key: 'remitted', label: 'Remitted (₦)', type: 'currency' },
      { key: 'outstanding', label: 'Outstanding (₦)', type: 'currency' },
      { key: 'collectionRate', label: 'Collection Rate (%)', type: 'number' },
      { key: 'contributingMembers', label: 'Contributing', type: 'number' },
      { key: 'lapsedMembers', label: 'Lapsed', type: 'number' },
      { key: 'inactiveMembers', label: 'Inactive', type: 'number' },
      { key: 'activeLoans', label: 'Active Loans', type: 'number' },
      { key: 'outstandingLoans', label: 'Loan Outstanding (₦)', type: 'currency' },
      { key: 'overdueLoans', label: 'Overdue Loans', type: 'number' },
      { key: 'remittanceBatches', label: 'Batches', type: 'number' },
      { key: 'lastRemittedAt', label: 'Last Remitted', type: 'date' },
      { key: 'remittanceBankName', label: 'Bank', type: 'text' },
      { key: 'remittanceAccountNumber', label: 'Account', type: 'text' },
    ];

    // Carry the totals through as a final row, so the download reconciles.
    const rows = [...result.rows, {
      organization: 'TOTAL',
      members: result.totals.members,
      expectedMonthly: result.totals.expectedMonthly,
      remitted: result.totals.remitted,
      outstanding: result.totals.outstanding,
      activeLoans: result.totals.activeLoans,
      outstandingLoans: result.totals.outstandingLoans,
      overdueLoans: result.totals.overdueLoans,
    }];

    const format = String(req.params.format || 'xlsx').toLowerCase();
    const filename = `coopvest-organizations-${result.period.month}.${format}`;

    if (format === 'csv') {
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.send(spreadsheet.toCsv({ columns, rows }));
      return;
    }
    if (format === 'xlsx') {
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.send(spreadsheet.toXlsx({ sheetName: `Orgs ${result.period.month}`, columns, rows }));
      return;
    }
    res.status(400).json({ success: false, error: `Unsupported format: ${format}. Use xlsx or csv.` });
  } catch (err) {
    if (err instanceof periods.PeriodError) {
      res.status(400).json({ success: false, error: err.message });
      return;
    }
    logger.error('org finance export error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /organizations/pending-requests ──────────────────────────────────────
router.get('/pending-requests', async (_req, res) => {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, user_id, name, full_name, email, phone, pending_organization_name, pending_organization_requested_at, monthly_amount, is_active, created_at')
      .not('pending_organization_name', 'is', null)
      .order('pending_organization_requested_at', { ascending: false })
      .limit(1000);
    if (error) throw error;

    const orgs = await orgFinance.loadOrganizations(supabase, logger);
    const byName = new Map(orgs.map((o) => [String(o.name).toLowerCase(), o]));

    const requests = (data || []).map((p) => {
      const name = p.pending_organization_name || '';
      const match = byName.get(name.toLowerCase());
      return {
        profileId: p.id,
        memberId: p.user_id || '',
        member: p.name || p.full_name || p.email || '',
        email: p.email || '',
        phone: p.phone || '',
        monthlyAmount: orgFinance.round2(Number(p.monthly_amount) || 0),
        requestedAt: p.pending_organization_requested_at || p.created_at,
        requestedOrganization: name,
        // If the named employer already exists the admin can approve in one
        // click; otherwise they must create the organization first.
        matchedOrganizationId: match?.id || null,
        matchedOrganizationName: match?.name || null,
        matchedOrganizationEnabled: Boolean(match?.deduction_enabled),
      };
    });

    res.json({ success: true, requests, total: requests.length });
  } catch (err) {
    logger.error('pending org requests error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── POST /organizations/assign ───────────────────────────────────────────────
/**
 * Link one or more members to an organization.
 *
 * Body: { organizationId, profileIds: string[], monthlyAmount? }
 * When `monthlyAmount` is given it is applied to each member so "Expected
 * monthly deduction" has a value even if the member never set one.
 */
router.post(
  '/assign',
  [
    body('organizationId').isUUID().withMessage('organizationId must be a valid id'),
    body('profileIds').isArray({ min: 1 }).withMessage('profileIds must be a non-empty array'),
    body('monthlyAmount').optional().isFloat({ min: 0 }).withMessage('monthlyAmount must be >= 0'),
  ],
  validate,
  async (req, res) => {
    try {
      const { organizationId, profileIds, monthlyAmount } = req.body;

      const { data: org, error: orgErr } = await supabase
        .from('organizations')
        .select('id, name, deduction_enabled')
        .eq('id', organizationId)
        .maybeSingle();
      if (orgErr) throw orgErr;
      if (!org) {
        res.status(404).json({ success: false, error: 'Organization not found' });
        return;
      }
      if (!org.deduction_enabled) {
        res.status(400).json({
          success: false,
          error: `${org.name} does not have salary deduction enabled. Enable it before assigning members.`,
        });
        return;
      }

      const now = new Date().toISOString();
      const unique = [...new Set(profileIds)];

      // Fetch current values so the audit trail can record what changed.
      const { data: before, error: beforeErr } = await supabase
        .from('profiles')
        .select('id, user_id, organization_id, monthly_amount')
        .in('id', unique);
      if (beforeErr) throw beforeErr;

      const updates = {
        organization_id: organizationId,
        contribution_method: 'salary_deduction',
        updated_at: now,
      };
      if (monthlyAmount !== undefined) updates.monthly_amount = monthlyAmount;

      const { error: updateErr } = await supabase
        .from('profiles')
        .update(updates)
        .in('id', unique);
      if (updateErr) throw updateErr;

      await logOrgAction(
        'ORG_MEMBERS_ASSIGNED',
        { model: 'Organization', id: organizationId },
        {
          organization: org.name,
          memberCount: unique.length,
          monthlyAmount: monthlyAmount ?? null,
          previous: (before || []).map((b) => ({
            profileId: b.id,
            memberId: b.user_id,
            organizationId: b.organization_id,
            monthlyAmount: b.monthly_amount,
          })),
        },
        req,
      );

      res.json({
        success: true,
        organization: { id: org.id, name: org.name },
        assigned: unique.length,
        monthlyAmount: monthlyAmount ?? null,
      });
    } catch (err) {
      logger.error('org assign error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── POST /organizations/unassign ─────────────────────────────────────────────
router.post(
  '/unassign',
  [
    body('profileIds').isArray({ min: 1 }).withMessage('profileIds must be a non-empty array'),
  ],
  validate,
  async (req, res) => {
    try {
      const unique = [...new Set(req.body.profileIds)];
      const { error } = await supabase
        .from('profiles')
        .update({ organization_id: null, updated_at: new Date().toISOString() })
        .in('id', unique);
      if (error) throw error;

      await logOrgAction('ORG_MEMBERS_UNASSIGNED', { model: 'Profile' }, { memberCount: unique.length }, req);
      res.json({ success: true, unassigned: unique.length });
    } catch (err) {
      logger.error('org unassign error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── POST /organizations/pending-requests/:id/approve ─────────────────────────
/**
 * Approve a member's employer request: link them to the matched organization
 * and clear the pending fields.
 */
router.post(
  '/pending-requests/:id/approve',
  [param('id').isUUID().withMessage('id must be a valid profile id')],
  validate,
  async (req, res) => {
    try {
      const profileId = req.params.id;
      const { data: profile, error: pErr } = await supabase
        .from('profiles')
        .select('id, user_id, name, pending_organization_name, monthly_amount, organization_id')
        .eq('id', profileId)
        .maybeSingle();
      if (pErr) throw pErr;
      if (!profile) {
        res.status(404).json({ success: false, error: 'Member not found' });
        return;
      }
      if (!profile.pending_organization_name) {
        res.status(400).json({ success: false, error: 'This member has no pending organization request' });
        return;
      }

      // Accept an explicit organization, otherwise match the requested name.
      let orgId = req.body.organizationId;
      if (!orgId) {
        const { data: match } = await supabase
          .from('organizations')
          .select('id, name, deduction_enabled')
          .ilike('name', profile.pending_organization_name)
          .maybeSingle();
        if (!match) {
          res.status(409).json({
            success: false,
            error: `No organization named "${profile.pending_organization_name}". Create it first, or pass organizationId explicitly.`,
          });
          return;
        }
        if (!match.deduction_enabled) {
          res.status(400).json({
            success: false,
            error: `${match.name} does not have salary deduction enabled.`,
          });
          return;
        }
        orgId = match.id;
      }

      const now = new Date().toISOString();
      const { data: updated, error: updErr } = await supabase
        .from('profiles')
        .update({
          organization_id: orgId,
          pending_organization_name: null,
          pending_organization_requested_at: null,
          contribution_method: 'salary_deduction',
          updated_at: now,
        })
        .eq('id', profileId)
        .select('id, user_id, organization_id')
        .single();
      if (updErr) throw updErr;

      await logOrgAction(
        'ORG_REQUEST_APPROVED',
        { model: 'Profile', id: profileId },
        {
          memberId: profile.user_id,
          requestedOrganization: profile.pending_organization_name,
          organizationId: orgId,
          previousOrganizationId: profile.organization_id,
        },
        req,
      );

      res.json({ success: true, profile: updated });
    } catch (err) {
      logger.error('org approve error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── POST /organizations/pending-requests/:id/reject ──────────────────────────
router.post(
  '/pending-requests/:id/reject',
  [
    param('id').isUUID().withMessage('id must be a valid profile id'),
    body('reason').optional().isString(),
  ],
  validate,
  async (req, res) => {
    try {
      const profileId = req.params.id;
      const now = new Date().toISOString();
      const { data: updated, error } = await supabase
        .from('profiles')
        .update({
          pending_organization_name: null,
          pending_organization_requested_at: null,
          updated_at: now,
        })
        .eq('id', profileId)
        .select('id, user_id')
        .maybeSingle();
      if (error) throw error;

      await logOrgAction(
        'ORG_REQUEST_REJECTED',
        { model: 'Profile', id: profileId },
        { reason: req.body.reason || null },
        req,
      );

      res.json({ success: true, profile: updated });
    } catch (err) {
      logger.error('org reject error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── GET /organizations/:id/finance ───────────────────────────────────────────
router.get(
  '/:id/finance',
  [param('id').isUUID().withMessage('id must be a valid organization id')],
  validate,
  async (req, res) => {
    try {
      const range = resolvePeriodOrCurrentMonth(req.query);
      const detail = await orgFinance.buildOrganizationDetail({
        db: supabase, orgId: req.params.id, range, logger,
      });
      if (!detail) {
        res.status(404).json({ success: false, error: 'Organization not found' });
        return;
      }
      res.json({ success: true, ...detail });
    } catch (err) {
      if (err instanceof periods.PeriodError) {
        res.status(400).json({ success: false, error: err.message });
        return;
      }
      logger.error('org detail error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

// ── GET /organizations/:id/trend ─────────────────────────────────────────────
router.get(
  '/:id/trend',
  [param('id').isUUID().withMessage('id must be a valid organization id')],
  validate,
  async (req, res) => {
    try {
      const months = Math.min(36, Math.max(1, Number(req.query.months) || 12));
      const trend = await orgFinance.buildOrganizationTrend({
        db: supabase, orgId: req.params.id, months, logger,
      });
      res.json({ success: true, ...trend });
    } catch (err) {
      logger.error('org trend error:', err);
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

module.exports = router;
