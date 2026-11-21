/**
 * Guards the contract between the admin dashboard and the API for the
 * savings-related loan actions.
 *
 * The dashboard approves loans, and can recover a defaulted loan from savings.
 * Both are gated server-side, and the gates are only useful if the dashboard
 * understands them: an officer who sees a bare "409" has no way to make the
 * deliberate decision the gate is asking for. These assert the shapes the
 * dashboard reads are the shapes the server sends.
 */

const fs = require('fs');
const path = require('path');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
const adminApi = read('src/routes/adminApi.js');

describe('approval coverage gate', () => {
  const approve = adminApi.slice(
    adminApi.indexOf("router.post('/loans/:id/approve'"),
    adminApi.indexOf("router.post('/loans/:id/reject'"),
  );

  it('refuses an under-covered approval with 409 and a machine-readable code', () => {
    expect(approve).toContain('status(409)');
    expect(approve).toContain("code: 'UNDER_COVERED'");
  });

  it('returns the figures the dashboard displays, not just a message', () => {
    // The dashboard renders requiredAmount / coveredAmount / shortfall.
    expect(approve).toContain('coverage,');
    const coverage = read('src/lib/guarantorCoverage.js');
    expect(coverage).toContain('shortfall');
    expect(coverage).toContain('coveredAmount');
    expect(coverage).toContain('requiredAmount');
  });

  it('lets the officer approve anyway, but only by saying so explicitly', () => {
    expect(approve).toContain('acknowledgeUnderCovered');
  });

  it('treats a missing flag as not acknowledged', () => {
    // `!req.body?.acknowledgeUnderCovered` means undefined blocks the approval.
    expect(approve).toContain('!req.body?.acknowledgeUnderCovered');
  });
});

describe('recover-from-savings endpoint', () => {
  const recover = adminApi.slice(
    adminApi.indexOf("router.post('/loans/:id/recover-from-savings'"),
  );

  it('exists where the dashboard posts', () => {
    expect(recover.length).toBeGreaterThan(0);
  });

  it('requires both noticeServed and confirm to be exactly true', () => {
    expect(recover).toContain('req.body?.noticeServed !== true');
    expect(recover).toContain('req.body?.confirm !== true');
  });

  it('reports NOT_ELIGIBLE for a loan that is not overdue or worse', () => {
    expect(recover).toContain("code: 'NOT_ELIGIBLE'");
    expect(recover).toContain('isEligibleForSetOff');
  });

  it('returns recovered, shortfall and steps for the result dialog', () => {
    const setoff = read('src/lib/savingsSetoff.js');
    expect(setoff).toContain('shortfall');
    expect(recover).toContain('recovered: data?.recovered');
    expect(recover).toContain('steps: data?.steps');
  });

  it('logs the recovery for the audit trail', () => {
    expect(recover).toContain('LOAN_SAVINGS_SETOFF');
  });
});

describe('guarantor pledges in the loans list', () => {
  it('exposes pledged amounts so the dashboard can show what is held', () => {
    expect(adminApi).toContain('pledged_amount');
    expect(adminApi).toContain('pledgedRecovered');
  });

  it('survives the pledge columns not existing yet', () => {
    // Migration 067 is applied by hand. Selecting a column that does not exist
    // must not blank the guarantor list on every loan in the meantime.
    expect(adminApi).toContain('42703');
    expect(adminApi).toContain('/pledged_/');
  });

  it('reports a null pledge rather than zero for pre-067 guarantees', () => {
    // A null pledge means nothing is held; zero would read as "held, but nil".
    expect(adminApi).toContain('pledged_amount != null ? Number(g.pledged_amount) : null');
  });
});
