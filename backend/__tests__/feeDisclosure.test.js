/**
 * The published fee disclosure must equal the fees we actually charge.
 *
 * `config/feeDisclosure.js` holds the amounts; `config/terms.json` is the text
 * the member reads and accepts during onboarding. The two are edited by
 * different people for different reasons, so they drift. A member who read
 * "₦3,000" and was charged "₦5,000" has a legitimate grievance, and the
 * disclosure becomes evidence against us rather than a defence.
 *
 * These tests parse the published prose and assert every figure in it matches
 * the constant the code charges. They also assert the bundled Flutter copy
 * still mirrors the served document, because a member offline sees that copy.
 */

const fs = require('fs');
const path = require('path');

const {
  LATE_REPAYMENT_FINE,
  REGISTRATION_FEE,
  MIN_MONTHLY_CONTRIBUTION,
  ADMINISTRATIVE_FEE,
  LOAN_INTEREST_RATES,
} = require('../src/config/feeDisclosure');

const terms = require('../src/config/terms.json');

const ROOT = path.join(__dirname, '..', '..');

function sectionById(id) {
  const found = (terms.sections || []).find((s) => s.id === id);
  if (!found) throw new Error(`terms.json has no section '${id}'`);
  return found;
}

/** All naira amounts written in a string, as numbers. */
function nairaAmountsIn(text) {
  return [...text.matchAll(/₦([\d,]+)/g)].map((m) => Number(m[1].replace(/,/g, '')));
}

describe('fee disclosure', () => {
  describe('the disclosure section exists and is reachable', () => {
    test('terms.json publishes a fees_and_charges section', () => {
      const section = sectionById('fees_and_charges');
      expect(section.title).toBe('Fees & Charges');
      expect(section.body.length).toBeGreaterThan(200);
    });

    test('it is shown early, not buried at the end', () => {
      const ids = terms.sections.map((s) => s.id);
      const position = ids.indexOf('fees_and_charges');
      expect(position).toBeGreaterThan(-1);
      // Onboarding requires every section to be opened and accepted, so order
      // is about prominence. A member should meet the charges before the
      // policy detail, not after.
      expect(position).toBeLessThanOrEqual(2);
    });

    test('the document version is dated, so an acceptance names a revision', () => {
      expect(terms.version).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    });
  });

  describe('every published amount matches the amount we charge', () => {
    const body = () => sectionById('fees_and_charges').body;

    test('the registration fee', () => {
      expect(body()).toContain(`₦${REGISTRATION_FEE.toLocaleString('en-NG')}`);
    });

    test('the minimum monthly contribution', () => {
      expect(body()).toContain(`₦${MIN_MONTHLY_CONTRIBUTION.toLocaleString('en-NG')}`);
    });

    test('the administrative fee and each levy it is made of', () => {
      const text = body();
      expect(text).toContain(`₦${ADMINISTRATIVE_FEE.total.toLocaleString('en-NG')}`);
      for (const component of ADMINISTRATIVE_FEE.components) {
        expect(text).toContain(`₦${component.amount.toLocaleString('en-NG')}`);
      }
    });

    test('the late repayment fine', () => {
      expect(body()).toContain(`₦${LATE_REPAYMENT_FINE.toLocaleString('en-NG')}`);
    });

    test('the levies add up to the administrative fee', () => {
      const sum = ADMINISTRATIVE_FEE.components.reduce((s, c) => s + c.amount, 0);
      expect(sum).toBe(ADMINISTRATIVE_FEE.total);
    });
  });

  describe('the published prose contains no amount we do not charge', () => {
    test('every naira figure in the section is a known charge', () => {
      const known = new Set([
        REGISTRATION_FEE,
        MIN_MONTHLY_CONTRIBUTION,
        ADMINISTRATIVE_FEE.total,
        ...ADMINISTRATIVE_FEE.components.map((c) => c.amount),
        LATE_REPAYMENT_FINE,
      ]);
      const unknown = nairaAmountsIn(sectionById('fees_and_charges').body)
        .filter((amount) => !known.has(amount));
      expect(unknown).toEqual([]);
    });
  });

  describe('the loan interest rates we publish match the rates we charge', () => {
    test('every product in the disclosure is a product we lend', () => {
      const text = sectionById('fees_and_charges').body;
      for (const [product, rate] of Object.entries(LOAN_INTEREST_RATES)) {
        expect(text).toContain(product);
        expect(text).toContain(`${rate}%`);
      }
    });

    test('the disclosure rates agree with the service that charges them', () => {
      // referralService is the authority the loan routes price against.
      const referralService = require('../src/services/referralService');
      for (const [product, rate] of Object.entries(LOAN_INTEREST_RATES)) {
        expect(referralService.getBaseInterestRate(product)).toBe(rate);
      }
    });
  });

  describe('the charges we levy are the charges we publish', () => {
    test('the fine the loan route applies comes from the disclosure', () => {
      const source = fs.readFileSync(
        path.join(ROOT, 'backend', 'src', 'routes', 'loans.js'),
        'utf8'
      );
      expect(source).toContain('LATE_REPAYMENT_FINE');
      expect(source).not.toMatch(/const PENALTY = \d/);
    });

    test('the fine the recovery worker applies comes from the disclosure', () => {
      const source = fs.readFileSync(
        path.join(ROOT, 'backend', 'src', 'workers', 'loanRecoveryWorker.js'),
        'utf8'
      );
      expect(source).toContain('LATE_REPAYMENT_FINE');
      // Member-facing messages are template literals. No template literal may
      // hardcode a naira amount, or it would quote a stale figure the moment
      // the constant changes. Comments may still name the amount.
      expect(source).not.toMatch(/`[^`]*₦[\d,]+[^`]*`/);
    });
  });

  describe('the bundled offline copy mirrors the served document', () => {
    const dart = fs.readFileSync(
      path.join(ROOT, 'lib', 'data', 'models', 'terms_content.dart'),
      'utf8'
    );

    test('the bundled document declares the same version', () => {
      expect(dart).toContain(`static const String version = '${terms.version}';`);
    });

    test('the bundled document carries the fees section', () => {
      expect(dart).toContain("id: 'fees_and_charges'");
    });

    test('the bundled copy quotes the same amounts', () => {
      for (const amount of nairaAmountsIn(sectionById('fees_and_charges').body)) {
        expect(dart).toContain(`₦${amount.toLocaleString('en-NG')}`);
      }
    });
  });

  describe('the disclosure states plainly that nothing else is charged', () => {
    test('it says no withdrawal fee applies', () => {
      expect(sectionById('fees_and_charges').body.toLowerCase())
        .toContain('no withdrawal fee');
    });

    test('it says early repayment carries no penalty', () => {
      expect(sectionById('fees_and_charges').body.toLowerCase())
        .toContain('no penalty for repaying early');
    });
  });
});
