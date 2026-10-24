const { planProfileChannelUpdate } = require('../src/lib/contributionChannel');

describe('planProfileChannelUpdate', () => {
  test('salary deduction with an active employer links the organisation', () => {
    const update = planProfileChannelUpdate({
      contributionType: 'salary_deduction',
      employerName: 'Acme Ltd',
      requestedOrgId: 'org-1',
      orgIsActive: true,
    });
    expect(update.contribution_method).toBe('payroll');
    expect(update.contribution_type).toBe('salary_deduction');
    expect(update.organization_id).toBe('org-1');
    expect(update.pending_organization_name).toBeNull();
  });

  test('salary deduction with an inactive/unresolved organisation records a pending request, never the id', () => {
    const update = planProfileChannelUpdate({
      contributionType: 'salary_deduction',
      employerName: 'Acme Ltd',
      requestedOrgId: 'org-1',
      orgIsActive: false,
    });
    expect(update.contribution_method).toBe('payroll');
    expect(update.organization_id).toBeNull();
    expect(update.pending_organization_name).toBe('Acme Ltd');
  });

  test('salary deduction with no organisation id records the free-text employer', () => {
    const update = planProfileChannelUpdate({
      contributionType: 'salary_deduction',
      employerName: '  Acme Ltd  ',
    });
    expect(update.organization_id).toBeNull();
    expect(update.pending_organization_name).toBe('Acme Ltd');
  });

  test('changing employer clears the previous organisation link', () => {
    // The member was linked to an enrolled employer and is now moving to one
    // that is not enrolled. Keeping the old link would leave payroll deducting
    // for the employer they left.
    const update = planProfileChannelUpdate({
      contributionType: 'salary_deduction',
      employerName: 'NewCo',
    });
    expect(update.organization_id).toBeNull();
    expect(update.pending_organization_name).toBe('NewCo');
  });

  test('direct deposit clears any employer link so the payroll exemption cannot linger', () => {
    const update = planProfileChannelUpdate({ contributionType: 'direct_deposit' });
    expect(update.contribution_method).toBe('manual');
    expect(update.contribution_type).toBe('direct_deposit');
    expect(update.organization_id).toBeNull();
    expect(update.pending_organization_name).toBeNull();
  });

  test('an unknown or missing channel leaves the profile untouched', () => {
    expect(planProfileChannelUpdate({})).toBeNull();
    expect(planProfileChannelUpdate({ contributionType: null })).toBeNull();
    expect(planProfileChannelUpdate({ contributionType: 'something_else' })).toBeNull();
  });

  test('salary deduction with no employer still records the channel', () => {
    const update = planProfileChannelUpdate({ contributionType: 'salary_deduction' });
    expect(update.contribution_method).toBe('payroll');
    expect(update.contribution_type).toBe('salary_deduction');
    expect(update.organization_id).toBeUndefined();
    expect(update.pending_organization_name).toBeUndefined();
  });
});
