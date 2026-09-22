/**
 * Ledger-backed comparative metrics.
 *
 * Every metric here is derived from the authoritative money tables —
 * `transactions` (the member-facing ledger), `contributions`, `loans`,
 * `loan_repayments`, `member_fees`, `rollovers` and `profiles` — never from a
 * pre-aggregated dashboard field. That is what lets a figure on the comparison
 * screen be traced back to the individual transactions that produced it (see
 * the drill-down endpoint).
 *
 * Two kinds of metric, handled differently:
 *
 *   FLOW  ("what happened during the period")
 *     Restricted to rows whose event date falls inside the period. Contributions,
 *     disbursements, new members, repayments.
 *
 *   STOCK ("what the position was at the end of the period")
 *     Balances and counts as at the period end date, not "anything that happened
 *     in the window". Outstanding loans are reconstructed by starting from the
 *     live balance and adding back repayments received after the period end,
 *     because `loans.remaining_balance` is a current value only. Comparing a
 *     point-in-time balance against a range total would be meaningless.
 */

const loanPolicy = require('./loanPolicy');
const periods = require('./reportPeriods');

// Contribution transaction types, matching CONTRIBUTION_TYPES elsewhere.
const CONTRIBUTION_TYPES = ['deposit', 'savings_deposit', 'transfer_in'];

// Rollover eligibility: 70% of original principal must be repaid (migration 039).
const ROLLOVER_MIN_PRINCIPAL_PCT = 70;

// Loan statuses that count as still-money-out at a point in time.
const OPEN_LOAN_STATUSES = ['approved', 'disbursed', 'active', 'repaying', 'overdue', 'in_recovery'];
// Statuses that mean a loan was actually funded. Listed explicitly rather than
// "anything not rejected" so a future status cannot silently inflate the book.
const DEEMED_DISBURSED_STATUSES = ['approved', 'disbursed', 'active', 'repaying', 'overdue', 'in_recovery', 'completed'];
const DEFAULT_BLOCKING_STATUSES = loanPolicy.DEFAULT_BLOCKING_STATUSES;
const CLOSED_LOAN_STATUSES = ['completed', 'rejected', 'cancelled'];

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

/** Read rows, tolerating a missing table or a query error. */
async function safeRows(promise, label, logger) {
  try {
    const { data, error } = await promise;
    if (error) {
      if (logger) logger.warn(`comparative: ${label} failed: ${error.message}`);
      return [];
    }
    return data || [];
  } catch (err) {
    if (logger) logger.warn(`comparative: ${label} threw: ${err.message}`);
    return [];
  }
}

function loadProfiles(db, logger, limit = 20000) {
  // `name`, `full_name` and `email` are included so every consumer (metrics and
  // the drill-down) can label a row with a person, not just a UUID.
  return safeRows(
    db
      .from('profiles')
      .select('id, user_id, name, full_name, email, organization_id, membership_status, is_active, is_flagged, created_at, monthly_amount')
      .limit(limit),
    'profiles',
    logger,
  );
}

function loadOrganizations(db, logger) {
  return safeRows(
    db.from('organizations').select('id, name, code').limit(5000),
    'organizations',
    logger,
  );
}

function loadTransactions(db, logger, limit = 20000) {
  return safeRows(
    db
      .from('transactions')
      .select('id, transaction_id, profile_id, type, category, amount, status, payment_method, reference, contribution_source, contribution_month, created_at, completed_at, reversed')
      .limit(limit),
    'transactions',
    logger,
  );
}

function loadLoans(db, logger, limit = 20000) {
  // NOTE: `loans.disbursed_at` does NOT exist — only `disbursed_by` does.
  // Selecting it makes PostgREST reject the whole query, which silently
  // zeroed every loan metric. `approved_at` is the populated timestamp marking
  // when a loan became live (see loanRecoveryWorker.js), so it is the date used
  // for disbursement-time metrics.
  return safeRows(
    db
      .from('loans')
      .select('id, loan_id, profile_id, loan_type, amount, original_principal, total_repayment, remaining_balance, outstanding_balance, principal_repaid, status, next_due_date, created_at, approved_at, is_rollover, rollover_count, monthly_repayment')
      .limit(limit),
    'loans',
    logger,
  );
}

