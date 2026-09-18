const fs = require('fs');
const path = require('path');

/**
 * Regression guard for the rollover flow.
 *
 * Three defects existed together on the same flow:
 *
 *  1. The admin dashboard's Rollover Management page calls
 *     `/api/admin/rollovers`, `/rollovers/:id/approve` and `/:id/reject`. None
 *     were implemented, so the page 404'd on mount and on every action.
 *
 *  2. Approve and reject wrote columns that do not exist on the table
 *     (`approved_at`, `admin_notes`, `rejected_at`); the real columns are
 *     `reviewed_by` / `reviewed_at` / `rejection_reason`. Verified against
 *     production: 42703 column does not exist, so both actions failed outright.
 *
 *  3. Approving never applied the rollover to the loan. It flipped `status` and
 *     notified the member "your new repayment schedule is now active" while the
 *     tenure, monthly repayment and outstanding balance were all unchanged.
 *
 * These tests assert the shape of the fix so none of the three can return.
 */
describe('rollover flow', () => {
  const adminSource = fs.readFileSync(
    path.join(__dirname, '../src/routes/adminRollovers.js'),
    'utf8',
  );
  const memberSource = fs.readFileSync(
    path.join(__dirname, '../src/routes/rollover.js'),
    'utf8',
  );
  const adminApiSource = fs.readFileSync(
    path.join(__dirname, '../src/routes/adminApi.js'),
    'utf8',
  );

  test('the admin rollover router is mounted', () => {
    expect(adminApiSource).toMatch(/require\('\.\/adminRollovers'\)/);
    expect(adminApiSource).toMatch(/router\.use\(adminRollovers\)/);
  });

  test('the routes the dashboard calls are implemented', () => {
    expect(adminSource).toMatch(/router\.get\('\/rollovers'/);
    expect(adminSource).toMatch(/router\.post\(\s*'\/rollovers\/:id\/approve'/);
    expect(adminSource).toMatch(/router\.post\(\s*'\/rollovers\/:id\/reject'/);
  });

  test('approval writes only columns that exist on the table', () => {
    // `rejected_at` does not exist on `rollovers`; the reject paths must use
    // `reviewed_at`. `approved_at` is legitimate — migration 038 adds it — so
    // the two handlers are checked individually.
    //
    // Comments are stripped before matching: the handlers carry an explanatory
    // note naming the bad column, and a guard that a comment can satisfy is
    // worthless.
    const stripComments = (src) =>
      src
        .split('\n')
        .filter((l) => !l.trim().startsWith('//'))
        .join('\n');

    for (const [label, source, anchor] of [
      ['member', memberSource, "'/:id/reject'"],
      ['admin', adminSource, "'/rollovers/:id/reject'"],
    ]) {
      const start = source.indexOf(anchor);
      expect({ label, found: start > -1 }).toEqual({ label, found: true });

      const code = stripComments(source.slice(start, start + 1200));
      expect({ label, writesRejectedAt: /rejected_at\s*:/.test(code) }).toEqual({
        label,
        writesRejectedAt: false,
      });
      expect({ label, writesReviewedAt: /reviewed_at\s*:/.test(code) }).toEqual({
        label,
        writesReviewedAt: true,
      });
    }
  });

  test('approval executes the refinance', () => {
    // Both the admin route and the member-facing admin route must call the
    // function that creates the new loan and settles the old one.
    expect(adminSource).toMatch(/rpc\('execute_loan_rollover'/);
    expect(memberSource).toMatch(/rpc\('execute_loan_rollover'/);
  });

  test('the member is only notified after the rollover is executed', () => {
    // Ordering matters: notifying first would repeat the original bug of
    // telling the member their schedule changed when it had not.
    const idxApply = adminSource.indexOf("rpc('execute_loan_rollover'");
    const idxNotify = adminSource.indexOf('notifyRolloverApproved');
    expect(idxApply).toBeGreaterThan(-1);
    expect(idxNotify).toBeGreaterThan(-1);
    expect(idxApply).toBeLessThan(idxNotify);
  });

  test('a failed application does not leave the rollover approved', () => {
    // If applying fails, the approval must be reverted so the member is never
    // in an "approved but unchanged" state.
    expect(adminSource).toMatch(/status: 'awaiting_admin_approval', approved_at: null/);
  });
});