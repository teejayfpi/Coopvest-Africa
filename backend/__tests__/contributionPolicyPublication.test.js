/**
 * The published Contribution Policy and the enforcement code must agree.
 *
 * A rule that members can be refused a loan under has to be written down where
 * they can read it, in the same terms the code applies. These tests fail if the
 * two drift: a grace period changed in code but not in the terms, or a rule
 * quietly dropped from the published text.
 */
const terms = require('../src/config/terms.json');
const { POLICY } = require('../src/lib/contributionConsistency');

const section = (id) => terms.sections.find((s) => s.id === id);
const contributionPolicy = section('contribution_policy');

describe('published contribution policy', () => {
  test('exists and has a body', () => {
    expect(contributionPolicy).toBeDefined();
    expect(contributionPolicy.body.length).toBeGreaterThan(200);
  });

  test('states the grace period the code actually applies', () => {
    // POLICY.graceDays is 10; the text must say ten (10) days, not "14" or "7".
    expect(contributionPolicy.body).toContain(`(${POLICY.graceDays}) days`);
  });

  test('states that contributions must be current to borrow', () => {
    expect(contributionPolicy.body.toLowerCase()).toContain('must be current');
  });

  test('says borrowing resumes automatically once paid up', () => {
    // The rule is reversible; members need to know paying clears it.
    expect(contributionPolicy.body.toLowerCase()).toContain('resumes automatically');
  });

  test('says no penalty is charged for a lapse', () => {
    expect(contributionPolicy.body.toLowerCase()).toContain('no penalty');
  });

  test('says the rule applies to every loan application', () => {
    // Enforcement is no longer tied to an agreement version - that gate let a
    // caller skip the check by omitting the field. The published text must not
    // suggest some applications are exempt.
    expect(contributionPolicy.body.toLowerCase()).toContain('applies to every loan application');
    expect(contributionPolicy.body.toLowerCase()).not.toContain('earlier version');
  });
});

describe('terms document integrity', () => {
  test('every section has the fields the app renders', () => {
    for (const s of terms.sections) {
      expect(typeof s.id).toBe('string');
      expect(typeof s.title).toBe('string');
      expect(typeof s.summary).toBe('string');
      expect(typeof s.body).toBe('string');
    }
  });

  test('the document is versioned', () => {
    expect(terms.version).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  test('section ids are unique', () => {
    const ids = terms.sections.map((s) => s.id);
    expect(new Set(ids).size).toBe(ids.length);
  });
});