function loadRepayments(db, logger, limit = 20000) {
  return safeRows(
    db
      .from('loan_repayments')
      .select('id, loan_id, profile_id, amount, principal_component, interest_component, paid_at, status, created_at')
      .limit(limit),
    'loan_repayments',
    logger,
  );
}

function loadRollovers(db, logger, limit = 20000) {
  return safeRows(
    db
      .from('rollovers')
      .select('id, loan_id, profile_id, status, extension_months, requested_amount, net_disbursed, created_at, approved_at')
      .limit(limit),
    'rollovers',
    logger,
  );
}

function loadFees(db, logger, limit = 20000) {
  return safeRows(
    db.from('member_fees').select('id, profile_id, fee_type, label, amount, status, paid_at, created_at').limit(limit),
    'member_fees',
    logger,
  );
}

function loadContributions(db, logger, limit = 20000) {
  return safeRows(
    db
      .from('contributions')
      .select('id, profile_id, amount, status, contribution_month, contribution_type, contribution_source, created_at')
      .limit(limit),
    'contributions',
    logger,
  );
}

/** Sum of amounts for rows whose chosen date field falls inside the period. */
function sumIn(rows, range, dateField = 'created_at', amountField = 'amount') {
  let total = 0;
  for (const r of rows) {
    const d = r[dateField] || r.created_at;
    if (periods.inRange(d, range)) total += num(r[amountField]);
  }
  return total;
}

function countIn(rows, range, dateField = 'created_at') {
  let n = 0;
  for (const r of rows) {
    const d = r[dateField] || r.created_at;
    if (periods.inRange(d, range)) n += 1;
  }
  return n;
}

/** Rows whose date field falls inside the period. */
function rowsIn(rows, range, dateField = 'created_at') {
  return rows.filter((r) => periods.inRange(r[dateField] || r.created_at, range));
}

function rate(numerator, denominator) {
  if (!denominator) return 0;
  return Math.round((numerator / denominator) * 1000) / 10;
}

// ── money allocation categories ──────────────────────────────────────────────

/**
 * Classify a contribution row into the income categories management reports on.
 * `member_fees` is the authoritative source for levies and fees; contributions
 * only distinguish registration fees from ordinary contributions.
 */
function incomeCategoryOf(row) {
  const hint = `${row.fee_type || ''} ${row.label || ''} ${row.contribution_type || ''}`.toLowerCase();
  if (row.fee_type === 'registration_fee' || hint.includes('registration')) return 'registration_fees';
  if (hint.includes('agm')) return 'agm_levies';
  if (hint.includes('development')) return 'development_levies';
  if (row.fee_type === 'levy' || hint.includes('levy')) return 'other_income';
  if (row.fee_type === 'fine' || hint.includes('fine') || hint.includes('penalty')) return 'other_income';
  return 'other_income';
}

// ═══════════════════════════════════════════════════════════════════════════
// Section: Membership
// ═══════════════════════════════════════════════════════════════════════════

