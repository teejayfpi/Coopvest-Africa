/**
 * Organization finance — the employer/institution view.
 *
 * Coopvest's acquisition model is employer-based: an institution deducts a
 * monthly amount from each employee and remits a lump sum. This module answers
 * the four questions that model creates, per organization, per period:
 *
 *   Expected   — what the institution should have deducted this month
 *                (Σ each linked member's `monthly_amount`)
 *   Remitted   — what actually arrived, tracked against `payroll_batches`
 *   Outstanding— Expected − Remitted, the money still owed to Coopvest
 *   Member status — who is linked, contributing, lapsed or unlinked
 *
 * Two deliberate decisions:
 *
 *   1. An organization's remittance is measured from `payroll_batches`, the
 *      table whose whole purpose is recording a batch remittance (it carries
 *      `organization_id`, `period_month`, `total_contribution_amount`,
 *      `remitted_at`, `reconciled`, `mismatch_amount`). Summing member
 *      transactions instead would answer a different question — "how much did
 *      members pay" — which double-counts direct payments a member made
 *      alongside a payroll deduction, and cannot represent a remittance that
 *      arrived before the members were allocated.
 *
 *   2. A member with no `organization_id` is reported as UNLINKED rather than
 *      silently dropped. On the live project every member is unlinked while 411
 *      organizations exist, so an "expected" figure built only from linked
 *      members would show zero and look like a working report. Surfacing the
 *      unlinked count is what makes that visible.
 */

const periods = require('./reportPeriods');
const loanPolicy = require('./loanPolicy');

const OPEN_LOAN_STATUSES = ['approved', 'disbursed', 'active', 'repaying', 'overdue', 'in_recovery'];

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function round2(v) {
  return Math.round(v * 100) / 100;
}

function rate(numerator, denominator) {
  if (!denominator) return 0;
  return Math.round((numerator / denominator) * 1000) / 10;
}

async function safeRows(promise, label, logger) {
  try {
    const { data, error } = await promise;
    if (error) {
      if (logger) logger.warn(`orgFinance: ${label} failed: ${error.message}`);
      return [];
    }
    return data || [];
  } catch (err) {
    if (logger) logger.warn(`orgFinance: ${label} threw: ${err.message}`);
    return [];
  }
}

const loadOrganizations = (db, logger) => safeRows(
  db
    .from('organizations')
    .select('id, name, code, type, status, is_active, deduction_type, deduction_enabled, remittance_cycle, member_count, contact_name, contact_email, contact_phone, remittance_bank_name, remittance_account_number, remittance_account_name, remittance_reference_hint, notes, created_at')
    .limit(5000),
  'organizations',
  logger,
);

const loadProfiles = (db, logger) => safeRows(
  db
    .from('profiles')
    .select('id, user_id, name, full_name, email, phone, organization_id, monthly_amount, contribution_method, is_active, is_flagged, membership_status, registration_fee_paid, salary_deduction_consent, pending_organization_name, created_at')
    .limit(50000),
  'profiles',
  logger,
);

const loadBatches = (db, logger) => safeRows(
  db
    .from('payroll_batches')
    .select('id, batch_reference, organization_id, period_month, total_contribution_amount, total_registration_fee_amount, remitted_at, reconciled, reconciled_at, mismatch_amount, note, created_at')
    .limit(20000),
  'payroll_batches',
  logger,
);

const loadContributions = (db, logger) => safeRows(
  db
    .from('transactions')
    .select('id, profile_id, amount, type, status, contribution_source, contribution_month, remittance_batch_id, created_at')
    .limit(20000),
  'transactions',
  logger,
);

const loadLoans = (db, logger) => safeRows(
  db
    .from('loans')
    .select('id, profile_id, amount, remaining_balance, outstanding_balance, principal_repaid, status, next_due_date')
    .limit(20000),
  'loans',
  logger,
);

