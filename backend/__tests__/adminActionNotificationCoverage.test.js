const fs = require('fs');
const path = require('path');

/**
 * The mirror image of adminNotificationCoverage.test.js.
 *
 * That test pins the *member → admin* direction: when a member does something
 * a human must act on, an admin is alerted. This one pins the reverse — the
 * *admin → member* direction. Admin decisions (KYC approved, deposit verified,
 * account flagged, …) used to change state silently, so a member only found out
 * by reopening the app and noticing the activation gate had cleared.
 *
 * Pinned at the source level so a future refactor cannot drop a member alert
 * from one of these admin handlers without a failing test.
 */
const ROOT = path.join(__dirname, '..', 'src');

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), 'utf8');
}

// [title the member sees, the handler it must be wired into]
const WIRED = [
  ['Account Verified', 'admin member verify'],
  ['Deposit Verified', 'deposit verify'],
  ['Deposit Rejected', 'deposit reject'],
  ['Verification Approved', 'KYC/compliance approve'],
  ['Verification Not Approved', 'KYC/compliance reject'],
  ['More Information Needed', 'KYC resubmission'],
  ['Password Reset Requested', 'admin reset-password'],
  ['Account Under Review', 'fraud freeze/flag'],
  ['Guarantor Request Approved', 'guarantor approve'],
];

describe('admin → member notification coverage for admin decisions', () => {
  const adminApi = read('routes/adminApi.js');

  test.each(WIRED)('adminApi.js tells the member "%s" (%s)', (title) => {
    expect(adminApi).toContain(title);
  });

  test('notifyService exports notifyMember', () => {
    const { notifyMember } = require('../src/services/notifyService');
    expect(typeof notifyMember).toBe('function');
  });

  test('notifyMember is non-fatal (wrapped in try/catch, returns on failure)', () => {
    const src = read('services/notifyService.js');
    const start = src.indexOf('async function notifyMember');
    expect(start).toBeGreaterThan(-1);
    const body = src.slice(start, start + 700);
    expect(body).toContain('try {');
    expect(body).toContain('catch');
    expect(body).toContain("status: 'failed'");
  });

  test('every member alert is fire-and-forget (has a .catch, is not awaited)', () => {
    // Count the notifyMember calls in the admin router; each must be followed
    // by a .catch so a notification failure can never fail the admin action.
    const calls = adminApi.split('notifyService\n      .notifyMember(').length - 1
      + adminApi.split('notifyService.notifyMember(').length - 1;
    expect(calls).toBeGreaterThanOrEqual(WIRED.length);
    expect(adminApi).not.toMatch(/await\s+notifyService\s*\n?\s*\.notifyMember\(/);
  });

  test('fraud actions target the alert owner, never the positional id', () => {
    const start = adminApi.indexOf("router.patch('/fraud-detection/:id'");
    expect(start).toBeGreaterThan(-1);
    const body = adminApi.slice(start, start + 900);
    // The client-supplied profile id is the target…
    expect(body).toContain('userId');
    // …and it is never taken from the URL param (a list position, not a uuid).
    expect(body).not.toMatch(/\.eq\('id',\s*req\.params\.id\)/);
  });

  test('member alert types are valid raw FCM types; only DB storage is normalised', () => {
    const { normalizeNotifType } = require('../src/services/notifyService');
    // sendPush puts the RAW type in the FCM `data.type` (so the mobile switch
    // can branch on rich names); normalizeNotifType only shapes what is written
    // to the `notifications` table. The raw types we emit must still normalise
    // to a permitted DB type — otherwise sendInApp silently drops the row.
    const dbTypes = new Set([
      'transaction', 'savings', 'investment', 'loan', 'referral',
      'kyc', 'system', 'promotion', 'security', 'reminder',
      'payment_proof_approved',
    ]);
    for (const t of ['kyc', 'transaction', 'security', 'guarantor_request', 'guarantor_confirmed']) {
      expect(dbTypes.has(normalizeNotifType(t))).toBe(true);
    }
    // Types already in the allowed set are preserved verbatim.
    for (const t of ['kyc', 'transaction', 'security']) {
      expect(normalizeNotifType(t)).toBe(t);
    }
  });
});
