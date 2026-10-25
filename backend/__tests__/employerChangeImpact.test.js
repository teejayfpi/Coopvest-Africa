const { assessEmployerChangeImpact, CODE } = require('../src/lib/employerChangeImpact');

describe('assessEmployerChangeImpact', () => {
  const base = {
    hasActiveLoan: true,
    previousOrgId: 'org-1',
    nextOrgId: 'org-2',
    previousChannel: 'salary',
    nextChannel: 'salary',
  };

  test('no active loan means no review, whatever changed', () => {
    const impact = assessEmployerChangeImpact({ ...base, hasActiveLoan: false });
    expect(impact.reviewRequired).toBe(false);
    expect(impact.codes).toEqual([]);
    expect(impact.reason).toBeNull();
    expect(impact.memberWarning).toBeNull();
  });

  test('moving to a different employer on an active loan needs review', () => {
    const impact = assessEmployerChangeImpact(base);
    expect(impact.reviewRequired).toBe(true);
    expect(impact.codes).toContain(CODE.ORGANISATION_CHANGED);
    expect(impact.reason).toBeTruthy();
    expect(impact.memberWarning).toBeTruthy();
  });

  test('switching channel on an active loan needs review', () => {
    const impact = assessEmployerChangeImpact({
      ...base,
      previousOrgId: null,
      nextOrgId: null,
      previousChannel: 'direct',
      nextChannel: 'salary',
    });
    expect(impact.reviewRequired).toBe(true);
    expect(impact.codes).toEqual([CODE.CHANNEL_CHANGED]);
  });

  test('an unchanged employer on an active loan is not flagged', () => {
    // Re-saving the same details must not raise a review every time.
    const impact = assessEmployerChangeImpact(base);
    const same = assessEmployerChangeImpact({ ...base, nextOrgId: 'org-1' });
    expect(same.reviewRequired).toBe(false);
    expect(same.codes).toEqual([]);
    // Sanity: the differing case above really is flagged.
    expect(impact.reviewRequired).toBe(true);
  });

  test('linking a first employer on an active loan needs review', () => {
    const impact = assessEmployerChangeImpact({
      ...base,
      previousOrgId: null,
      nextOrgId: 'org-1',
    });
    expect(impact.reviewRequired).toBe(true);
    expect(impact.codes).toContain(CODE.ORGANISATION_CHANGED);
  });

  test('clearing the employer link on an active loan needs review', () => {
    // A member who moves to direct deposit drops the employer; their salaried
    // guarantors no longer match, so this must not pass silently.
    const impact = assessEmployerChangeImpact({
      ...base,
      nextOrgId: null,
      nextChannel: 'direct',
    });
    expect(impact.reviewRequired).toBe(true);
    expect(impact.codes).toContain(CODE.ORGANISATION_CHANGED);
    expect(impact.codes).toContain(CODE.CHANNEL_CHANGED);
  });

  test('null and undefined employer links are treated as equal', () => {
    const impact = assessEmployerChangeImpact({
      hasActiveLoan: true,
      previousOrgId: undefined,
      nextOrgId: null,
      previousChannel: 'direct',
      nextChannel: 'direct',
    });
    expect(impact.reviewRequired).toBe(false);
  });
});