async function membershipMetrics(ctx) {
  const { db, range, logger } = ctx;
  const profiles = await loadProfiles(db, logger, 50000);

  const newMembers = countIn(profiles, range);
  // Active/inactive are point-in-time states, evaluated as at the period end.
  const asAt = new Date(`${range.end}T23:59:59.999Z`).getTime();
  const existed = profiles.filter((p) => new Date(p.created_at).getTime() <= asAt);
  const activeMembers = existed.filter((p) => p.is_active && !p.is_flagged).length;
  const inactiveMembers = existed.filter((p) => p.is_active === false || p.is_flagged).length;

  const withOrg = existed.filter((p) => p.organization_id);
  const orgMap = new Map((await loadOrganizations(db, logger)).map((o) => [o.id, o.name]));
  const orgCounts = new Map();
  for (const p of withOrg) {
    orgCounts.set(p.organization_id, (orgCounts.get(p.organization_id) || 0) + 1);
  }

  return {
    key: 'membership',
    label: 'Membership',
    metrics: [
      { key: 'new_members', label: 'New members', value: newMembers, unit: 'number' },
      { key: 'total_members', label: 'Total members (period end)', value: existed.length, unit: 'number' },
      { key: 'active_members', label: 'Active members (period end)', value: activeMembers, unit: 'number' },
      { key: 'inactive_members', label: 'Inactive members (period end)', value: inactiveMembers, unit: 'number' },
      { key: 'organization_linked_members', label: 'Members in an organization', value: withOrg.length, unit: 'number' },
      {
        key: 'avg_members_per_organization',
        label: 'Avg members per organization',
        value: orgCounts.size ? Math.round((withOrg.length / orgCounts.size) * 10) / 10 : 0,
        unit: 'number',
      },
    ],
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Section: Savings & Contributions
// ═══════════════════════════════════════════════════════════════════════════

async function savingsMetrics(ctx) {
  const { db, range, logger } = ctx;
  const [transactions, contributions, fees] = await Promise.all([
    loadTransactions(db, logger),
    loadContributions(db, logger),
    loadFees(db, logger),
  ]);

  const completedTx = transactions.filter((t) => t.status !== 'failed' && t.status !== 'reversed');

  // The `transactions` table IS the central ledger, so it is the authoritative
  // source for money (see the merged-ledger endpoints, which union
  // ledger_entries with transactions). `contributions` is a derived table and
  // the two can disagree — on the live project `contributions` holds rows the
  // ledger does not, including a ₦100,000,000 test entry. Preferring the
  // derived table would make the headline figure untraceable to a transaction,
  // which is exactly what this module must not do.
  const sourceRows = rowsIn(
    completedTx.filter((t) => CONTRIBUTION_TYPES.includes(t.type)),
    range,
  );

  // Cross-check: if the derived table disagrees, report it rather than hide it.
  const derivedRows = rowsIn(contributions, range);
  const derivedTotal = derivedRows.reduce((s, r) => s + num(r.amount), 0);
  const ledgerTotal = sourceRows.reduce((s, r) => s + num(r.amount), 0);
  const dataQuality = [];
  if (derivedRows.length > 0 && Math.abs(derivedTotal - ledgerTotal) > 0.01) {
    dataQuality.push({
      check: 'contributions_table_vs_ledger',
      message:
        'The derived `contributions` table disagrees with the transaction ledger for this period. '
        + 'Reports use the ledger; the difference is shown for reconciliation.',
      ledger: ledgerTotal,
      derivedTable: derivedTotal,
      difference: Math.round((derivedTotal - ledgerTotal) * 100) / 100,
    });
  }

  const totalContributions = ledgerTotal;
  const contributors = new Set(sourceRows.map((r) => r.profile_id).filter(Boolean));
  const salaryDeductions = sourceRows
    .filter((r) => r.contribution_source === 'salary_deduction')
    .reduce((s, r) => s + num(r.amount), 0);
  const directContributions = sourceRows
    .filter((r) => r.contribution_source !== 'salary_deduction')
    .reduce((s, r) => s + num(r.amount), 0);

  // Levies and registration fees come from member_fees, which records the fee
  // type; a contribution row cannot distinguish an AGM levy from a monthly one.
  const feeRows = rowsIn(fees, range);
  const byCategory = { registration_fees: 0, agm_levies: 0, development_levies: 0, other_income: 0 };
  for (const f of feeRows) byCategory[incomeCategoryOf(f)] += num(f.amount);

  const totalIncome =
    totalContributions + byCategory.registration_fees + byCategory.agm_levies +
    byCategory.development_levies + byCategory.other_income;

  // Withdrawals are money leaving, tracked as debits.
  const withdrawals = rowsIn(
    completedTx.filter((t) => t.type === 'withdrawal' || t.category === 'debit'),
    range,
  ).reduce((s, r) => s + num(r.amount), 0);

  const pctOfTotal = (v) => (totalIncome > 0 ? Math.round((v / totalIncome) * 1000) / 10 : 0);

  return {
    key: 'savings',
    label: 'Savings & Contributions',
    dataQuality,
    metrics: [
      { key: 'total_contributions', label: 'Total contributions', value: totalContributions, unit: 'currency' },
      { key: 'total_income', label: 'Total income (incl. fees & levies)', value: totalIncome, unit: 'currency' },
      {
        key: 'average_contribution',
        label: 'Average contribution',
        value: sourceRows.length ? Math.round((totalContributions / sourceRows.length) * 100) / 100 : 0,
        unit: 'currency',
      },
      { key: 'number_of_contributors', label: 'Number of contributors', value: contributors.size, unit: 'number' },
      { key: 'salary_deductions', label: 'Salary deductions', value: salaryDeductions, unit: 'currency' },
      { key: 'direct_contributions', label: 'Direct contributions', value: directContributions, unit: 'currency' },
      {
        key: 'salary_share_pct',
        label: 'Salary share of contributions',
        value: totalContributions > 0 ? rate(salaryDeductions, totalContributions) : 0,
        unit: 'percent',
      },
      { key: 'registration_fees', label: 'Registration fees', value: byCategory.registration_fees, unit: 'currency' },
      { key: 'agm_levies', label: 'AGM levies', value: byCategory.agm_levies, unit: 'currency' },
      { key: 'development_levies', label: 'Development levies', value: byCategory.development_levies, unit: 'currency' },
      { key: 'other_income', label: 'Other income', value: byCategory.other_income, unit: 'currency' },
      { key: 'withdrawals', label: 'Withdrawals', value: withdrawals, unit: 'currency' },
      { key: 'net_position', label: 'Net (income − withdrawals)', value: totalIncome - withdrawals, unit: 'currency' },
    ],
    composition: [
      { key: 'salary_deductions', label: 'Salary deductions', value: salaryDeductions, pct: pctOfTotal(salaryDeductions) },
      { key: 'direct_contributions', label: 'Direct contributions', value: directContributions, pct: pctOfTotal(directContributions) },
      { key: 'registration_fees', label: 'Registration fees', value: byCategory.registration_fees, pct: pctOfTotal(byCategory.registration_fees) },
      { key: 'agm_levies', label: 'AGM levies', value: byCategory.agm_levies, pct: pctOfTotal(byCategory.agm_levies) },
      { key: 'development_levies', label: 'Development levies', value: byCategory.development_levies, pct: pctOfTotal(byCategory.development_levies) },
      { key: 'other_income', label: 'Other income', value: byCategory.other_income, pct: pctOfTotal(byCategory.other_income) },
    ].filter((c) => c.value > 0),
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Section: Loan performance
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Reconstruct each loan's position as at `range.end`.
 *
 * `loans.remaining_balance` is a live value, so the historical balance is the
 * live balance plus every repayment received after the period end. Repayments
 * carry `principal_component`, which makes the principal position exact rather
 * than estimated.
 */
function loanPositionAsAt(loan, repayments, endMs, nowMs) {
  const later = repayments.filter(
    (r) => r.loan_id === loan.id && new Date(r.paid_at || r.created_at).getTime() > endMs,
  );
  const laterTotal = later.reduce((s, r) => s + num(r.amount), 0);
  const laterPrincipal = later.reduce((s, r) => s + num(r.principal_component), 0);

  const liveBalance = num(loan.remaining_balance ?? loan.outstanding_balance);
  const balanceAtEnd = liveBalance + laterTotal;

  const livePrincipalRepaid = num(loan.principal_repaid);
  const principalRepaidAtEnd = Math.max(0, livePrincipalRepaid - laterPrincipal);

  const createdAt = new Date(loan.created_at).getTime();
  const existed = createdAt <= endMs;

  return {
    existed,
    balanceAtEnd: Math.max(0, Math.round(balanceAtEnd * 100) / 100),
    principalRepaidAtEnd,
    originalPrincipal: num(loan.original_principal) || num(loan.amount),
    createdInPeriod: periods.inRange(loan.created_at, { start: isoFrom(endMs, -0), end: isoFrom(endMs, 0) }),
  };
}

function isoFrom(ms, offsetDays) {
  return new Date(ms + offsetDays * 86400000).toISOString().slice(0, 10);
}

async function loanMetrics(ctx) {
  const { db, range, logger } = ctx;
  const [loans, repayments, rollovers] = await Promise.all([
    loadLoans(db, logger),
    loadRepayments(db, logger),
    loadRollovers(db, logger),
  ]);

  const endMs = new Date(`${range.end}T23:59:59.999Z`).getTime();

  const created = rowsIn(loans, range);
  const amountRequested = created.reduce((s, l) => s + num(l.amount), 0);

  const approved = rowsIn(
    loans.filter((l) => DEEMED_DISBURSED_STATUSES.includes(l.status)),
    range,
    'approved_at',
  );
  const rejected = rowsIn(loans.filter((l) => l.status === 'rejected'), range);
  // `approved_at` is the disbursement timestamp: the loans table has no
  // disbursed_at (only disbursed_by), as documented in loanRecoveryWorker.
  const disbursed = approved;
  const amountDisbursed = disbursed.reduce((s, l) => s + num(l.amount), 0);
  const amountApproved = approved.reduce((s, l) => s + num(l.amount), 0);

  const repaymentsInPeriod = rowsIn(repayments, range, 'paid_at');
  const repaymentsTotal = repaymentsInPeriod.reduce((s, r) => s + num(r.amount), 0);

  // Point-in-time stock: only loans that existed by the period end, with the
  // balance reconstructed to that date.
  const positions = loans
    .map((l) => ({ loan: l, ...loanPositionAsAt(l, repayments, endMs, Date.now()) }))
    .filter((p) => p.existed);

  const openPositions = positions.filter((p) => OPEN_LOAN_STATUSES.includes(p.loan.status));
  const outstanding = openPositions.reduce((s, p) => s + p.balanceAtEnd, 0);

  // Overdue as at period end: the due date had already passed and the loan was
  // not settled. Using the live status would let a loan that defaulted later
  // retroactively change a past period's default rate.
  const overduePositions = positions.filter((p) => {
    if (!p.loan.next_due_date) return false;
    if (CLOSED_LOAN_STATUSES.includes(p.loan.status) && !['completed'].includes(p.loan.status)) return false;
    const due = new Date(p.loan.next_due_date).getTime();
    return due < endMs && p.balanceAtEnd > 0;
  });

  const seriousDefault = positions.filter((p) => DEFAULT_BLOCKING_STATUSES.includes(p.loan.status)).length;

  const repaidThisPeriodCount = repaymentsInPeriod.length;
  const disbursedCount = disbursed.length || approved.length;

  return {
    key: 'loans',
    label: 'Loan Performance',
    metrics: [
      { key: 'applications', label: 'Applications', value: created.length, unit: 'number' },
      { key: 'applications_approved', label: 'Applications approved', value: approved.length, unit: 'number' },
      { key: 'applications_rejected', label: 'Applications rejected', value: rejected.length, unit: 'number' },
      { key: 'amount_requested', label: 'Total amount requested', value: amountRequested, unit: 'currency' },
      { key: 'amount_approved', label: 'Total amount approved', value: amountApproved, unit: 'currency' },
      { key: 'amount_disbursed', label: 'Total amount disbursed', value: amountDisbursed, unit: 'currency' },
      { key: 'repayments_received', label: 'Repayments received', value: repaymentsTotal, unit: 'currency' },
      { key: 'outstanding_loans', label: 'Outstanding (period end)', value: Math.round(outstanding * 100) / 100, unit: 'currency' },
      { key: 'outstanding_loan_count', label: 'Loans outstanding (period end)', value: openPositions.length, unit: 'number' },
      { key: 'overdue_loans', label: 'Overdue loans (period end)', value: overduePositions.length, unit: 'number' },
      {
        key: 'overdue_exposure',
        label: 'Overdue exposure (period end)',
        value: Math.round(overduePositions.reduce((s, p) => s + p.balanceAtEnd, 0) * 100) / 100,
        unit: 'currency',
      },
      {
        key: 'default_rate',
        label: 'Default rate (period end)',
        value: openPositions.length + seriousDefault > 0
          ? rate(seriousDefault, openPositions.length + seriousDefault)
          : 0,
        unit: 'percent',
        // A rising default rate is bad; the insight engine needs to know.
        higherIsBetter: false,
      },
      {
        key: 'average_loan_size',
        label: 'Average loan size (disbursed)',
        value: disbursedCount ? Math.round((amountDisbursed || amountApproved) / disbursedCount) : 0,
        unit: 'currency',
      },
      { key: 'repayment_count', label: 'Repayments recorded', value: repaidThisPeriodCount, unit: 'number' },
      { key: 'rollover_requests', label: 'Rollover requests', value: countIn(rollovers, range), unit: 'number' },
      {
        key: 'rollover_approvals',
        label: 'Rollover approvals',
        value: rowsIn(rollovers.filter((r) => r.status === 'approved'), range).length,
        unit: 'number',
      },
    ],
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Section: Rollover performance
// ═══════════════════════════════════════════════════════════════════════════

async function rolloverMetrics(ctx) {
  const { db, range, logger } = ctx;
  const [loans, repayments, rollovers] = await Promise.all([
    loadLoans(db, logger),
    loadRepayments(db, logger),
    loadRollovers(db, logger),
  ]);

  const endMs = new Date(`${range.end}T23:59:59.999Z`).getTime();

  // Eligible as at period end: 70% of original principal repaid, loan still open.
  const eligible = loans.filter((l) => {
    const createdAt = new Date(l.created_at).getTime();
    if (createdAt > endMs) return false;
    if (!OPEN_LOAN_STATUSES.includes(l.status)) return false;
    const principal = num(l.original_principal) || num(l.amount);
    if (principal <= 0) return false;
    const repaid = loanPositionAsAt(l, repayments, endMs, Date.now()).principalRepaidAtEnd;
    return (repaid / principal) * 100 >= ROLLOVER_MIN_PRINCIPAL_PCT;
  });

  const requested = rowsIn(rollovers, range);
  const approved = rowsIn(rollovers.filter((r) => r.status === 'approved'), range);
  const amountRolledOver = approved.reduce(
    (s, r) => s + (num(r.net_disbursed) || num(r.requested_amount)),
    0,
  );

  return {
    key: 'rollover',
    label: 'Rollover Performance',
    metrics: [
      { key: 'rollover_eligible', label: 'Members rollover-eligible (period end)', value: eligible.length, unit: 'number' },
      { key: 'rollover_requested', label: 'Rollover requests', value: requested.length, unit: 'number' },
      { key: 'rollover_approved', label: 'Rollovers approved', value: approved.length, unit: 'number' },
      { key: 'rollover_amount', label: 'Amount rolled over', value: amountRolledOver, unit: 'currency' },
      {
        key: 'rollover_utilization_rate',
        label: 'Rollover utilization rate',
        value: rate(requested.length, eligible.length),
        unit: 'percent',
      },
      {
        key: 'rollover_approval_rate',
        label: 'Rollover approval rate',
        value: rate(approved.length, requested.length),
        unit: 'percent',
      },
      {
        key: 'rollover_min_principal_pct',
        label: 'Eligibility threshold (% principal repaid)',
        value: ROLLOVER_MIN_PRINCIPAL_PCT,
        unit: 'percent',
        // Informational; comparing a constant across periods is meaningless.
        informational: true,
      },
    ],
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Section: Organizations (per-organization, so two can be compared)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Per-organization metrics for a period.
 *
 * Returns one entry per organization so the comparison engine can pair the
 * same organization across two periods (Bowen in Q1 vs Bowen in Q2) or the
 * caller can compare two different organizations in the same period.
 */
async function organizationMetrics(ctx) {
  const { db, range, logger } = ctx;
  const [orgs, profiles, transactions, loans, repayments] = await Promise.all([
    loadOrganizations(db, logger),
    loadProfiles(db, logger, 50000),
    loadTransactions(db, logger),
    loadLoans(db, logger),
    loadRepayments(db, logger),
  ]);

  const endMs = new Date(`${range.end}T23:59:59.999Z`).getTime();
  const profileOrg = new Map(profiles.map((p) => [p.id, p.organization_id]));
  const byId = new Map(orgs.map((o) => [o.id, o]));

  const acc = new Map();
  const bucket = (orgId) => {
    if (!acc.has(orgId)) {
      acc.set(orgId, {
        organizationId: orgId,
        organization: byId.get(orgId)?.name || 'Unknown',
        code: byId.get(orgId)?.code || '',
        members: 0,
        activeMembers: 0,
        newMembers: 0,
        contributions: 0,
        salaryDeductions: 0,
        activeLoans: 0,
        outstandingLoans: 0,
        overdueLoans: 0,
        repayments: 0,
        expectedMonthly: 0,
      });
    }
    return acc.get(orgId);
  };

  for (const p of profiles) {
    if (!p.organization_id) continue;
    const b = bucket(p.organization_id);
    if (new Date(p.created_at).getTime() <= endMs) b.members += 1;
    if (p.is_active && !p.is_flagged) b.activeMembers += 1;
    if (periods.inRange(p.created_at, range)) b.newMembers += 1;
    b.expectedMonthly += num(p.monthly_amount);
  }

  const contribTx = transactions.filter(
    (t) => CONTRIBUTION_TYPES.includes(t.type) && t.status !== 'failed' && t.status !== 'reversed',
  );
  for (const t of rowsIn(contribTx, range)) {
    const orgId = profileOrg.get(t.profile_id);
    if (!orgId) continue;
    const b = bucket(orgId);
    b.contributions += num(t.amount);
    if (t.contribution_source === 'salary_deduction') b.salaryDeductions += num(t.amount);
  }

  for (const l of loans) {
    const orgId = profileOrg.get(l.profile_id);
    if (!orgId) continue;
    const pos = loanPositionAsAt(l, repayments, endMs, Date.now());
    if (!pos.existed) continue;
    const b = bucket(orgId);
    if (OPEN_LOAN_STATUSES.includes(l.status)) {
      b.activeLoans += 1;
      b.outstandingLoans += pos.balanceAtEnd;
    }
    if (l.next_due_date && new Date(l.next_due_date).getTime() < endMs && pos.balanceAtEnd > 0) {
      b.overdueLoans += 1;
    }
  }

  for (const r of rowsIn(repayments, range, 'paid_at')) {
    const orgId = profileOrg.get(r.profile_id);
    if (!orgId) continue;
    bucket(orgId).repayments += num(r.amount);
  }

  const rows = [...acc.values()]
    .map((b) => ({
      ...b,
      outstandingLoans: Math.round(b.outstandingLoans * 100) / 100,
      repaymentRate: rate(b.repayments, b.repayments + b.outstandingLoans),
    }))
    .sort((a, b) => b.contributions - a.contributions);

  return { key: 'organizations', label: 'Organization Comparison', rows, metrics: [] };
}

// ═══════════════════════════════════════════════════════════════════════════
// Registry
// ═══════════════════════════════════════════════════════════════════════════

const SECTIONS = {
  membership: {
    key: 'membership',
    label: 'Membership',
    description: 'Members joining, active and inactive counts.',
    run: membershipMetrics,
  },
  savings: {
    key: 'savings',
    label: 'Savings & Contributions',
    description: 'Contributions by source, fees, levies and withdrawals.',
    run: savingsMetrics,
  },
  loans: {
    key: 'loans',
    label: 'Loan Performance',
    description: 'Applications, approvals, disbursements, repayments and defaults.',
    run: loanMetrics,
  },
  rollover: {
    key: 'rollover',
    label: 'Rollover Performance',
    description: 'Rollover eligibility, uptake and approvals.',
    run: rolloverMetrics,
  },
  organizations: {
    key: 'organizations',
    label: 'Organization Comparison',
    description: 'Per-organization members, collections and loan book.',
    run: organizationMetrics,
  },
};

const DEFAULT_SECTIONS = ['membership', 'savings', 'loans', 'rollover'];

function listSections() {
  return Object.values(SECTIONS).map((s) => ({
    key: s.key,
    label: s.label,
    description: s.description,
  }));
}

/** Run the requested sections (or the defaults) for one period. */
async function runSections(sectionKeys, ctx) {
  const keys = (Array.isArray(sectionKeys) && sectionKeys.length
    ? sectionKeys
    : DEFAULT_SECTIONS
  ).filter((k) => SECTIONS[k]);

  if (keys.length === 0) {
    const err = new Error(`No valid sections. Use one of: ${Object.keys(SECTIONS).join(', ')}`);
    err.status = 400;
    throw err;
  }

  const out = {};
  for (const key of keys) {
    out[key] = await SECTIONS[key].run(ctx);
  }
  return out;
}

module.exports = {
  SECTIONS,
  DEFAULT_SECTIONS,
  listSections,
  runSections,
  // exported for tests
  CONTRIBUTION_TYPES,
  OPEN_LOAN_STATUSES,
  ROLLOVER_MIN_PRINCIPAL_PCT,
  incomeCategoryOf,
  loanPositionAsAt,
  rate,
  sumIn,
  countIn,
  rowsIn,
  loadLoans,
  loadRepayments,
  loadRollovers,
  loadTransactions,
  loadProfiles,
  loadOrganizations,
  loadFees,
  loadContributions,
};
