/**
 * The onboarding gate is split by risk.
 *
 * Members complained registration was too long: the dashboard, wallet and
 * savings were gated on KYC *approval* AND the registration fee, so a member
 * who had paid still could not see their own money while an admin reviewed
 * their documents (four production members were in exactly this state).
 *
 * The rule now is:
 *   - requireRegistrationPaid -> dashboard / wallet / savings. Fee settled is
 *     enough; KYC is not required. No credit risk.
 *   - requireActivated -> loans / rollover / guarantor / payout accounts.
 *     KYC remains mandatory because lending or paying out without a verified
 *     identity is the real exposure.
 *
 * These tests pin both directions so a future refactor cannot quietly widen
 * the KYC exemption into lending, or re-tighten the dashboard.
 */

const fs = require('fs');
const path = require('path');

const authSource = fs.readFileSync(
  path.join(__dirname, '../src/middleware/auth.js'),
  'utf8',
);
const serverSource = fs.readFileSync(
  path.join(__dirname, '../src/server.js'),
  'utf8',
);

/**
 * Middleware chain mounted at a path, or null when no exact mount exists.
 *
 * The chain can contain nested parentheses — `requireFeatureFlag('loanModule')`
 * — so this captures greedily to the closing `);` at the end of the line
 * rather than to the first `)`.
 */
function mountFor(routePath) {
  const re = new RegExp(
    "app\\.use\\('" + routePath.replace(/[/]/g, '\\/') + "'\\s*,\\s*(.+)\\);\\s*$",
    'm',
  );
  const m = serverSource.match(re);
  return m ? m[1] : null;
}

describe('middleware definitions', () => {
  test('requireActivated still requires the full gate (KYC + fee)', () => {
    expect(authSource).toMatch(/function requireActivated\(/);
    expect(authSource).toMatch(/if \(gate\.activated\) return next\(\);/);
  });

  test('requireRegistrationPaid gates on the fee alone, not KYC', () => {
    const start = authSource.indexOf('function requireRegistrationPaid(');
    expect(start).toBeGreaterThan(-1);
    const body = authSource.slice(start, start + 1400);

    // Acts on the settled flag...
    expect(body).toMatch(
      /if \(gate\.registration_fee_settled && !gate\.blocked\) return next\(\);/,
    );
    // ...and never consults KYC approval.
    const head = body.slice(0, body.indexOf('try {'));
    expect(head).not.toMatch(/kyc_approved/);
    expect(head).not.toMatch(/gate\.activated/);
  });

  test('it is exported for the route mounts to use', () => {
    expect(authSource).toMatch(/requireRegistrationPaid,/);
  });
});

describe('dashboard and money routes do not require KYC', () => {
  const feeOnly = [
    '/api/v1/wallet',
    '/api/wallet',
    '/api/v1/savings',
    '/api/savings',
    '/api/v1/transactions',
    '/api/transactions',
    '/api/v1/contributions',
    '/api/contributions',
    '/api/v1/termination',
    '/api/termination',
    '/api/v1/investments',
    '/api/investments',
  ];

  test.each(feeOnly)('%s is gated on the registration fee only', (route) => {
    const chain = mountFor(route);
    expect(chain).not.toBeNull();
    expect(chain).toMatch(/requireRegistrationPaid/);
    expect(chain).not.toMatch(/requireActivated/);
  });
});

describe('credit and disbursement routes still require full KYC', () => {
  const kycRequired = [
    '/api/v1/loans',
    '/api/loans',
    '/api/v1/rollover',
    '/api/rollover',
    '/api/v1/guarantor',
    '/api/guarantor',
  ];

  test.each(kycRequired)('%s keeps requireActivated', (route) => {
    const chain = mountFor(route);
    expect(chain).not.toBeNull();
    expect(chain).toMatch(/requireActivated/);
    expect(chain).not.toMatch(/requireRegistrationPaid/);
  });
});