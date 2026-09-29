const fs = require('fs');
const path = require('path');

/**
 * Regression guard for the registration-fee gate.
 *
 * Members with the **Direct Deposit** contribution route could reach the
 * member dashboard without paying the ₦5,000 registration fee: pressing back
 * from the payment screen, or signing out and back in, dropped them into the
 * app. Two server-side holes let that stand:
 *
 *   1. `GET /user/dashboard` (savings + referral figures) was mounted behind
 *      `authenticate` only, so an authenticated-but-unpaid member could read
 *      their dashboard summary directly. It is now `requireRegistrationPaid`.
 *   2. There was no ungated endpoint the app could ask "am I activated?" —
 *      so the client gate had nothing authoritative to re-check on resume.
 *      `GET /api/v1/app/home-status` now answers that with the same
 *      `gateStatusFor` decision `requireRegistrationPaid` enforces.
 *
 * The exemption itself (salary deduction with an employer on file) is covered
 * in activationGate.test.js; this file covers the wiring.
 */
describe('registration-fee enforcement wiring', () => {
  const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
  const codeOnly = (src) =>
    src
      .split('\n')
      .filter((line) => !line.trim().startsWith('//') && !line.trim().startsWith('*'))
      .join('\n');

  test('GET /user/dashboard requires a settled registration fee', () => {
    const src = read('src/routes/user.js');
    const route = src.match(/router\.get\(\s*'\/dashboard'[^\n]*/);
    expect(route).not.toBeNull();
    expect(route[0]).toContain('requireRegistrationPaid');
  });

  test('user.js imports the gate it uses', () => {
    expect(read('src/routes/user.js')).toContain('requireRegistrationPaid');
  });

  test('the onboarding home-status endpoint exists and is ungated', () => {
    const src = read('src/routes/app.js');
    const route = src.match(/router\.get\(\s*'\/home-status'[^\n]*/);
    expect(route).not.toBeNull();
    // It must NOT carry a gate: the app calls it while the member is still
    // unpaid, to find out that they are unpaid.
    expect(route[0]).not.toContain('requireRegistrationPaid');
    expect(route[0]).not.toContain('requireActivated');
  });

  test('home-status returns the gate and no financial fields', () => {
    const src = read('src/routes/app.js');
    expect(src).toContain('gateStatusFor');
    // The route is reachable by an unpaid member, so it must not become a way
    // to read balances. Fail if a money field is ever added.
    const code = codeOnly(src);
    for (const money of ['total_saved', 'balance', 'outstanding', 'monthly_savings']) {
      expect(code).not.toContain(money);
    }
  });

  test('app routes are mounted under /api/v1/app', () => {
    const src = read('src/server.js');
    expect(src).toContain("app.use('/api/v1/app', appRoutes)");
  });

  test('the home-status lookup fails closed', () => {
    // On a profile-lookup error the endpoint must report activated: false, so
    // a backend hiccup never hands an unpaid member the dashboard.
    expect(read('src/routes/app.js')).toContain('activated: false');
  });
});
