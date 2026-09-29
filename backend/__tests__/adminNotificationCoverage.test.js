const fs = require('fs');
const path = require('path');

/**
 * Members expect the admin dashboard to be told about anything they do that a
 * human must act on. The failed-charge, loan, KYC, ticket, rollover, deposit,
 * withdrawal and contact paths already alert admins; termination, investment
 * participation, savings withdrawal, manual payment proof and document upload
 * did not — those events waited in a queue that no one was watching.
 *
 * This pins the wiring at the source level so a future refactor cannot silently
 * drop an admin alert from one of these handlers without a failing test.
 */
const ROOT = path.join(__dirname, '..', 'src');

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), 'utf8');
}

const WIRED = [
  ['routes/termination.js', 'Membership Termination Requested'],
  ['routes/investments.js', 'New Investment Participation'],
  ['routes/savings.js', 'Savings Withdrawal'],
  ['routes/paymentProofs.js', 'Payment Proof Awaiting Verification'],
  ['routes/documents.js', 'New Document Uploaded'],
];

describe('admin notification coverage for actionable member events', () => {
  test.each(WIRED)('%s alerts admins (%s)', (rel, title) => {
    const src = read(rel);
    expect(src).toContain('notifyService');
    expect(src).toContain('notifyAdmins');
    expect(src).toContain(title);
    // Fire-and-forget: the alert must not be awaited, so a notification
    // failure can never fail the member's request.
    expect(src).not.toMatch(/await\s+notifyService\.notifyAdmins\(/);
  });

  test('every admin alert is non-fatal (has a .catch)', () => {
    for (const [rel] of WIRED) {
      const src = read(rel);
      const calls = src.split('notifyAdmins(').length - 1;
      expect(calls).toBeGreaterThan(0);
      expect(src).toContain('.catch(');
    }
  });

  test('each wired event type maps inside the DB CHECK constraint', () => {
    const { normalizeNotifType } = require('../src/services/notifyService');
    const dbTypes = new Set([
      'transaction', 'savings', 'investment', 'loan', 'referral',
      'kyc', 'system', 'promotion', 'security', 'reminder',
      'payment_proof_approved',
    ]);
    for (const t of ['termination', 'investment', 'savings', 'payment_proof', 'kyc']) {
      expect(dbTypes.has(normalizeNotifType(t))).toBe(true);
    }
  });
});
