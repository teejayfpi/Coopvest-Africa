const fs = require('fs');
const path = require('path');

/**
 * Regression guard for the wallet-minting endpoint.
 *
 * `POST /wallet/deposit` credited a member's wallet directly:
 *
 *     const wallet = await adjustBalance(req.user.id, Number(amount));
 *
 * with no payment, no proof and no admin verification, so any authenticated
 * member could mint their own balance by calling it. The mobile app never used
 * it — it uses POST /wallet/contribute, which creates a pending deposit_request
 * for an admin to verify.
 *
 * The route was deleted. This test asserts it stays deleted, and that the
 * verified path still exists, so a future refactor cannot quietly reintroduce a
 * credit-without-verification route.
 */
describe('wallet deposit routes', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '../src/routes/wallet.js'),
    'utf8',
  );

  /** Route declarations in the file, e.g. "post /deposit". */
  const declaredRoutes = () => {
    const routes = [];
    const re = /router\.(get|post|put|patch|delete)\(\s*\n?\s*'([^']+)'/g;
    let m;
    while ((m = re.exec(source)) !== null) {
      routes.push(`${m[1].toUpperCase()} ${m[2]}`);
    }
    return routes;
  };

  test('POST /deposit no longer exists', () => {
    expect(declaredRoutes()).not.toContain('POST /deposit');
  });

  test('the verified deposit path still exists', () => {
    // The replacement: creates a pending request for admin verification.
    expect(declaredRoutes()).toContain('POST /contribute');
    expect(declaredRoutes()).toContain('GET /deposit-requests');
  });

  /** Source with comment lines stripped, so guards test code not prose. */
  const codeOnly = source
    .split('\n')
    .filter((line) => !line.trim().startsWith('//'))
    .join('\n');

  test('no route credits the caller\'s wallet without a verification step', () => {
    // adjustBalance is the primitive that moves a wallet balance. A positive
    // credit against the caller's own id, driven by a client-supplied amount, is
    // the minting pattern that was removed. Debits (transfers, withdrawals) are
    // legitimate and are not matched.
    const selfCreditWithClientAmount =
      /adjustBalance\(\s*req\.user\.id\s*,\s*\+?\s*(Number\(\s*)?(req\.body|amount)\b/;
    expect(selfCreditWithClientAmount.test(codeOnly)).toBe(false);
  });

  test('the removal is documented so the intent survives', () => {
    expect(source).toMatch(/POST \/wallet\/deposit was REMOVED/);
  });
});