const CONTRIBUTION_TYPES = ['deposit', 'savings_deposit', 'transfer_in'];

// ── member status within an organization ─────────────────────────────────────

/**
 * Classify a linked member's standing.
 *
 * `contributing` — a contribution landed in the period.
 * `lapsed`       — linked, active, but nothing received in the period.
 * `inactive`     — deactivated or flagged.
 * `pending`      — no organization_id yet, but the member asked to join one.
 * `unlinked`     — no organization at all and no pending request.
 */
function classifyMember(member, { contributedThisPeriod, expectedAmount, isActive, isFlagged, pendingOrgName }) {
  if (!member.organization_id) {
    return pendingOrgName ? 'pending' : 'unlinked';
  }
  if (!isActive || isFlagged) return 'inactive';
  if (contributedThisPeriod) return 'contributing';
  // A member with no expected deduction cannot be "lapsed" — there was nothing
  // to deduct. Report them separately rather than as a failure.
  if (expectedAmount <= 0) return 'no_expectation';
  return 'lapsed';
}

/**
 * Build the per-organization financial position for a period.
 *
 * @returns {Promise<{rows: Array, totals: object, unlinked: object, period: object}>}
 */
async function buildOrganizationPosition({ db, range, logger }) {
  const [orgs, profiles, batches, contributions, loans] = await Promise.all([
    loadOrganizations(db, logger),
    loadProfiles(db, logger),
    loadBatches(db, logger),
    loadContributions(db, logger),
    loadLoans(db, logger),
  ]);

  const periodMonth = range.start.slice(0, 7); // 'YYYY-MM'
  const endMs = new Date(`${range.end}T23:59:59.999Z`).getTime();

  // Members grouped by organization.
  const byOrg = new Map();
  const unlinked = { total: 0, pending: 0, pendingNames: new Map() };
  const membersWithOrg = [];

  for (const p of profiles) {
    if (!p.organization_id) {
      unlinked.total += 1;
      if (p.pending_organization_name) {
        unlinked.pending += 1;
        const key = p.pending_organization_name;
        unlinked.pendingNames.set(key, (unlinked.pendingNames.get(key) || 0) + 1);
      }
      continue;
    }
    membersWithOrg.push(p);
    if (!byOrg.has(p.organization_id)) byOrg.set(p.organization_id, []);
    byOrg.get(p.organization_id).push(p);
  }

  // Which members contributed during the period, and how much.
  const completedContribs = contributions.filter(
    (t) => CONTRIBUTION_TYPES.includes(t.type) && t.status !== 'failed' && t.status !== 'reversed',
  );
  const contributedProfiles = new Set();
  const contributedByProfile = new Map();
  for (const t of completedContribs) {
    if (!periods.inRange(t.created_at, range)) continue;
    contributedProfiles.add(t.profile_id);
    contributedByProfile.set(t.profile_id, (contributedByProfile.get(t.profile_id) || 0) + num(t.amount));
  }

  // Loan position per profile (current, since this is an operational view).
  const loanByProfile = new Map();
  for (const l of loans) {
    if (!OPEN_LOAN_STATUSES.includes(l.status)) continue;
    const entry = loanByProfile.get(l.profile_id) || { count: 0, outstanding: 0, overdue: 0 };
    entry.count += 1;
    const bal = num(l.remaining_balance ?? l.outstanding_balance);
    entry.outstanding += bal;
    if (l.next_due_date && new Date(l.next_due_date).getTime() < Date.now() && bal > 0) entry.overdue += 1;
    loanByProfile.set(l.profile_id, entry);
  }

  // Remittances: batches for this period, matched by organization.
  const batchByOrg = new Map();
  for (const b of batches) {
    if (!b.organization_id) continue;
    const bMonth = b.period_month || (b.remitted_at || b.created_at || '').slice(0, 7);
    if (bMonth !== periodMonth) continue;
    const entry = batchByOrg.get(b.organization_id) || {
      batches: 0, remitted: 0, registrationFees: 0, mismatch: 0,
      reconciled: 0, lastRemittedAt: null, references: [],
    };
    entry.batches += 1;
    entry.remitted += num(b.total_contribution_amount);
    entry.registrationFees += num(b.total_registration_fee_amount);
    entry.mismatch += num(b.mismatch_amount);
    if (b.reconciled) entry.reconciled += 1;
    const at = b.remitted_at || b.created_at;
    if (at && (!entry.lastRemittedAt || at > entry.lastRemittedAt)) entry.lastRemittedAt = at;
    if (b.batch_reference) entry.references.push(b.batch_reference);
    batchByOrg.set(b.organization_id, entry);
  }

  const rows = orgs.map((o) => {
    const members = byOrg.get(o.id) || [];
    const expectedMonthly = members.reduce((s, m) => s + num(m.monthly_amount), 0);
    const rem = batchByOrg.get(o.id) || {
      batches: 0, remitted: 0, registrationFees: 0, mismatch: 0, reconciled: 0, lastRemittedAt: null, references: [],
    };

    const statusCounts = {
      contributing: 0, lapsed: 0, inactive: 0, no_expectation: 0,
    };
    let activeLoans = 0;
    let outstandingLoans = 0;
    let overdueLoans = 0;

    for (const m of members) {
      const expectedAmount = num(m.monthly_amount);
      const status = classifyMember(m, {
        contributedThisPeriod: contributedProfiles.has(m.id),
        expectedAmount,
        isActive: m.is_active !== false,
        isFlagged: Boolean(m.is_flagged),
        pendingOrgName: null,
      });
      if (statusCounts[status] !== undefined) statusCounts[status] += 1;

      const loan = loanByProfile.get(m.id);
      if (loan) {
        activeLoans += loan.count;
        outstandingLoans += loan.outstanding;
        overdueLoans += loan.overdue;
      }
    }

    const outstanding = round2(expectedMonthly - rem.remitted);

    return {
      organizationId: o.id,
      organization: o.name || '',
      code: o.code || '',
      type: o.type || '',
      isActive: o.is_active !== false && o.status !== 'inactive',
      deductionEnabled: Boolean(o.deduction_enabled),
      deductionType: o.deduction_type || '',
      remittanceCycle: o.remittance_cycle || '',

      members: members.length,
      // `organizations.member_count` is a stored counter that has drifted (it
      // reads 0 for every org on the live project). The live count is shown as
      // the source of truth, with the stored value kept for comparison.
      storedMemberCount: num(o.member_count),
      memberCountDrift: num(o.member_count) - members.length,

      expectedMonthly: round2(expectedMonthly),
      remitted: round2(rem.remitted),
      registrationFeesRemitted: round2(rem.registrationFees),
      outstanding,
      remittanceBatches: rem.batches,
      reconciledBatches: rem.reconciled,
      mismatchAmount: round2(rem.mismatch),
      lastRemittedAt: rem.lastRemittedAt,
      remittanceReferences: rem.references,

      contributingMembers: statusCounts.contributing,
      lapsedMembers: statusCounts.lapsed,
      inactiveMembers: statusCounts.inactive,
      membersWithoutExpectation: statusCounts.no_expectation,

      collectionRate: rate(rem.remitted, expectedMonthly),

      activeLoans,
      outstandingLoans: round2(outstandingLoans),
      overdueLoans,

      contactName: o.contact_name || '',
      contactEmail: o.contact_email || '',
      contactPhone: o.contact_phone || '',
      remittanceBankName: o.remittance_bank_name || '',
      remittanceAccountNumber: o.remittance_account_number || '',
      remittanceAccountName: o.remittance_account_name || '',
    };
  });

  // Sort by what is owed first — that is the actionable order for a finance
  // officer, not alphabetical.
  rows.sort((a, b) => b.outstanding - a.outstanding || b.expectedMonthly - a.expectedMonthly);

  const totals = {
    organizations: rows.length,
    organizationsWithMembers: rows.filter((r) => r.members > 0).length,
    organizationsEnabled: rows.filter((r) => r.deductionEnabled).length,
    members: rows.reduce((s, r) => s + r.members, 0),
    expectedMonthly: round2(rows.reduce((s, r) => s + r.expectedMonthly, 0)),
    remitted: round2(rows.reduce((s, r) => s + r.remitted, 0)),
    outstanding: round2(rows.reduce((s, r) => s + r.outstanding, 0)),
    registrationFeesRemitted: round2(rows.reduce((s, r) => s + r.registrationFeesRemitted, 0)),
    mismatchAmount: round2(rows.reduce((s, r) => s + r.mismatchAmount, 0)),
    activeLoans: rows.reduce((s, r) => s + r.activeLoans, 0),
    outstandingLoans: round2(rows.reduce((s, r) => s + r.outstandingLoans, 0)),
    overdueLoans: rows.reduce((s, r) => s + r.overdueLoans, 0),
    contributingMembers: rows.reduce((s, r) => s + r.contributingMembers, 0),
    lapsedMembers: rows.reduce((s, r) => s + r.lapsedMembers, 0),
  };
  totals.collectionRate = rate(totals.remitted, totals.expectedMonthly);

  return {
    period: { type: range.type, label: range.label, start: range.start, end: range.end, month: periodMonth },
    rows,
    totals,
    unlinked: {
      total: unlinked.total,
      pending: unlinked.pending,
      // Requests waiting on an admin decision, grouped by the employer named.
      pendingRequests: [...unlinked.pendingNames.entries()]
        .map(([name, count]) => ({ organizationName: name, members: count }))
        .sort((a, b) => b.members - a.members),
    },
  };
}

