const fs = require('fs');
const path = require('path');

/**
 * Route-exposure regression tests.
 *
 * These pin the fixes for a class of bug that is invisible in a normal test:
 * an admin router mounted on a member prefix, or an admin router whose only
 * guard is `authenticate`. Both leave the handlers reachable with an ordinary
 * member token, and neither shows up until someone reads server.js next to the
 * router's own guard.
 *
 * The specific incident: `app.use('/api/kyc', kycAdminRoutes)` combined with
 * `router.use(authenticate)` in kycAdmin.js. Member kyc.js defines no
 * catch-all, so GET /api/kyc/pending and GET /api/kyc/:profileId (which selects
 * profiles.* — BVN, NIN, bank details) fell through to the admin handlers with
 * only a member token, and POST /api/kyc/:profileId/verify let a member approve
 * their own KYC.
 */

const serverSrc = fs.readFileSync(path.join(__dirname, '..', 'src', 'server.js'), 'utf8');
const kycAdminSrc = fs.readFileSync(path.join(__dirname, '..', 'src', 'routes', 'kycAdmin.js'), 'utf8');

describe('admin routers are never reachable on a member prefix', () => {
  test('kycAdmin is not mounted at the member /api/kyc prefix', () => {
    expect(serverSrc).not.toMatch(/app\.use\(\s*['"]\/api\/kyc['"]\s*,\s*kycAdminRoutes\s*\)/);
  });

  test('kycAdmin is still mounted at the guarded admin prefixes', () => {
    expect(serverSrc).toMatch(/app\.use\(\s*['"]\/api\/v2\/admin\/kyc['"]\s*,\s*kycAdminRoutes\s*\)/);
  });

  test('the admin KYC router requires an admin role, not just a session', () => {
    // `router.use(authenticate)` admits any signed-in member. The guard must be
    // requireAdmin (or requirePermission) for a router that returns other
    // members' PII.
    const guardLine = kycAdminSrc.match(/^router\.use\(([^)]*)\)/m);
    expect(guardLine).not.toBeNull();
    expect(guardLine[1]).toMatch(/requireAdmin|requirePermission|requireSuperAdmin/);
    expect(guardLine[1]).not.toMatch(/^\s*authenticate\s*$/);
  });
});

describe('rate limiting cannot be keyed on attacker-controlled headers', () => {
  test('no rate limiter keys on the raw x-forwarded-for header', () => {
    // X-Forwarded-For is client-supplied; keying on it lets a caller rotate the
    // value per request and defeat the limit. Express's req.ip is derived from
    // the socket and the trusted proxy chain.
    const limiterSections = serverSrc.split('rateLimit(').slice(1);
    expect(limiterSections.length).toBeGreaterThan(0);
    for (const section of limiterSections) {
      const body = section.slice(0, 900);
      expect(body).not.toMatch(/keyGenerator[\s\S]*?req\.headers\[\s*['"]x-forwarded-for['"]\s*\]/);
    }
  });
});

describe('KYC documents are not stored behind public URLs', () => {
  test('the documents upload route signs the URL instead of using getPublicUrl', () => {
    const documentsSrc = fs.readFileSync(
      path.join(__dirname, '..', 'src', 'routes', 'documents.js'),
      'utf8',
    );
    expect(documentsSrc).toMatch(/createSignedUrl/);
    expect(documentsSrc).not.toMatch(/\.getPublicUrl\(/);
  });
});

describe('the Paystack webhook compares the signature in constant time', () => {
  test('timingSafeEqual is used and a genuine error is not swallowed as 200', () => {
    const paymentsSrc = fs.readFileSync(
      path.join(__dirname, '..', 'src', 'routes', 'payments.js'),
      'utf8',
    );
    expect(paymentsSrc).toMatch(/timingSafeEqual/);
    // The webhook catch must not return 200 on failure.
    const catchBlock = paymentsSrc.split("paystack webhook error:")[1] || '';
    expect(catchBlock.slice(0, 400)).not.toMatch(/sendStatus\(200\)/);
  });
});

describe('client IP cannot be forged', () => {
  test('trust proxy is a hop count, not `true`', () => {
    // `true` trusts the whole X-Forwarded-For chain and takes the left-most,
    // caller-supplied entry, defeating the rate limiters and the IP whitelist.
    expect(serverSrc).not.toMatch(/app\.set\(\s*['"]trust proxy['"]\s*,\s*true\s*\)/);
    expect(serverSrc).toMatch(/app\.set\(\s*['"]trust proxy['"]\s*,\s*parseInt\(/);
  });

  test('the public login recorder derives the IP from req.ip, not the header', () => {
    const start = serverSrc.indexOf("'/api/admin/login-history/log'");
    expect(start).toBeGreaterThan(-1);
    const handler = serverSrc.slice(start, start + 700);
    expect(handler).not.toMatch(/req\.headers\[\s*['"]x-forwarded-for['"]\s*\]/);
    expect(handler).toMatch(/req\.ip/);
  });
});

