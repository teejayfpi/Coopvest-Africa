/**
 * Guarantor eligibility matrix.
 *
 * The rule the business asked for:
 *   * a salary-deduction borrower's guarantors must be salary-deduction members
 *     of the same organisation; and
 *   * a direct-deposit borrower's guarantors must be direct-deposit members
 *     (a salaried member may not stand for them).
 *
 * These tests pin both directions of every branch, including the "unknown
 * channel" cases, so a later refactor cannot quietly widen or loosen the rule.
 */

const {
  contributionChannel,
  guarantorEligibility,
  canGuarantee,
} = require('../src/lib/guarantorEligibility');

const ORG_A = 'org-a';
const ORG_B = 'org-b';

const salary = (id, orgId = ORG_A) => ({
  id,
  contribution_method: 'salary_deduction',
  contribution_type: null,
  organization_id: orgId,
});
const direct = (id) => ({
  id,
  contribution_method: 'direct_deposit',
  contribution_type: null,
  organization_id: null,
});
const unknown = (id) => ({
  id,
  contribution_method: null,
  contribution_type: null,
  organization_id: null,
});

describe('contributionChannel', () => {
  test('reads payroll spellings as salary', () => {
    expect(contributionChannel({ contribution_method: 'payroll' })).toBe('salary');
    expect(contributionChannel({ contribution_method: 'salary_deduction' })).toBe('salary');
    expect(contributionChannel({ contribution_method: 'salary-based' })).toBe('salary');
    expect(contributionChannel({ contribution_type: 'salary_deduction' })).toBe('salary');
  });

  test('reads self-funded spellings as direct', () => {
    expect(contributionChannel({ contribution_method: 'direct_deposit' })).toBe('direct');
    expect(contributionChannel({ contribution_method: 'manual' })).toBe('direct');
  });

  test('anything else is unknown', () => {
    expect(contributionChannel(null)).toBe('unknown');
    expect(contributionChannel({})).toBe('unknown');
    expect(contributionChannel({ contribution_method: 'something_else' })).toBe('unknown');
  });
});

describe('salary-deduction borrower', () => {
  test('same organisation, salary guarantor is eligible', () => {
    const r = guarantorEligibility(salary('b', ORG_A), salary('g', ORG_A));
    expect(r.eligible).toBe(true);
    expect(canGuarantee(salary('b', ORG_A), salary('g', ORG_A))).toBe(true);
  });

  test('different organisation is rejected', () => {
    const r = guarantorEligibility(salary('b', ORG_A), salary('g', ORG_B));
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('ORG_MISMATCH');
  });

  test('direct-deposit guarantor is rejected', () => {
    const r = guarantorEligibility(salary('b', ORG_A), direct('g'));
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('GUARANTOR_NOT_SALARY');
  });

  test('salary guarantor with no organisation is rejected', () => {
    const r = guarantorEligibility(salary('b', ORG_A), salary('g', null));
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('ORG_MISMATCH');
  });

  test('borrower with no organisation is rejected even for a same-org guarantor', () => {
    const r = guarantorEligibility(salary('b', null), salary('g', null));
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('BORROWER_NO_ORG');
  });
});

describe('direct-deposit borrower', () => {
  test('direct-deposit guarantor is eligible', () => {
    const r = guarantorEligibility(direct('b'), direct('g'));
    expect(r.eligible).toBe(true);
  });

  test('salary-deduction guarantor is rejected', () => {
    const r = guarantorEligibility(direct('b'), salary('g', ORG_A));
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('GUARANTOR_SALARIED');
  });

  test('unknown-channel guarantor is rejected', () => {
    const r = guarantorEligibility(direct('b'), unknown('g'));
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('GUARANTOR_CHANNEL_UNKNOWN');
  });
});

describe('self and unknown borrowers', () => {
  test('a member cannot guarantee their own loan', () => {
    const me = salary('me', ORG_A);
    const r = guarantorEligibility(me, me);
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('SELF');
  });

  test('unknown borrower channel is refused, not guessed', () => {
    const r = guarantorEligibility(unknown('b'), direct('g'));
    expect(r.eligible).toBe(false);
    expect(r.code).toBe('BORROWER_CHANNEL_UNKNOWN');
  });

  test('missing profiles are refused', () => {
    expect(guarantorEligibility(null, direct('g')).eligible).toBe(false);
    expect(guarantorEligibility(direct('b'), null).eligible).toBe(false);
  });
});