/**
 * Detail for one organization: members, contributions and remittance history.
 */
async function buildOrganizationDetail({ db, orgId, range, logger }) {
  const position = await buildOrganizationPosition({ db, range, logger });
  const row = position.rows.find((r) => r.organizationId === orgId);
  if (!row) return null;

  const [profiles, contributions, batches, loans] = await Promise.all([
    loadProfiles(db, logger),
    loadContributions(db, logger),
    loadBatches(db, logger),
    loadLoans(db, logger),
  ]);

  const members = profiles.filter((p) => p.organization_id === orgId);

  const completedContribs = contributions.filter(
    (t) => CONTRIBUTION_TYPES.includes(t.type) && t.status !== 'failed' && t.status !== 'reversed',
  );
  const contributedByProfile = new Map();
  for (const t of completedContribs) {
    if (!periods.inRange(t.created_at, range)) continue;
    contributedByProfile.set(
      t.profile_id,
      (contributedByProfile.get(t.profile_id) || 0) + num(t.amount),
    );
  }

  const loanByProfile = new Map();
  for (const l of loans) {
    if (!OPEN_LOAN_STATUSES.includes(l.status)) continue;
    const entry = loanByProfile.get(l.profile_id) || { count: 0, outstanding: 0 };
    entry.count += 1;
    entry.outstanding += num(l.remaining_balance ?? l.outstanding_balance);
    loanByProfile.set(l.profile_id, entry);
  }

  const memberRows = members.map((m) => {
    const loan = loanByProfile.get(m.id);
    const contributed = contributedByProfile.get(m.id) || 0;
    return {
      profileId: m.id,
      memberId: m.user_id || '',
      member: m.name || m.full_name || m.email || '',
      email: m.email || '',
      phone: m.phone || '',
      expectedMonthly: round2(num(m.monthly_amount)),
      contributed: round2(contributed),
      variance: round2(contributed - num(m.monthly_amount)),
      contributionMethod: m.contribution_method || '',
      salaryDeductionConsent: Boolean(m.salary_deduction_consent),
      activeLoans: loan?.count || 0,
      outstandingLoans: round2(loan?.outstanding || 0),
      status: classifyMember(m, {
        contributedThisPeriod: contributed > 0,
        expectedAmount: num(m.monthly_amount),
        isActive: m.is_active !== false,
        isFlagged: Boolean(m.is_flagged),
        pendingOrgName: null,
      }),
      joinedAt: m.created_at || '',
    };
  }).sort((a, b) => b.outstandingLoans - a.outstandingLoans || (a.member < b.member ? -1 : 1));

  const history = batches
    .filter((b) => b.organization_id === orgId)
    .map((b) => ({
      batchId: b.id,
      reference: b.batch_reference || '',
      periodMonth: b.period_month || '',
      remittedAt: b.remitted_at || b.created_at || '',
      contributionAmount: round2(num(b.total_contribution_amount)),
      registrationFeeAmount: round2(num(b.total_registration_fee_amount)),
      total: round2(num(b.total_contribution_amount) + num(b.total_registration_fee_amount)),
      reconciled: Boolean(b.reconciled),
      reconciledAt: b.reconciled_at || '',
      mismatchAmount: round2(num(b.mismatch_amount)),
      note: b.note || '',
    }))
    .sort((a, b) => (a.periodMonth < b.periodMonth ? 1 : -1));

  return {
    period: position.period,
    organization: row,
    members: memberRows,
    remittanceHistory: history,
    // Members who asked to join this employer but are not linked yet.
    pendingRequests: position.unlinked.pendingRequests
      .filter((p) => p.organizationName.toLowerCase() === String(row.organization).toLowerCase()),
  };
}

