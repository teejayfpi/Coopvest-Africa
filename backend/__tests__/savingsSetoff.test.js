/**
 * Set-off planning.
 *
 * The ordering rules are the substance here: the borrower's own savings are
 * taken first, and a guarantor is never asked for more than they pledged at
 * consent. Those two guarantees are what make the recovery defensible, so they
 * are tested directly rather than inferred from a total.
 */
const {
  planSetOff,
  isEligibleForSetOff,
  setOffNotice,
} = require('../src/lib/savingsSetoff');

const BORROWER = 'borrower-1';

describe('planSetOff', () => {
  test('takes the borrower savings first', () => {
    const plan = planSetOff({
      outstanding: 250000,
      borrowerProfileId: BORROWER,
      borrowerSavings: 100000,
      guarantors: [
        { profileId: 'g1', savings: 90000, pledged: 83334 },
        { profileId: 'g2', savings: 90000, pledged: 83334 },
      ],
    });
    expect(plan.steps[0]).toEqual({ profileId: BORROWER, role: 'borrower', amount: 100000 });
  });

  test('stops asking guarantors once the loan is settled', () => {
    const plan = planSetOff({
      outstanding: 150000,
      borrowerProfileId: BORROWER,
      borrowerSavings: 100000,
      guarantors: [
        { profileId: 'g1', savings: 90000, pledged: 83334 },
        { profileId: 'g2', savings: 90000, pledged: 83334 },
      ],
    });
    // 100,000 from the borrower leaves 50,000, which the first guarantor covers.
    expect(plan.steps).toHaveLength(2);
    expect(plan.steps[1]).toEqual({ profileId: 'g1', role: 'guarantor', amount: 50000 });
    expect(plan.shortfall).toBe(0);
    expect(plan.exhausted).toBe(false);
  });

  test('never takes more from a guarantor than they pledged', () => {
    const plan = planSetOff({
      outstanding: 300000,
      borrowerProfileId: BORROWER,
      borrowerSavings: 0,
      guarantors: [
        { profileId: 'g1', savings: 500000, pledged: 83334 },
      ],
    });
    expect(plan.steps[0].amount).toBe(83334);
  });

  test('takes only what a guarantor actually holds when that is less than the pledge', () => {
    const plan = planSetOff({
      outstanding: 300000,
      borrowerProfileId: BORROWER,
      borrowerSavings: 0,
      guarantors: [{ profileId: 'g1', savings: 12000, pledged: 83334 }],
    });
    expect(plan.steps[0].amount).toBe(12000);
  });

  test('reports the shortfall when every source is exhausted', () => {
    const plan = planSetOff({
      outstanding: 300000,
      borrowerProfileId: BORROWER,
      borrowerSavings: 50000,
      guarantors: [
        { profileId: 'g1', savings: 40000, pledged: 83334 },
        { profileId: 'g2', savings: 0, pledged: 83334 },
      ],
    });
    expect(plan.recovered).toBe(90000);
    expect(plan.shortfall).toBe(210000);
    expect(plan.exhausted).toBe(true);
  });

  test('skips a guarantor with no savings and no pledge', () => {
    const plan = planSetOff({
      outstanding: 100000,
      borrowerProfileId: BORROWER,
      borrowerSavings: 0,
      guarantors: [
        { profileId: 'g1', savings: 0, pledged: 0 },
        { profileId: 'g2', savings: 100000, pledged: 100000 },
      ],
    });
    expect(plan.steps).toHaveLength(1);
    expect(plan.steps[0].profileId).toBe('g2');
  });

  test('plans nothing when the loan owes nothing', () => {
    const plan = planSetOff({
      outstanding: 0,
      borrowerProfileId: BORROWER,
      borrowerSavings: 100000,
      guarantors: [{ profileId: 'g1', savings: 50000, pledged: 40000 }],
    });
    expect(plan.steps).toHaveLength(0);
    expect(plan.shortfall).toBe(0);
  });

  test('never exceeds the outstanding balance in total', () => {
    const plan = planSetOff({
      outstanding: 100000,
      borrowerProfileId: BORROWER,
      borrowerSavings: 60000,
      guarantors: [{ profileId: 'g1', savings: 60000, pledged: 60000 }],
    });
    expect(plan.recovered).toBe(100000);
  });
});

describe('isEligibleForSetOff', () => {
  test.each(['overdue', 'defaulted', 'in_recovery'])('allows %s', (status) => {
    expect(isEligibleForSetOff({ status })).toBe(true);
  });

  test.each(['active', 'repaying', 'approved', 'completed', 'pending'])(
    'refuses %s — the member is still paying or has paid',
    (status) => {
      expect(isEligibleForSetOff({ status })).toBe(false);
    },
  );

  test('refuses a missing loan', () => {
    expect(isEligibleForSetOff(null)).toBe(false);
  });
});

describe('setOffNotice', () => {
  test('names the amount, the loan and the notice period', () => {
    const notice = setOffNotice({ amount: 250000, loanReference: 'LN-123', daysUntil: 14 });
    expect(notice).toContain('₦250,000');
    expect(notice).toContain('LN-123');
    expect(notice).toContain('14 days');
    expect(notice).toContain('recovery');
  });
});
