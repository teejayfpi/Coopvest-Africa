/**
 * Guards the consent contract for the contribution-currency rule.
 *
 * The server only applies the rule to applications whose agreement version
 * discloses it. That is a promise to members, and it depends on three things
 * staying in sync: the version the app sends, the version the policy requires,
 * and the clause in the agreement the member reads. If any one of them drifts,
 * members are either refused under a rule they never saw, or the rule is never
 * applied at all.
 */
const fs = require('fs');
const path = require('path');

// Repo root is one level above `backend/`; app sources live there.
const read = (rel) => fs.readFileSync(path.join(__dirname, '..', '..', rel), 'utf8');

const { POLICY } = require('../src/lib/contributionConsistency');

const appScreen = read('lib/presentation/screens/loan/loan_application_screen.dart');
const appService = read('lib/data/api/loan_api_service.dart');
const loansRoute = read('backend/src/routes/loans.js');

describe('the app sends the version the policy requires', () => {
  test('the apply request carries the current agreement version', () => {
    expect(appScreen).toContain(`'agreementVersion': '${POLICY.version}'`);
  });

  test('the request model defaults to the current agreement version', () => {
    // A default that lags would exempt every member who builds the request
    // without passing a version explicitly.
    expect(appService).toContain(`this.agreementVersion = '${POLICY.version}'`);
  });
});

describe('the agreement the member reads discloses the rule', () => {
  test('the dialog states the grace period', () => {
    expect(appScreen).toContain('ten (10) days');
  });

  test('the dialog states that contributions must be current', () => {
    expect(appScreen.toLowerCase()).toContain('must be current');
  });

  test('the dialog states borrowing resumes once paid up', () => {
    expect(appScreen.toLowerCase()).toContain('resumes automatically');
  });
});

describe('the server enforces only against consent', () => {
  test('the currency check is gated on the accepted agreement version', () => {
    expect(loansRoute).toContain('contributionConsistency.policyAppliesTo(agreementVersion)');
  });

  test('the loan records what the member accepted, not an assumed default', () => {
    // Defaulting to the current version would fabricate consent evidence. The
    // key is omitted entirely when the client sent no version so the column
    // default applies: `loan_agreements.agreement_version` is NOT NULL, so an
    // explicit null would fail the insert and silently drop the consent record.
    const records = loansRoute.match(/\.\.\.\(agreementVersion \? .* : \{\}\)/g) || [];
    expect(records.length).toBe(2);
    expect(loansRoute).not.toContain('agreement_version: agreementVersion || null');
  });

  test('a refusal is machine-readable and explains itself', () => {
    expect(loansRoute).toContain('CONTRIBUTIONS_NOT_CURRENT');
  });
});

describe('consent evidence survives a client that sends no version', () => {
  /**
   * The insert omits `agreement_version` when the client sent none, relying on
   * the column default. This is the only reason the record is written at all:
   * the column is NOT NULL in production, and the insert's error is merely
   * logged, so a null would return 201 to the member while dropping the consent
   * evidence. That combination is silent, which is why it needs a guard.
   */
  test('the payload omits the key rather than sending null', () => {
    const inserts = loansRoute.match(/\.\.\.\(agreementVersion \? \{ agreement_version: agreementVersion \} : \{\}\)/g) || [];
    expect(inserts.length).toBe(2);
  });

  test('a client version is still recorded verbatim', () => {
    // A member who accepted v1.1 must keep v1.1 — the gate depends on it.
    expect(loansRoute).toContain('{ agreement_version: agreementVersion }');
  });
});