/**
 * Month-by-month trend for one organization, so a page can chart expected
 * against remitted over time.
 */
async function buildOrganizationTrend({ db, orgId, months = 12, logger }) {
  const [batches, profiles] = await Promise.all([
    loadBatches(db, logger),
    loadProfiles(db, logger),
  ]);

  const members = profiles.filter((p) => p.organization_id === orgId);
  const expectedMonthly = members.reduce((s, m) => s + num(m.monthly_amount), 0);

  const orgBatches = batches.filter((b) => b.organization_id === orgId);
  const byMonth = new Map();
  for (const b of orgBatches) {
    const key = b.period_month || (b.remitted_at || b.created_at || '').slice(0, 7);
    if (!key) continue;
    const entry = byMonth.get(key) || { remitted: 0, registrationFees: 0, batches: 0 };
    entry.remitted += num(b.total_contribution_amount);
    entry.registrationFees += num(b.total_registration_fee_amount);
    entry.batches += 1;
    byMonth.set(key, entry);
  }

  // Build the last N calendar months, including months with no remittance, so
  // a gap in the chart is visible rather than absent.
  const now = new Date();
  const out = [];
  for (let i = months - 1; i >= 0; i -= 1) {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
    const key = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
    const entry = byMonth.get(key) || { remitted: 0, registrationFees: 0, batches: 0 };
    out.push({
      periodMonth: key,
      expected: round2(expectedMonthly),
      remitted: round2(entry.remitted),
      registrationFees: round2(entry.registrationFees),
      outstanding: round2(expectedMonthly - entry.remitted),
      batches: entry.batches,
    });
  }

  return {
    organizationId: orgId,
    organization: (await loadOrganizations(db, logger)).find((o) => o.id === orgId)?.name || '',
    expectedMonthly: round2(expectedMonthly),
    members: members.length,
    months: out,
  };
}

module.exports = {
  buildOrganizationPosition,
  buildOrganizationDetail,
  buildOrganizationTrend,
  classifyMember,
  CONTRIBUTION_TYPES,
  OPEN_LOAN_STATUSES,
  loadOrganizations,
  loadProfiles,
  loadBatches,
  loadContributions,
  loadLoans,
  rate,
  round2,
};
