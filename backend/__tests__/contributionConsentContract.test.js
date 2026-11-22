/**
 * Guards the consent contract for the loan eligibility rule.
 *
 * The rule now applies to every applicant, so it has to be disclosed everywhere
 * a member might read it. It depends on these staying in sync: the version the
 * app sends, the version the policy requires, the clause in the in-app
 * agreement, and the published terms document. If any one drifts, members are
 * refused under a rule they were never shown.
 *
 * The rule used to be gated on `policyAppliesTo(agreementVersion)`. That
 * exempted any caller that omitted the optional `agreementVersion` field, so a
 * member who had stopped contributing months earlier was approved by leaving
 * the field out. Enforcement is now unconditional; this suite fails if the gate
 * is ever reinstated.
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

  test('the dialog states the six consecutive months requirement', () => {
    expect(appScreen).toContain('six (6) consecutive months');
  });

  test('the dialog states that a missed month breaks the run', () => {
    expect(appScreen.toLowerCase()).toContain('breaks the run');
  });
});

describe('the published terms disclose the rule', () => {
  const terms = require('../src/config/terms.json');
  const loanPolicy = terms.sections.find((s) => s.id === 'loan_policy');

  test('the loan policy section names six consecutive months', () => {
    expect(loanPolicy.body).toContain('six (6) consecutive months');
  });

  test('the loan policy section says a missed month breaks the run', () => {
    expect(loanPolicy.body.toLowerCase()).toContain('breaks the consecutive run');
  });

  test('the loan policy section states contributions must be current', () => {
    expect(loanPolicy.body.toLowerCase()).toContain('current at the time of application');
  });

  test('the bundled offline copy mirrors the served version', () => {
    const bundled = read('lib/data/models/terms_content.dart');
    expect(bundled).toContain(`static const String version = '${terms.version}';`);
  });
});

describe('the server enforces the rule unconditionally', () => {
  test('the eligibility check is not gated on the accepted agreement version', () => {
    // The gate let a caller skip the check by omitting an optional field.
    expect(loansRoute).not.toContain('contributionConsistency.policyAppliesTo(agreementVersion)');
    expect(loansRoute).not.toMatch(/if\s*\(\s*contributionConsistency\.policyAppliesTo/);
  });

  test('the route calls the combined eligibility verdict', () => {
    expect(loansRoute).toContain('contributionConsistency.assessEligibility(');
  });

  test('the route still reads deposits for members who never write a row', () => {
    expect(loansRoute).toContain('CONTRIBUTION_TRANSACTION_TYPES');
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
    expect(loansRoute).toContain('code: verdict.reason');
    expect(loansRoute).toContain('contributionConsistency.eligibilityMessage(verdict)');
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


describe('a refused member is told what to do and where to read the rule', () => {
  const appScreen = read('lib/presentation/screens/loan/loan_application_screen.dart');
  const settingsScreen = read('lib/presentation/screens/profile/profile_settings_screen.dart');

  test('the server returns the reason, the remedy and the terms section', () => {
    expect(loansRoute).toContain('contributionConsistency.eligibilityRefusal(verdict)');
    expect(loansRoute).toContain('guidance: refusal');
    expect(loansRoute).toContain('termsSection:');
  });

  test('the app renders the server refusal message', () => {
    expect(appScreen).toContain('_extractApiError');
  });

  test('the app links a refusal to the section the server cited', () => {
    expect(appScreen).toContain("data['termsSection']");
    expect(appScreen).toContain('_rejectionTermsSectionId');
    expect(appScreen).toContain('Terms & Conditions');
  });

  test('the ineligible card links to the loan policy', () => {
    expect(appScreen).toContain("_openTermsSection('loan_policy')");
  });

  test('the app opens the served document, not the bundled copy', () => {
    expect(appScreen).toContain('termsDocumentProvider');
    expect(appScreen).toContain('TermsSectionScreen');
  });

  test('members can reach the policies from settings', () => {
    // Before this the Loan and Contribution policies were unreachable after
    // onboarding, so a referral to the terms would have dead-ended.
    expect(settingsScreen).toContain("'label': 'Terms & Conditions'");
    expect(settingsScreen).toContain('_openTermsAndConditions');
  });
});

describe('the app and the server answer the same eligibility question', () => {
  const model = read('lib/data/models/contributions/monthly_contribution.dart');
  const helper = read('lib/core/utils/loan_eligibility.dart');
  const card = read('lib/presentation/widgets/loan/loan_eligibility_card.dart');
  const provider = read('lib/presentation/providers/loan_provider.dart');

  test('the server exposes the verdict it enforces', () => {
    // The app cannot compute this from one page of contributions, so it asks.
    expect(loansRoute).toContain("router.get('/eligibility'");
    expect(loansRoute).toContain('computeEligibility');
  });

  test('the application gate and the endpoint share one computation', () => {
    // Two copies of the rule drift; the gate must call the same helper the
    // endpoint reports, or a member is told one thing and refused another.
    const gateUsesHelper = /if \(!loanPolicy\.minEligibilityDisabled\(\)\) \{\s*\n\s*const \{[^}]*\} = await computeEligibility\(profileId\);/.test(loansRoute);
    expect(gateUsesHelper).toBe(true);
  });

  test('/eligibility is registered before the /:loanId catch-all', () => {
    const eligibilityAt = loansRoute.indexOf("router.get('/eligibility'");
    const catchAllAt = loansRoute.indexOf("router.get(\n  '/:loanId',");
    expect(eligibilityAt).toBeGreaterThan(-1);
    expect(catchAllAt).toBeGreaterThan(-1);
    expect(eligibilityAt).toBeLessThan(catchAllAt);
  });

  test('the app fetches the server verdict', () => {
    expect(provider).toContain('serverEligibilityProvider');
    expect(provider).toContain("'/loans/eligibility'");
  });

  test('the dashboard card prefers the server verdict', () => {
    expect(card).toContain('serverEligibilityProvider');
    expect(card).toContain('serverEligibility?.consecutiveMonths');
  });

  test('the card does not decide eligibility from membership alone', () => {
    // The regression: six months of tenure, zero contributions, "Eligible".
    expect(card).not.toMatch(/final isEligible = monthsDone >= monthsRequired/);
    expect(card).toContain('membershipMet && runMet && isCurrent');
  });
});

describe('a settled contribution is never read as unpaid', () => {
  const model = read('lib/data/models/contributions/monthly_contribution.dart');
  const { PAID_CONTRIBUTION_STATUSES } = require('../src/lib/contributionStatuses');

  test('the paid vocabulary the server writes is parsed to a settled status', () => {
    // The enum names only `successful`; the server also writes `completed`,
    // `approved`, `confirmed` and `paid`. Parsing by enum name alone mapped all
    // four onto `pending`, so a paying member read as unpaid.
    expect(PAID_CONTRIBUTION_STATUSES.length).toBeGreaterThan(1);
    for (const status of PAID_CONTRIBUTION_STATUSES) {
      expect(model).toContain(`case '${status}':`);
    }
  });

  test('every module reads the one paid-status list', () => {
    // Three copies drifted: only the wallet's accepted `confirmed`, so that
    // contribution counted toward the balance but not toward eligibility.
    const wallet = read('backend/src/routes/wallet.js');
    const policy = read('backend/src/lib/loanPolicy.js');
    const consistency = read('backend/src/lib/contributionConsistency.js');
    for (const source of [wallet, policy, consistency]) {
      expect(source).toContain('contributionStatuses');
      expect(source).not.toMatch(/new Set\(\['successful'/);
    }
  });

  test('the model no longer matches status by enum name', () => {
    expect(model).not.toContain("(e) => e.name == (json['status'] as String? ?? 'pending')");
    expect(model).toContain('contributionStatusFrom(json[\'status\'])');
  });
});
