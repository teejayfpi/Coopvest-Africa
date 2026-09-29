const {
  normalizeNotifType,
  normalizeNotifCategory,
} = require('../src/services/notifyService');

/**
 * The notifications.type column has a CHECK constraint. Writing a value outside
 * it throws 23514, and every caller treats a notify failure as non-fatal — so
 * an invalid type silently drops the admin alert. Deposit and withdrawal alerts
 * used `type: 'deposit'`/`'withdrawal'`, neither of which the constraint
 * allows, so those alerts never reached anyone.
 *
 * These tests pin the coercion that prevents a repeat: every type a caller
 * might pass must resolve to a value the DB accepts.
 */
const DB_ALLOWED_TYPES = [
  'transaction',
  'savings',
  'investment',
  'loan',
  'referral',
  'kyc',
  'system',
  'promotion',
  'security',
  'reminder',
];

describe('notification type coercion', () => {
  test('every allowed DB type passes through unchanged', () => {
    for (const t of DB_ALLOWED_TYPES) {
      expect(normalizeNotifType(t)).toBe(t);
    }
  });

  test("the values that used to break deposits and withdrawals are coerced", () => {
    // These are exactly what wallet.js passes; both must map onto the constraint.
    expect(DB_ALLOWED_TYPES).toContain(normalizeNotifType('deposit'));
    expect(DB_ALLOWED_TYPES).toContain(normalizeNotifType('withdrawal'));
    expect(normalizeNotifType('deposit')).toBe('transaction');
  });

  test('the historical sendInApp default is also coerced', () => {
    // sendInApp defaulted to 'announcement', which the constraint rejects too.
    expect(DB_ALLOWED_TYPES).toContain(normalizeNotifType('announcement'));
  });

  test.each([
    ['loan_application', 'loan'],
    ['rollover_request', 'loan'],
    ['wallet_credit', 'transaction'],
    ['payment_proof_submitted', 'transaction'],
    ['monthly_savings', 'savings'],
    ['kyc_submitted', 'kyc'],
    ['otp_sent', 'security'],
    ['contribution_reminder', 'reminder'],
    // Types added when wiring admin alerts for the remaining actionable member
    // events (termination, investments, savings withdrawals, payment proofs,
    // document uploads). Each must land inside the CHECK constraint or the
    // alert is silently dropped.
    ['termination', 'system'],
    ['investment', 'investment'],
    ['savings', 'savings'],
    ['payment_proof', 'transaction'],
  ])('%s → %s', (input, expected) => {
    expect(normalizeNotifType(input)).toBe(expected);
  });

  test('an unknown or missing type falls back to system', () => {
    expect(normalizeNotifType('something_new')).toBe('system');
    expect(normalizeNotifType(undefined)).toBe('system');
    expect(normalizeNotifType('')).toBe('system');
  });

  test('the rich payment_proof_approved type survives for the mobile listener', () => {
    expect(normalizeNotifType('payment_proof_approved')).toBe('payment_proof_approved');
  });
});

describe('notification category coercion', () => {
  test('the four UI severities pass through', () => {
    for (const c of ['info', 'warning', 'success', 'action_required']) {
      expect(normalizeNotifCategory(c, 'system')).toBe(c);
    }
  });

  test('a missing category is inferred from the event type', () => {
    expect(normalizeNotifCategory(undefined, 'payment_approved')).toBe('success');
    expect(normalizeNotifCategory(undefined, 'loan_rejected')).toBe('warning');
    expect(normalizeNotifCategory(undefined, 'kyc_required')).toBe('action_required');
  });

  test('an unknown category never reaches the DB unchecked', () => {
    // Anything not in the allowed set resolves to a valid value.
    expect(['info', 'warning', 'success', 'action_required']).toContain(
      normalizeNotifCategory('critical', 'system')
    );
  });
});
