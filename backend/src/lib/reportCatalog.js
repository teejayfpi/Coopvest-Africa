/**
 * Report catalog for the admin reporting suite.
 *
 * Each entry declares its columns and how to fetch its rows. The runner in
 * reportEngine.js turns that into the `{ columns, rows, summary }` shape shared
 * by the JSON, CSV and XLSX outputs, so a report is defined exactly once.
 *
 * Design notes:
 *   - Filters are applied server-side where a real indexed column exists, and
 *     re-checked in JS so derived reports (which aggregate across several
 *     tables) filter on the same definition of "in range".
 *   - Money columns are declared `type: 'currency'` so the XLSX writer emits
 *     real numeric cells and the totals are usable on open.
 *   - Optional tables (withdrawal_requests, loan_repayments) are read through
 *     `safeRows`, which tolerates a missing table instead of failing the whole
 *     report.
 */

const logger = require('../utils/logger');
const loanPolicy = require('./loanPolicy');

// Mirrors CONTRIBUTION_TYPES in adminApi.js / the mobile contribution flow.
const CONTRIBUTION_TYPES = ['deposit', 'savings_deposit', 'transfer_in'];

// Loan statuses that mean the member is behind, borrowed from the dashboard
// summary definition so the Default report and the dashboard agree.
const DEFAULTED_LOAN_STATUSES = ['overdue', 'defaulted', 'in_recovery'];
const OPEN_LOAN_STATUSES = ['approved', 'disbursed', 'active', 'repaying'];

// ── shared helpers ───────────────────────────────────────────────────────────

/** Read rows, tolerating a missing table (42P01) or any query error. */
async function safeRows(promise, label) {
  try {
    const { data, error } = await promise;
    if (error) {
      logger.warn(`report: ${label} query failed: ${error.message}`);
      return [];
    }
    return data || [];
  } catch (err) {
    logger.warn(`report: ${label} threw: ${err.message}`);
    return [];
  }
}

function dayStart(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  d.setUTCHours(0, 0, 0, 0);
  return d.getTime();
}

function dayEnd(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  d.setUTCHours(23, 59, 59, 999);
  return d.getTime();
}

/** Inclusive [from, to] range test used by derived reports. */
function inDateRange(iso, from, to) {
  if (!iso) return false;
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return false;
  const lo = dayStart(from);
  const hi = dayEnd(to);
  if (lo !== null && t < lo) return false;
  if (hi !== null && t > hi) return false;
  return true;
}

