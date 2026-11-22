/**
 * Pins the wiring, not just the helper.
 *
 * `guarantorDecisionNotifications.test.js` proves the notifier behaves
 * correctly; it would pass even if no route ever called it. This is the test
 * that fails when a decision path stops telling guarantors — the original bug
 * was exactly that, on three of the four paths.
 *
 * The paths that tell guarantors:
 *
 *   routes/adminApi.js       POST /loans/:id/decision
 *   routes/adminApi.js       POST /loans/:id/approve
 *   routes/adminApi.js       POST /loans/:id/reject
 *   routes/adminApi.js       POST /loans/:id/disburse  (liability starts)
 *   lib/approvalRequests.js  Approval Center execution
 */
const fs = require('fs');
const path = require('path');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', 'src', rel), 'utf8');

const adminApi = read('routes/adminApi.js');
const approvalRequests = read('lib/approvalRequests.js');

/** Count calls that pass an explicit approve/reject flag. */
const calls = (src) => (src.match(/notifyGuarantorsOfDecision\(/g) || []).length;

describe('every loan decision tells the guarantors', () => {
  test('the admin API wires the notifier into every decision endpoint', () => {
    // /decision, /approve, /reject and /disburse. Asserted as a floor rather
    // than an exact count so a new path does not have to edit this test, while
    // dropping one still fails it.
    expect(calls(adminApi)).toBeGreaterThanOrEqual(4);
  });

  test('the Approval Center wires the notifier too', () => {
    expect(calls(approvalRequests)).toBe(1);
  });

  test('the admin API imports the shared notifier rather than a local copy', () => {
    expect(adminApi).toContain("require('../lib/guarantorNotifications')");
    // A second local implementation is how the paths drifted apart before.
    expect(adminApi).not.toMatch(/async function notifyGuarantorsOf/);
  });

  test('rejections notify guarantors, not only approvals', () => {
    // Each of these handlers must pass the decision through, so a rejection
    // reaches the guarantors with the right outcome.
    expect(adminApi).toMatch(/notifyGuarantorsOfDecision\(data, false, reason\)/);
    expect(adminApi).toMatch(/notifyGuarantorsOfDecision\(data, true, null\)/);
    expect(adminApi).toMatch(/notifyGuarantorsOfDecision\(data, approve, reason\)/);
    expect(approvalRequests).toMatch(/notifyGuarantorsOfDecision\(loan, approve, reason\)/);
  });

  test('the Approval Center notifier runs outside the borrower try/catch', () => {
    // Inside the block above it, a borrower-notification failure would skip
    // the guarantors entirely.
    const body = approvalRequests.slice(approvalRequests.indexOf('async function executeLoanApprovalDecision'));
    const borrowerCatch = body.indexOf("logger.warn('approvalRequests: borrower notification failed:'");
    const guarantorCall = body.indexOf('notifyGuarantorsOfDecision(loan, approve, reason)');
    expect(borrowerCatch).toBeGreaterThan(-1);
    expect(guarantorCall).toBeGreaterThan(borrowerCatch);
  });
});

describe('recovery notices go through the shared notifier', () => {
  const worker = fs.readFileSync(
    path.join(__dirname, '../src/workers/loanRecoveryWorker.js'), 'utf8',
  );

  test('the worker uses the shared notifier', () => {
    expect(worker).toMatch(/guarantorNotifications\.notifyGuarantorsOfRecovery/);
  });

  test('the worker no longer queries the unwritten "accepted" status', () => {
    // Nothing in the codebase writes 'accepted'; consent writes 'consented'.
    // Filtering on it matched no row, so guarantors were never told.
    expect(worker).not.toMatch(/eq\(\s*'status'\s*,\s*'accepted'\s*\)/);
  });

  test('the shared module treats both spellings as bound', () => {
    const mod = fs.readFileSync(
      path.join(__dirname, '../src/lib/guarantorNotifications.js'), 'utf8',
    );
    expect(mod).toMatch(/'consented'/);
    expect(mod).toMatch(/'accepted'/);
  });
});
