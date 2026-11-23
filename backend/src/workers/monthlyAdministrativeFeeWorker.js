/**
 * Monthly administrative fee worker.
 *
 * The cooperative charges NGN1,500 a month (NGN1,000 administrative charges +
 * NGN500 development levy). That charge was published in the terms, shown in
 * the fee schedule, and read by `computeObligations` - but no code ever created
 * the `member_fees` row it is collected from. `computeObligations` only totals
 * rows that exist, so the fee never appeared in any member's "amount due"
 * unless an admin had assigned it by hand, one member at a time.
 *
 * This worker creates the obligation. It bills the current month only:
 * back-billing every month since a member joined would present a lump sum they
 * were never told they owed, which is a worse harm than the missed charge.
 *
 * Every member is billed, including salary-deduction members. The fee used to be
 * skipped for them on the premise that payroll recovers it, but no payroll path
 * can: `payroll_batch_lines` carries `contribution_amount` and
 * `registration_fee_amount` and nothing else, and `organizationFinance` totals
 * only those two. So the charge was neither billed in-app nor deducted from
 * salary - it was collected by nobody, for every enrolled org.
 *
 * Idempotent on `(profile_id, fee_type_id, billing_month)` via a partial unique
 * index, so a re-run or an overlapping tick cannot create a second charge.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');
const { ADMINISTRATIVE_FEE } = require('../config/feeDisclosure');
const { isStaffRole } = require('../lib/permissions');

const POLL_INTERVAL_MS = 24 * 60 * 60 * 1000; // daily
const STARTUP_DELAY_MS = 10 * 60 * 1000;
const FEE_NAME = 'Administrative Fee';

/** 'YYYY-MM' for a date, matching `wallet.monthKey` so the two agree. */
function billingMonth(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * Whether this member should be billed for `month`.
 *
 * Pure, so the rule is testable without a database. `created_at` is compared by
 * month rather than by instant: a member who joined in the current month is
 * billed, because the charge is for the month they are in.
 */
function shouldBill(profile, month) {
  if (!profile || !profile.id) return false;
  if (profile.is_active === false || profile.is_flagged === true) return false;
  // Staff and admin accounts are not members; the member charge does not apply.
  if (isStaffRole(profile.role)) return false;
  // Salary-deduction members are billed too - see the note at the top of this
  // file. Their employer cannot recover this charge, so the app must.
  if (profile.created_at) {
    const joined = billingMonth(new Date(profile.created_at));
    if (Number.isNaN(new Date(profile.created_at).getTime())) return false;
    if (joined > month) return false; // joined in a later month than being billed
  }
  return true;
}

/** Resolve the catalogue id, so the row links to the fee the member is shown. */
async function resolveFeeTypeId() {
  const { data } = await supabase
    .from('fee_types')
    .select('id, amount')
    .eq('name', FEE_NAME)
    .eq('category', 'fee')
    .maybeSingle();
  return data || null;
}

/**
 * Bill one member for one month. Returns the outcome as a short string so the
 * tick can tally what happened.
 */
async function billMember(profile, { feeType, month }) {
  if (!shouldBill(profile, month)) return 'skipped';

  const { error } = await supabase.from('member_fees').insert({
    profile_id: profile.id,
    fee_type_id: feeType.id,
    fee_type: 'fee',
    label: FEE_NAME,
    amount: ADMINISTRATIVE_FEE.total,
    status: 'outstanding',
    billing_month: month,
  });

  if (!error) return 'billed';

  // 23505 = unique violation: this member already has this month's charge.
  // That is the expected outcome on a second run, not a failure.
  if (error.code === '23505') return 'already_billed';
  logger.warn(`monthlyAdministrativeFeeWorker: insert failed for ${profile.id}:`, error.message);
  return 'failed';
}

/**
 * One pass. `now` is injectable so the month boundary is testable.
 */
async function processDue({ now = new Date() } = {}) {
  const month = billingMonth(now);
  try {
    const feeType = await resolveFeeTypeId();
    if (!feeType) {
      // The catalogue entry is created by migration 055. Its absence is a
      // configuration fault, not a per-member one - say so once and stop.
      logger.warn('monthlyAdministrativeFeeWorker: fee_types row "Administrative Fee" not found');
      return { month, billed: 0, error: 'fee type missing' };
    }

    const { data: members, error } = await supabase
      .from('profiles')
      .select('id, role, created_at, contribution_method, contribution_type, organization_id, pending_organization_name, pending_organization_requested_at, is_active, is_flagged');
    if (error) throw error;

    const tally = {};
    for (const member of members || []) {
      const outcome = await billMember(member, { feeType, month });
      tally[outcome] = (tally[outcome] || 0) + 1;
    }
    logger.info(`monthlyAdministrativeFeeWorker: ${month} ${JSON.stringify(tally)}`);
    return { month, checked: (members || []).length, tally };
  } catch (err) {
    logger.warn('monthlyAdministrativeFeeWorker: tick failed:', err.message);
    return { month, error: err.message };
  }
}

function start() {
  if (process.env.MONTHLY_ADMIN_FEE_DISABLED === '1') {
    logger.info('monthlyAdministrativeFeeWorker: disabled via env');
    return null;
  }
  logger.info('monthlyAdministrativeFeeWorker: started (poll every 24h)');
  const handle = setInterval(processDue, POLL_INTERVAL_MS);
  setTimeout(() => processDue().catch(() => {}), STARTUP_DELAY_MS);
  return handle;
}

module.exports = {
  start,
  processDue,
  billMember,
  shouldBill,
  billingMonth,
};