/** 'YYYY-MM' key for a timestamp, used for monthly grouping. */
function monthKey(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

/** 'YYYY-MM-DD' key for a timestamp, used for daily grouping. */
function dayKey(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

function num(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function memberName(profile) {
  if (!profile) return '';
  return profile.name || profile.full_name || profile.email || '';
}

/** Load { id -> profile } for a set of profile ids, chunked. */
async function loadProfileMap(db, ids) {
  const unique = [...new Set((ids || []).filter(Boolean))];
  const map = new Map();
  const CHUNK = 200;
  for (let i = 0; i < unique.length; i += CHUNK) {
    const rows = await safeRows(
      db
        .from('profiles')
        .select('id, user_id, name, full_name, email, organization_id, membership_status, is_active')
        .in('id', unique.slice(i, i + CHUNK)),
      'profiles',
    );
    for (const p of rows) map.set(p.id, p);
  }
  return map;
}

/** Load { id -> organization } for a set of organization ids. */
async function loadOrgMap(db, ids) {
  const unique = [...new Set((ids || []).filter(Boolean))];
  const map = new Map();
  if (unique.length === 0) return map;
  const CHUNK = 200;
  for (let i = 0; i < unique.length; i += CHUNK) {
    const rows = await safeRows(
      db.from('organizations').select('id, name, code').in('id', unique.slice(i, i + CHUNK)),
      'organizations',
    );
    for (const o of rows) map.set(o.id, o);
  }
  return map;
}

/** Resolve an organisation display name for a profile. */
function orgNameFor(profile, orgMap) {
  if (!profile?.organization_id) return '';
  return orgMap.get(profile.organization_id)?.name || '';
}

// ── report definitions ───────────────────────────────────────────────────────

/**
 * Row-level reports all accept the same filters. `ctx` gives a report its
 * dependencies so the runner can inject a test double.
 */
const REPORTS = {
  // ── Financial ──────────────────────────────────────────────────────────────

  daily_transactions: {
    id: 'daily_transactions',
    name: 'Daily Transactions',
    category: 'Financial',
    description: 'Every money movement, grouped by day.',
    supportsDateRange: true,
    groupableBy: ['day'],
    columns: [
      { key: 'date', label: 'Date', type: 'date' },
      { key: 'transactionCount', label: 'Transactions', type: 'number' },
      { key: 'credits', label: 'Credits (₦)', type: 'currency' },
      { key: 'debits', label: 'Debits (₦)', type: 'currency' },
      { key: 'net', label: 'Net (₦)', type: 'currency' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      const rows = await safeRows(
        db
          .from('transactions')
          .select('id, created_at, completed_at, type, category, amount, status')
          .gte('created_at', filters.dateFrom || '1970-01-01')
          .lte('created_at', `${filters.dateTo || '2999-12-31'}T23:59:59.999Z`)
          .limit(20000),
        'transactions',
      );

      const buckets = new Map();
      for (const t of rows) {
        const when = t.completed_at || t.created_at;
        const key = dayKey(when);
        if (!key) continue;
        if (!buckets.has(key)) {
          buckets.set(key, { date: key, transactionCount: 0, credits: 0, debits: 0, net: 0 });
        }
        const b = buckets.get(key);
        const amount = num(t.amount);
        const isCredit = t.category === 'credit' || ['deposit', 'savings_deposit', 'transfer_in'].includes(t.type);
        b.transactionCount += 1;
        if (isCredit) b.credits += amount;
        else b.debits += amount;
        b.net = b.credits - b.debits;
      }
      return { rows: [...buckets.values()].sort((a, b) => (a.date < b.date ? 1 : -1)) };
    },
  },

  monthly_transactions: {
    id: 'monthly_transactions',
    name: 'Monthly Transactions',
    category: 'Financial',
    description: 'Every money movement, grouped by month.',
    supportsDateRange: true,
    groupableBy: ['month'],
    columns: [
      { key: 'month', label: 'Month', type: 'text' },
      { key: 'transactionCount', label: 'Transactions', type: 'number' },
      { key: 'credits', label: 'Credits (₦)', type: 'currency' },
      { key: 'debits', label: 'Debits (₦)', type: 'currency' },
      { key: 'net', label: 'Net (₦)', type: 'currency' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      const rows = await safeRows(
        db
          .from('transactions')
          .select('id, created_at, completed_at, type, category, amount')
          .gte('created_at', filters.dateFrom || '1970-01-01')
          .lte('created_at', `${filters.dateTo || '2999-12-31'}T23:59:59.999Z`)
          .limit(20000),
        'transactions',
      );

      const buckets = new Map();
      for (const t of rows) {
        const key = monthKey(t.completed_at || t.created_at);
        if (!key) continue;
        if (!buckets.has(key)) {
          buckets.set(key, { month: key, transactionCount: 0, credits: 0, debits: 0, net: 0 });
        }
        const b = buckets.get(key);
        const amount = num(t.amount);
        const isCredit = t.category === 'credit' || ['deposit', 'savings_deposit', 'transfer_in'].includes(t.type);
        b.transactionCount += 1;
        if (isCredit) b.credits += amount;
        else b.debits += amount;
        b.net = b.credits - b.debits;
      }
      return { rows: [...buckets.values()].sort((a, b) => (a.month < b.month ? 1 : -1)) };
    },
  },

  savings_report: {
    id: 'savings_report',
    name: 'Savings Report',
    category: 'Financial',
    description: 'Per-member savings position and contribution consistency.',
    supportsDateRange: false,
    supportsOrganization: true,
    columns: [
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'totalSaved', label: 'Total Saved (₦)', type: 'currency' },
      { key: 'monthlySavings', label: 'Monthly Savings (₦)', type: 'currency' },
      { key: 'balance', label: 'Balance (₦)', type: 'currency' },
      { key: 'consecutiveMonths', label: 'Consecutive Months', type: 'number' },
      { key: 'lastSavingsDate', label: 'Last Savings', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('savings')
        .select('id, profile_id, total_saved, monthly_savings, balance, consecutive_months, last_savings_date')
        .order('last_savings_date', { ascending: false })
        .limit(20000);
      if (filters.memberId) query = query.eq('profile_id', filters.memberId);
      const rows = await safeRows(query, 'savings');

      const profileMap = await loadProfileMap(db, rows.map((r) => r.profile_id));
      const orgMap = await loadOrgMap(
        db,
        [...profileMap.values()].map((p) => p.organization_id),
      );

      let out = rows.map((r) => {
        const profile = profileMap.get(r.profile_id);
        return {
          memberId: profile?.user_id || '',
          memberName: memberName(profile),
          organization: orgNameFor(profile, orgMap),
          _orgId: profile?.organization_id || null,
          totalSaved: num(r.total_saved),
          monthlySavings: num(r.monthly_savings),
          balance: num(r.balance),
          consecutiveMonths: num(r.consecutive_months),
          lastSavingsDate: r.last_savings_date || '',
        };
      });
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  loan_report: {
    id: 'loan_report',
    name: 'Loan Report',
    category: 'Financial',
    description: 'All loan applications with terms, balances and status.',
    supportsDateRange: true,
    supportsOrganization: true,
    columns: [
      { key: 'loanId', label: 'Loan ID', type: 'text' },
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'loanType', label: 'Product', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'totalRepayment', label: 'Total Repayment (₦)', type: 'currency' },
      { key: 'remainingBalance', label: 'Outstanding (₦)', type: 'currency' },
      { key: 'monthlyRepayment', label: 'Monthly (₦)', type: 'currency' },
      { key: 'status', label: 'Status', type: 'text' },
      { key: 'nextDueDate', label: 'Next Due', type: 'date' },
      { key: 'createdAt', label: 'Applied', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('loans')
        .select('id, loan_id, profile_id, loan_type, amount, total_repayment, remaining_balance, monthly_repayment, status, next_due_date, created_at')
        .order('created_at', { ascending: false })
        .limit(20000);
      if (filters.status) query = query.eq('status', filters.status);
      if (filters.memberId) query = query.eq('profile_id', filters.memberId);
      if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
      if (filters.dateTo) query = query.lte('created_at', `${filters.dateTo}T23:59:59.999Z`);
      const rows = await safeRows(query, 'loans');

      const profileMap = await loadProfileMap(db, rows.map((r) => r.profile_id));
      const orgMap = await loadOrgMap(
        db,
        [...profileMap.values()].map((p) => p.organization_id),
      );

      let out = rows.map((r) => {
        const profile = profileMap.get(r.profile_id);
        return {
          loanId: r.loan_id || r.id,
          memberId: profile?.user_id || '',
          memberName: memberName(profile),
          organization: orgNameFor(profile, orgMap),
          _orgId: profile?.organization_id || null,
          loanType: r.loan_type || '',
          amount: num(r.amount),
          totalRepayment: num(r.total_repayment),
          remainingBalance: num(r.remaining_balance ?? r.outstanding_balance),
          monthlyRepayment: num(r.monthly_repayment),
          status: r.status || '',
          nextDueDate: r.next_due_date || '',
          createdAt: r.created_at || '',
        };
      });
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  repayment_report: {
    id: 'repayment_report',
    name: 'Repayment Report',
    category: 'Financial',
    description: 'Loan repayments received, with the loan and member they settled.',
    supportsDateRange: true,
    columns: [
      { key: 'paidAt', label: 'Paid', type: 'date' },
      { key: 'loanId', label: 'Loan ID', type: 'text' },
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'status', label: 'Status', type: 'text' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('loan_repayments')
        .select('id, loan_id, profile_id, amount, paid_at, status, created_at')
        .order('paid_at', { ascending: false, nullsFirst: false })
        .limit(20000);
      if (filters.dateFrom) query = query.gte('paid_at', filters.dateFrom);
      if (filters.dateTo) query = query.lte('paid_at', `${filters.dateTo}T23:59:59.999Z`);
      const rows = await safeRows(query, 'loan_repayments');

      const profileMap = await loadProfileMap(db, rows.map((r) => r.profile_id));
      const loanIds = [...new Set(rows.map((r) => r.loan_id).filter(Boolean))];
      const loanMap = new Map();
      if (loanIds.length) {
        const loans = await safeRows(
          db.from('loans').select('id, loan_id').in('id', loanIds.slice(0, 500)),
          'loans',
        );
        for (const l of loans) loanMap.set(l.id, l.loan_id || l.id);
      }

      return {
        rows: rows.map((r) => {
          const profile = profileMap.get(r.profile_id);
          return {
            paidAt: r.paid_at || r.created_at || '',
            loanId: loanMap.get(r.loan_id) || r.loan_id || '',
            memberId: profile?.user_id || '',
            memberName: memberName(profile),
            amount: num(r.amount),
            status: r.status || '',
          };
        }),
      };
    },
  },

  default_report: {
    id: 'default_report',
    name: 'Default Report',
    category: 'Financial',
    description: 'Loans past their due date, with days overdue and exposure.',
    supportsDateRange: false,
    supportsOrganization: true,
    columns: [
      { key: 'loanId', label: 'Loan ID', type: 'text' },
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'outstanding', label: 'Outstanding (₦)', type: 'currency' },
      { key: 'nextDueDate', label: 'Due Date', type: 'date' },
      { key: 'daysOverdue', label: 'Days Overdue', type: 'number' },
      { key: 'status', label: 'Status', type: 'text' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      const rows = await safeRows(
        db
          .from('loans')
          .select('id, loan_id, profile_id, amount, remaining_balance, outstanding_balance, principal_repaid, status, next_due_date')
          .in('status', ['active', 'disbursed', 'repaying', 'overdue', 'defaulted', 'in_recovery'])
          .limit(20000),
        'loans',
      );

      const now = Date.now();
      const overdue = rows.filter((l) => {
        if (!l.next_due_date) return false;
        const due = new Date(l.next_due_date).getTime();
        return Number.isFinite(due) && due < now;
      });

      const profileMap = await loadProfileMap(db, overdue.map((r) => r.profile_id));
      const orgMap = await loadOrgMap(
        db,
        [...profileMap.values()].map((p) => p.organization_id),
      );

      let out = overdue
        .map((l) => {
          const profile = profileMap.get(l.profile_id);
          const due = new Date(l.next_due_date).getTime();
          const outstanding = num(l.remaining_balance ?? l.outstanding_balance) ||
            Math.max(0, num(l.amount) - num(l.principal_repaid));
          return {
            loanId: l.loan_id || l.id,
            memberId: profile?.user_id || '',
            memberName: memberName(profile),
            organization: orgNameFor(profile, orgMap),
            _orgId: profile?.organization_id || null,
            outstanding,
            nextDueDate: l.next_due_date || '',
            daysOverdue: Math.max(0, Math.floor((now - due) / 86400000)),
            status: l.status || '',
          };
        })
        .sort((a, b) => b.daysOverdue - a.daysOverdue);
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  salary_deduction_report: {
    id: 'salary_deduction_report',
    name: 'Salary Deduction Report',
    category: 'Financial',
    description: 'Contributions collected via employer payroll deduction, per period and organization.',
    supportsDateRange: true,
    groupableBy: ['contribution_month'],
    columns: [
      { key: 'period', label: 'Period', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'members', label: 'Members', type: 'number' },
      { key: 'amount', label: 'Deducted (₦)', type: 'currency' },
      { key: 'registrationFees', label: 'Registration Fees (₦)', type: 'currency' },
      { key: 'total', label: 'Total (₦)', type: 'currency' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('transactions')
        .select('id, profile_id, amount, contribution_source, contribution_month, created_at, status')
        .eq('contribution_source', 'salary_deduction')
        .limit(20000);
      if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
      if (filters.dateTo) query = query.lte('created_at', `${filters.dateTo}T23:59:59.999Z`);
      const rows = await safeRows(query, 'salary_deduction transactions');

      const profileMap = await loadProfileMap(db, rows.map((r) => r.profile_id));
      const orgMap = await loadOrgMap(
        db,
        [...profileMap.values()].map((p) => p.organization_id),
      );

      // One row per period+organisation, which is how remittances are reconciled.
      const buckets = new Map();
      for (const t of rows) {
        const profile = profileMap.get(t.profile_id);
        const org = orgNameFor(profile, orgMap) || 'Unassigned';
        const period = t.contribution_month || monthKey(t.created_at) || 'Unknown';
        const key = `${period}|${org}`;
        if (!buckets.has(key)) {
          buckets.set(key, {
            period, organization: org, _members: new Set(),
            amount: 0, registrationFees: 0, total: 0, _orgId: profile?.organization_id || null,
          });
        }
        const b = buckets.get(key);
        b._members.add(t.profile_id);
        b.amount += num(t.amount);
        b.total = b.amount + b.registrationFees;
      }

      let out = [...buckets.values()].map((b) => ({
        ...b, members: b._members.size, _members: undefined,
      }));
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      out.sort((a, b) => (a.period < b.period ? 1 : -1));
      return { rows: out, strip: ['_orgId'] };
    },
  },

  fee_levy_report: {
    id: 'fee_levy_report',
    name: 'Fee & Levy Report',
    category: 'Financial',
    description: 'Fees and levies assigned to members, and how much has been settled.',
    supportsDateRange: true,
    supportsOrganization: true,
    columns: [
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'feeType', label: 'Type', type: 'text' },
      { key: 'label', label: 'Description', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'status', label: 'Status', type: 'text' },
      { key: 'paidAt', label: 'Paid', type: 'date' },
      { key: 'createdAt', label: 'Assigned', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('member_fees')
        .select('id, profile_id, fee_type, label, amount, status, paid_at, created_at')
        .order('created_at', { ascending: false })
        .limit(20000);
      if (filters.status) query = query.eq('status', filters.status);
      if (filters.memberId) query = query.eq('profile_id', filters.memberId);
      if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
      if (filters.dateTo) query = query.lte('created_at', `${filters.dateTo}T23:59:59.999Z`);
      const rows = await safeRows(query, 'member_fees');

      const profileMap = await loadProfileMap(db, rows.map((r) => r.profile_id));
      const orgMap = await loadOrgMap(
        db,
        [...profileMap.values()].map((p) => p.organization_id),
      );

      let out = rows.map((r) => {
        const profile = profileMap.get(r.profile_id);
        return {
          memberId: profile?.user_id || '',
          memberName: memberName(profile),
          organization: orgNameFor(profile, orgMap),
          _orgId: profile?.organization_id || null,
          feeType: r.fee_type || '',
          label: r.label || '',
          amount: num(r.amount),
          status: r.status || '',
          paidAt: r.paid_at || '',
          createdAt: r.created_at || '',
        };
      });
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  withdrawal_report: {
    id: 'withdrawal_report',
    name: 'Withdrawal Report',
    category: 'Financial',
    description: 'Member withdrawal requests and their processing status.',
    supportsDateRange: true,
    columns: [
      { key: 'requestedAt', label: 'Requested', type: 'date' },
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'bankName', label: 'Bank', type: 'text' },
      { key: 'accountNumber', label: 'Account', type: 'text' },
      { key: 'status', label: 'Status', type: 'text' },
      { key: 'processedAt', label: 'Processed', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('withdrawal_requests')
        .select('id, profile_id, amount, bank_name, account_number, status, created_at, processed_at')
        .order('created_at', { ascending: false })
        .limit(20000);
      if (filters.status) query = query.eq('status', filters.status);
      if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
      if (filters.dateTo) query = query.lte('created_at', `${filters.dateTo}T23:59:59.999Z`);
      const rows = await safeRows(query, 'withdrawal_requests');

      const profileMap = await loadProfileMap(db, rows.map((r) => r.profile_id));
      return {
        rows: rows.map((r) => {
          const profile = profileMap.get(r.profile_id);
          return {
            requestedAt: r.created_at || '',
            memberId: profile?.user_id || '',
            memberName: memberName(profile),
            amount: num(r.amount),
            bankName: r.bank_name || '',
            accountNumber: r.account_number || '',
            status: r.status || '',
            processedAt: r.processed_at || '',
          };
        }),
      };
    },
  },

  investment_report: {
    id: 'investment_report',
    name: 'Investment Report',
    category: 'Financial',
    description: 'Member participation in investment pools, by pool.',
    supportsDateRange: true,
    columns: [
      { key: 'poolName', label: 'Pool', type: 'text' },
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'amount', label: 'Amount (₦)', type: 'currency' },
      { key: 'expectedReturnPct', label: 'Expected Return (%)', type: 'number' },
      { key: 'status', label: 'Status', type: 'text' },
      { key: 'createdAt', label: 'Invested', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('investment_participations')
        .select('id, pool_id, profile_id, amount, status, created_at')
        .order('created_at', { ascending: false })
        .limit(20000);
      if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
      if (filters.dateTo) query = query.lte('created_at', `${filters.dateTo}T23:59:59.999Z`);
      const rows = await safeRows(query, 'investment_participations');

      const profileMap = await loadProfileMap(db, rows.map((r) => r.profile_id));
      const poolIds = [...new Set(rows.map((r) => r.pool_id).filter(Boolean))];
      const poolMap = new Map();
      if (poolIds.length) {
        const pools = await safeRows(
          db.from('investment_pools').select('id, name, expected_return_pct').in('id', poolIds.slice(0, 500)),
          'investment_pools',
        );
        for (const p of pools) poolMap.set(p.id, p);
      }

      return {
        rows: rows.map((r) => {
          const profile = profileMap.get(r.profile_id);
          const pool = poolMap.get(r.pool_id);
          return {
            poolName: pool?.name || '',
            memberId: profile?.user_id || '',
            memberName: memberName(profile),
            amount: num(r.amount),
            expectedReturnPct: num(pool?.expected_return_pct),
            status: r.status || '',
            createdAt: r.created_at || '',
          };
        }),
      };
    },
  },

  // ── Member ─────────────────────────────────────────────────────────────────

  new_members: {
    id: 'new_members',
    name: 'New Members',
    category: 'Member',
    description: 'Members who joined in the selected period.',
    supportsDateRange: true,
    supportsOrganization: true,
    columns: [
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'email', label: 'Email', type: 'text' },
      { key: 'phone', label: 'Phone', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'status', label: 'Membership Status', type: 'text' },
      { key: 'kycVerified', label: 'KYC Verified', type: 'text' },
      { key: 'createdAt', label: 'Joined', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      let query = db
        .from('profiles')
        .select('id, user_id, name, full_name, email, phone, organization_id, membership_status, is_active, kyc_verified, created_at')
        .order('created_at', { ascending: false })
        .limit(20000);
      if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
      if (filters.dateTo) query = query.lte('created_at', `${filters.dateTo}T23:59:59.999Z`);
      const rows = await safeRows(query, 'profiles');
      const orgMap = await loadOrgMap(db, rows.map((p) => p.organization_id));

      let out = rows.map((p) => ({
        memberId: p.user_id || '',
        memberName: memberName(p),
        email: p.email || '',
        phone: p.phone || '',
        organization: orgNameFor(p, orgMap),
        _orgId: p.organization_id || null,
        status: p.membership_status || (p.is_active ? 'active' : 'inactive'),
        kycVerified: p.kyc_verified ? 'Yes' : 'No',
        createdAt: p.created_at || '',
      }));
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  active_members: {
    id: 'active_members',
    name: 'Active Members',
    category: 'Member',
    description: 'Members currently active on the platform.',
    supportsDateRange: false,
    supportsOrganization: true,
    columns: [
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'email', label: 'Email', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'kycVerified', label: 'KYC Verified', type: 'text' },
      { key: 'registrationFeePaid', label: 'Reg. Fee Paid', type: 'text' },
      { key: 'createdAt', label: 'Joined', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      const rows = await safeRows(
        db
          .from('profiles')
          .select('id, user_id, name, full_name, email, organization_id, kyc_verified, registration_fee_paid, created_at')
          .eq('is_active', true)
          .eq('is_flagged', false)
          .order('created_at', { ascending: false })
          .limit(20000),
        'profiles',
      );
      const orgMap = await loadOrgMap(db, rows.map((p) => p.organization_id));

      let out = rows.map((p) => ({
        memberId: p.user_id || '',
        memberName: memberName(p),
        email: p.email || '',
        organization: orgNameFor(p, orgMap),
        _orgId: p.organization_id || null,
        kycVerified: p.kyc_verified ? 'Yes' : 'No',
        registrationFeePaid: p.registration_fee_paid ? 'Yes' : 'No',
        createdAt: p.created_at || '',
      }));
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  inactive_members: {
    id: 'inactive_members',
    name: 'Inactive Members',
    category: 'Member',
    description: 'Members deactivated or flagged, with the reason.',
    supportsDateRange: false,
    supportsOrganization: true,
    columns: [
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'email', label: 'Email', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'reason', label: 'Reason', type: 'text' },
      { key: 'createdAt', label: 'Joined', type: 'date' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      const rows = await safeRows(
        db
          .from('profiles')
          .select('id, user_id, name, full_name, email, organization_id, is_active, is_flagged, flagged_reason, flag_reason, membership_status, created_at')
          .or('is_active.eq.false,is_flagged.eq.true')
          .order('created_at', { ascending: false })
          .limit(20000),
        'profiles',
      );
      const orgMap = await loadOrgMap(db, rows.map((p) => p.organization_id));

      let out = rows.map((p) => ({
        memberId: p.user_id || '',
        memberName: memberName(p),
        email: p.email || '',
        organization: orgNameFor(p, orgMap),
        _orgId: p.organization_id || null,
        reason: p.flagged_reason || p.flag_reason || (p.is_active === false ? 'Deactivated' : 'Flagged'),
        createdAt: p.created_at || '',
      }));
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  organization_breakdown: {
    id: 'organization_breakdown',
    name: 'Organization Breakdown',
    category: 'Member',
    description: 'Members, collections and outstanding remittance per organization.',
    supportsDateRange: false,
    columns: [
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'code', label: 'Code', type: 'text' },
      { key: 'deductionType', label: 'Deduction Type', type: 'text' },
      { key: 'members', label: 'Members', type: 'number' },
      { key: 'expectedMonthly', label: 'Expected Monthly (₦)', type: 'currency' },
      { key: 'remitted', label: 'Remitted (₦)', type: 'currency' },
      { key: 'outstanding', label: 'Outstanding (₦)', type: 'currency' },
    ],
    async fetch(ctx) {
      const { db } = ctx;
      const orgs = await safeRows(
        db
          .from('organizations')
          .select('id, name, code, deduction_type, member_count, is_active')
          .order('name', { ascending: true })
          .limit(5000),
        'organizations',
      );
      const profiles = await safeRows(
        db
          .from('profiles')
          .select('id, organization_id, monthly_amount, is_active')
          .not('organization_id', 'is', null)
          .limit(20000),
        'profiles',
      );

      // Money actually received from each organisation via payroll deduction.
      const payrollTxns = await safeRows(
        db
          .from('transactions')
          .select('profile_id, amount, contribution_source')
          .eq('contribution_source', 'salary_deduction')
          .limit(20000),
        'salary_deduction transactions',
      );

      const membersByOrg = new Map();
      const expectedByOrg = new Map();
      const profileOrg = new Map();
      for (const p of profiles) {
        profileOrg.set(p.id, p.organization_id);
        membersByOrg.set(p.organization_id, (membersByOrg.get(p.organization_id) || 0) + 1);
        expectedByOrg.set(
          p.organization_id,
          (expectedByOrg.get(p.organization_id) || 0) + num(p.monthly_amount),
        );
      }
      const remittedByOrg = new Map();
      for (const t of payrollTxns) {
        const orgId = profileOrg.get(t.profile_id);
        if (!orgId) continue;
        remittedByOrg.set(orgId, (remittedByOrg.get(orgId) || 0) + num(t.amount));
      }

      return {
        rows: orgs.map((o) => {
          const expected = expectedByOrg.get(o.id) || 0;
          const remitted = remittedByOrg.get(o.id) || 0;
          return {
            organization: o.name || '',
            code: o.code || '',
            deductionType: o.deduction_type || '',
            members: membersByOrg.get(o.id) || num(o.member_count),
            expectedMonthly: expected,
            remitted,
            outstanding: Math.max(0, expected - remitted),
          };
        }),
      };
    },
  },

  contribution_performance: {
    id: 'contribution_performance',
    name: 'Contribution Performance',
    category: 'Member',
    description: 'Contribution collected per month against what was expected.',
    supportsDateRange: true,
    groupableBy: ['month'],
    columns: [
      { key: 'month', label: 'Month', type: 'text' },
      { key: 'contributors', label: 'Contributors', type: 'number' },
      { key: 'expected', label: 'Expected (₦)', type: 'currency' },
      { key: 'collected', label: 'Collected (₦)', type: 'currency' },
      { key: 'variance', label: 'Variance (₦)', type: 'currency' },
      { key: 'collectionRate', label: 'Collection Rate (%)', type: 'number' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      const contributions = await safeRows(
        db
          .from('contributions')
          .select('id, profile_id, amount, status, contribution_month, created_at')
          .limit(20000),
        'contributions',
      );

      // Expected = sum of each active member's declared monthly amount.
      const profiles = await safeRows(
        db.from('profiles').select('id, monthly_amount').eq('is_active', true).limit(20000),
        'profiles',
      );
      const expectedPerMonth = profiles.reduce((s, p) => s + num(p.monthly_amount), 0);

      const buckets = new Map();
      for (const c of contributions) {
        const when = c.created_at;
        if (filters.dateFrom || filters.dateTo) {
          if (!inDateRange(when, filters.dateFrom, filters.dateTo)) continue;
        }
        const key = c.contribution_month || monthKey(when);
        if (!key) continue;
        if (!buckets.has(key)) {
          buckets.set(key, { month: key, _members: new Set(), collected: 0 });
        }
        const b = buckets.get(key);
        b._members.add(c.profile_id);
        b.collected += num(c.amount);
      }

      const rows = [...buckets.values()].map((b) => {
        const expected = expectedPerMonth;
        return {
          month: b.month,
          contributors: b._members.size,
          expected,
          collected: b.collected,
          variance: b.collected - expected,
          collectionRate: expected > 0 ? Math.round((b.collected / expected) * 1000) / 10 : 0,
        };
      });
      rows.sort((a, b) => (a.month < b.month ? 1 : -1));
      return { rows };
    },
  },

  loan_eligibility: {
    id: 'loan_eligibility',
    name: 'Loan Eligibility',
    category: 'Member',
    description: 'What each member can borrow, based on savings and loan policy.',
    supportsDateRange: false,
    supportsOrganization: true,
    columns: [
      { key: 'memberId', label: 'Membership ID', type: 'text' },
      { key: 'memberName', label: 'Member', type: 'text' },
      { key: 'organization', label: 'Organization', type: 'text' },
      { key: 'totalSaved', label: 'Total Saved (₦)', type: 'currency' },
      { key: 'maxLoanAmount', label: 'Max Eligible (₦)', type: 'currency' },
      { key: 'multiplier', label: 'Multiplier', type: 'number' },
      { key: 'activeLoans', label: 'Active Loans', type: 'number' },
      { key: 'outstanding', label: 'Outstanding (₦)', type: 'currency' },
      { key: 'eligible', label: 'Eligible', type: 'text' },
      { key: 'blockReason', label: 'Blocked By', type: 'text' },
    ],
    async fetch(ctx) {
      const { db, filters } = ctx;
      const profiles = await safeRows(
        db
          .from('profiles')
          .select('id, user_id, name, full_name, email, organization_id, is_active')
          .eq('is_active', true)
          .limit(20000),
        'profiles',
      );
      const savings = await safeRows(db.from('savings').select('profile_id, total_saved').limit(20000), 'savings');
      const loans = await safeRows(
        db.from('loans').select('profile_id, status, remaining_balance').limit(20000),
        'loans',
      );

      const savingsMap = new Map(savings.map((s) => [s.profile_id, num(s.total_saved)]));
      const activeByProfile = new Map();
      const blockedByProfile = new Map();
      for (const l of loans) {
        if (OPEN_LOAN_STATUSES.includes(l.status)) {
          const entry = activeByProfile.get(l.profile_id) || { count: 0, outstanding: 0 };
          entry.count += 1;
          entry.outstanding += num(l.remaining_balance);
          activeByProfile.set(l.profile_id, entry);
        }
        if (loanPolicy.DEFAULT_BLOCKING_STATUSES.includes(l.status)) {
          blockedByProfile.set(l.profile_id, l.status);
        }
      }

      const orgMap = await loadOrgMap(db, profiles.map((p) => p.organization_id));
      const defaultMultiplier = loanPolicy.DEFAULT_MULTIPLIER;

      let out = profiles.map((p) => {
        const totalSaved = savingsMap.get(p.id) || 0;
        const active = activeByProfile.get(p.id) || { count: 0, outstanding: 0 };
        const blocked = blockedByProfile.get(p.id);
        return {
          memberId: p.user_id || '',
          memberName: memberName(p),
          organization: orgNameFor(p, orgMap),
          _orgId: p.organization_id || null,
          totalSaved,
          // Representative capacity — the real figure depends on the product
          // chosen at application time (3×–5×), so use the base multiplier.
          maxLoanAmount: loanPolicy.maxLoanAmount(null, totalSaved) || totalSaved * defaultMultiplier,
          multiplier: defaultMultiplier,
          activeLoans: active.count,
          outstanding: active.outstanding,
          eligible: blocked ? 'No' : 'Yes',
          blockReason: blocked || '',
        };
      });
      if (filters.organizationId) out = out.filter((r) => r._orgId === filters.organizationId);
      out.sort((a, b) => b.maxLoanAmount - a.maxLoanAmount);
      return { rows: out, strip: ['_orgId'] };
    },
  },

  default_statistics: {
    id: 'default_statistics',
    name: 'Default Statistics',
    category: 'Member',
    description: 'Default rates and exposure by loan product, with an aging breakdown.',
    supportsDateRange: false,
    columns: [
      { key: 'loanType', label: 'Product', type: 'text' },
      { key: 'totalLoans', label: 'Loans', type: 'number' },
      { key: 'defaultedLoans', label: 'Defaulted', type: 'number' },
      { key: 'defaultRate', label: 'Default Rate (%)', type: 'number' },
      { key: 'outstanding', label: 'Outstanding (₦)', type: 'currency' },
      { key: 'avgDaysOverdue', label: 'Avg Days Overdue', type: 'number' },
      { key: 'aging0to30', label: '0–30 days', type: 'number' },
      { key: 'aging31to90', label: '31–90 days', type: 'number' },
      { key: 'aging90plus', label: '90+ days', type: 'number' },
    ],
    async fetch(ctx) {
      const { db } = ctx;
      const loans = await safeRows(
        db
          .from('loans')
          .select('id, loan_type, status, amount, remaining_balance, outstanding_balance, next_due_date')
          .limit(20000),
        'loans',
      );

      const now = Date.now();
      const buckets = new Map();
      for (const l of loans) {
        const type = l.loan_type || 'Unspecified';
        if (!buckets.has(type)) {
          buckets.set(type, {
            loanType: type, totalLoans: 0, defaultedLoans: 0, outstanding: 0,
            _daysSum: 0, aging0to30: 0, aging31to90: 0, aging90plus: 0,
          });
        }
        const b = buckets.get(type);
        b.totalLoans += 1;

        const due = l.next_due_date ? new Date(l.next_due_date).getTime() : null;
        const isOverdue = due !== null && due < now &&
          !['completed', 'rejected', 'cancelled'].includes(l.status);
        if (!isOverdue) continue;

        const days = Math.floor((now - due) / 86400000);
        b.defaultedLoans += 1;
        b.outstanding += num(l.remaining_balance ?? l.outstanding_balance);
        b._daysSum += days;
        if (days <= 30) b.aging0to30 += 1;
        else if (days <= 90) b.aging31to90 += 1;
        else b.aging90plus += 1;
      }

      const rows = [...buckets.values()].map((b) => ({
        loanType: b.loanType,
        totalLoans: b.totalLoans,
        defaultedLoans: b.defaultedLoans,
        defaultRate: b.totalLoans > 0 ? Math.round((b.defaultedLoans / b.totalLoans) * 1000) / 10 : 0,
        outstanding: b.outstanding,
        avgDaysOverdue: b.defaultedLoans > 0 ? Math.round(b._daysSum / b.defaultedLoans) : 0,
        aging0to30: b.aging0to30,
        aging31to90: b.aging31to90,
        aging90plus: b.aging90plus,
      }));
      rows.sort((a, b) => b.defaultRate - a.defaultRate);
      return { rows };
    },
  },
};

/** Catalog metadata for the report picker UI. */
function listReports() {
  return Object.values(REPORTS).map((r) => ({
    id: r.id,
    name: r.name,
    category: r.category,
    description: r.description,
    supportsDateRange: Boolean(r.supportsDateRange),
    supportsOrganization: Boolean(r.supportsOrganization),
    groupableBy: r.groupableBy || [],
    columns: r.columns.map((c) => ({ key: c.key, label: c.label, type: c.type })),
  }));
}

module.exports = {
  REPORTS,
  listReports,
  // exported for tests and reuse
  CONTRIBUTION_TYPES,
  OPEN_LOAN_STATUSES,
  DEFAULTED_LOAN_STATUSES,
  inDateRange,
  monthKey,
  dayKey,
  loadProfileMap,
  loadOrgMap,
  safeRows,
};
