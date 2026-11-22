/**
 * Contribution consistency.
 *
 * The scenario under test throughout: a member contributed six months in a row
 * (so they qualified for a loan), then stopped. `countContributionMonths` still
 * reports six and lets them borrow again; these rules are what notice the stop.
 */
const {
  monthKey,
  shiftMonth,
  paidMonths,
  assessConsistency,
  assessEligibility,
  eligibilityRefusal,
  eligibilityMessage,
  longestStreak,
  standingFor,
  consistencyMessage,
  parseVersion,
  versionAtLeast,
  policyAppliesTo,
  POLICY,
  CONTRIBUTION_TRANSACTION_TYPES,
} = require('../src/lib/contributionConsistency');

const paid = (month) => ({ status: 'completed', contribution_month: `${month}-01` });

describe('month helpers', () => {
  test('monthKey normalises a date to year-month', () => {
    expect(monthKey('2026-03-15T10:00:00Z')).toBe('2026-03');
  });

  test('shiftMonth crosses a year boundary backwards', () => {
    expect(shiftMonth('2026-01', -1)).toBe('2025-12');
  });

  test('shiftMonth crosses a year boundary forwards', () => {
    expect(shiftMonth('2026-12', 1)).toBe('2027-01');
  });
});

describe('paidMonths', () => {
  test('ignores unpaid and failed contributions', () => {
    const months = paidMonths([
      { status: 'pending', contribution_month: '2026-01-01' },
      { status: 'failed', contribution_month: '2026-02-01' },
      { status: 'completed', contribution_month: '2026-03-01' },
    ]);
    expect([...months]).toEqual(['2026-03']);
  });

  test('counts wallet deposits, which write no contributions row', () => {
    const months = paidMonths([], [{ created_at: '2026-04-10T00:00:00Z' }]);
    expect([...months]).toEqual(['2026-04']);
  });

  test('counts a month once even if paid twice', () => {
    const months = paidMonths([paid('2026-05'), paid('2026-05')]);
    expect(months.size).toBe(1);
  });
});

describe('assessConsistency — the member who stopped', () => {
  // Six consecutive months, then nothing. "Now" is four months later.
  const sixThenStop = ['2026-01', '2026-02', '2026-03', '2026-04', '2026-05', '2026-06'].map(paid);
  const now = new Date('2026-11-15T00:00:00Z');

  test('reports the historical run', () => {
    const a = assessConsistency({ contributions: sixThenStop, now });
    expect(a.paidMonths).toBe(6);
    expect(a.streak).toBe(6);
  });

  test('reports that they are not in good standing', () => {
    const a = assessConsistency({ contributions: sixThenStop, now });
    expect(a.inGoodStanding).toBe(false);
    expect(a.currentStreak).toBe(0);
  });

  test('measures how far behind they are', () => {
    const a = assessConsistency({ contributions: sixThenStop, now });
    expect(a.monthsSinceLast).toBe(5);
  });

  test('escalates to review after three months', () => {
    const a = assessConsistency({ contributions: sixThenStop, now });
    expect(standingFor(a.currentStreak, a.monthsSinceLast)).toBe('review');
  });

  test('tells them what is wrong and how to fix it', () => {
    const a = assessConsistency({ contributions: sixThenStop, now });
    const message = consistencyMessage(a);
    expect(message).toContain('5 months behind');
    expect(message).toContain('resumes as soon as');
  });
});

describe('assessConsistency — good standing', () => {
  test('a member who paid this month is in good standing', () => {
    const a = assessConsistency({
      contributions: [paid('2026-09'), paid('2026-10'), paid('2026-11')],
      now: new Date('2026-11-20T00:00:00Z'),
    });
    expect(a.inGoodStanding).toBe(true);
    expect(a.currentStreak).toBe(3);
    expect(standingFor(a.currentStreak, a.monthsSinceLast)).toBe('good');
  });

  test('does not treat an unpaid current month as arrears during grace', () => {
    const a = assessConsistency({
      contributions: [paid('2026-09'), paid('2026-10')],
      now: new Date('2026-11-05T00:00:00Z'),
      graceDays: 10,
    });
    expect(a.graceActive).toBe(true);
    expect(a.inGoodStanding).toBe(true);
    expect(a.currentStreak).toBe(2);
  });

  test('treats the same member as behind once grace has passed', () => {
    const a = assessConsistency({
      contributions: [paid('2026-09'), paid('2026-10')],
      now: new Date('2026-11-20T00:00:00Z'),
      graceDays: 10,
    });
    expect(a.graceActive).toBe(false);
    expect(a.inGoodStanding).toBe(false);
  });

  test('a gap breaks the streak even if they paid this month', () => {
    const a = assessConsistency({
      contributions: [paid('2026-08'), paid('2026-11')],
      now: new Date('2026-11-20T00:00:00Z'),
    });
    expect(a.currentStreak).toBe(1);
    expect(a.streak).toBe(1);
  });
});

describe('assessConsistency — edge cases', () => {
  test('a member with no contributions at all', () => {
    const a = assessConsistency({ contributions: [], now: new Date('2026-11-20T00:00:00Z') });
    expect(a.paidMonths).toBe(0);
    expect(a.inGoodStanding).toBe(false);
    expect(standingFor(a.currentStreak, a.monthsSinceLast)).toBe('never_contributed');
  });

  test('one month behind is a warning, not a restriction', () => {
    expect(standingFor(0, 1)).toBe('warning');
  });

  test('two months behind is a restriction', () => {
    expect(standingFor(0, 2)).toBe('restricted');
  });
});

describe('consent gating — the rule only applies to members who accepted it', () => {
  test('an application carrying the disclosing version is subject to the check', () => {
    expect(policyAppliesTo(POLICY.version)).toBe(true);
  });

  test('an older agreement is not subject to the check', () => {
    // v1.0 is what shipped before the clause existed.
    expect(policyAppliesTo('v1.0')).toBe(false);
  });

  test('a later agreement version stays subject to the check', () => {
    expect(policyAppliesTo('v1.2')).toBe(true);
    expect(policyAppliesTo('v2.0')).toBe(true);
  });

  test('a missing or unparseable version never enforces the rule', () => {
    // Absent consent must fail closed towards the member, not against them.
    expect(policyAppliesTo(undefined)).toBe(false);
    expect(policyAppliesTo(null)).toBe(false);
    expect(policyAppliesTo('')).toBe(false);
    expect(policyAppliesTo('garbage')).toBe(false);
  });

  test('version comparison is numeric, not lexical', () => {
    // "v1.10" must be newer than "v1.9"; a string compare would invert them.
    expect(versionAtLeast('v1.10', 'v1.9')).toBe(true);
    expect(versionAtLeast('v1.9', 'v1.10')).toBe(false);
  });

  test('parseVersion tolerates a missing v prefix', () => {
    expect(parseVersion('1.1')).toEqual([1, 1]);
    expect(parseVersion('v1.1')).toEqual([1, 1]);
  });
});

describe('contribution transaction types', () => {
  test('covers every flow that credits savings, not just wallet deposits', () => {
    // Payroll batches write salary_deduction; counting only savings_deposit
    // reported payroll members as never having contributed.
    for (const type of ['deposit', 'savings_deposit', 'transfer_in', 'salary_deduction', 'contribution']) {
      expect(CONTRIBUTION_TRANSACTION_TYPES).toContain(type);
    }
  });
});


/**
 * The agreed eligibility rule: six consecutive months of contributions with no
 * month missed, still up to date at the time of application.
 *
 * The bug these guard: eligibility used to count *distinct* months ever paid,
 * so a member who paid six months and then lapsed still qualified, and a member
 * with a gap in the middle also qualified.
 */
describe('assessEligibility — six consecutive months, no month missed', () => {
  const now = new Date('2026-11-20T12:00:00Z');
  // Months counting back from the current month: 0 = this month, 1 = last, ...
  const monthBack = (n) => {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - n, 15));
    return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
  };
  const months = (...backs) => backs.map((n) => paid(monthBack(n)));

  test('six consecutive months including this month is eligible', () => {
    const v = assessEligibility({ contributions: months(0, 1, 2, 3, 4, 5), now });
    expect(v.eligible).toBe(true);
    expect(v.longestStreak).toBe(6);
    expect(v.reason).toBeNull();
  });

  test('six consecutive months but stopped two months ago is NOT eligible', () => {
    // The reported bug: this member was approved because the count of distinct
    // months was still six.
    const v = assessEligibility({ contributions: months(2, 3, 4, 5, 6, 7), now });
    expect(v.longestStreak).toBe(6);
    expect(v.inGoodStanding).toBe(false);
    expect(v.eligible).toBe(false);
    expect(v.reason).toBe('CONTRIBUTIONS_NOT_CURRENT');
  });

  test('six months with a three-month gap in the middle is NOT eligible', () => {
    // Paid this month, but missed a stretch mid-history. Counting distinct
    // months scored this 6; the longest unbroken run is only 3.
    const v = assessEligibility({ contributions: months(0, 1, 2, 6, 7, 8), now });
    expect(v.paidMonths).toBe(6);
    expect(v.longestStreak).toBe(3);
    expect(v.eligible).toBe(false);
    expect(v.reason).toBe('INSUFFICIENT_CONSECUTIVE_MONTHS');
  });

  test('five consecutive months is not enough', () => {
    const v = assessEligibility({ contributions: months(0, 1, 2, 3, 4), now });
    expect(v.longestStreak).toBe(5);
    expect(v.eligible).toBe(false);
    expect(v.reason).toBe('INSUFFICIENT_CONSECUTIVE_MONTHS');
  });

  test('six months but last month missed is NOT eligible', () => {
    const v = assessEligibility({ contributions: months(1, 2, 3, 4, 5, 6), now });
    expect(v.longestStreak).toBe(6);
    expect(v.eligible).toBe(false);
    expect(v.reason).toBe('CONTRIBUTIONS_NOT_CURRENT');
  });

  test('a longer run qualifies', () => {
    const v = assessEligibility({ contributions: months(0, 1, 2, 3, 4, 5, 6, 7, 8), now });
    expect(v.longestStreak).toBe(9);
    expect(v.eligible).toBe(true);
  });

  test('no contributions at all is not eligible and does not crash', () => {
    const v = assessEligibility({ contributions: [], now });
    expect(v.longestStreak).toBe(0);
    expect(v.eligible).toBe(false);
    expect(v.reason).toBe('INSUFFICIENT_CONSECUTIVE_MONTHS');
  });

  test('a run served earlier still counts once the member is up to date again', () => {
    // Six consecutive months, then one missed month, then paid again. The
    // qualifying run is intact and the member is current, so they qualify.
    const v = assessEligibility({ contributions: months(0, 2, 3, 4, 5, 6, 7), now });
    expect(v.longestStreak).toBe(6);
    expect(v.inGoodStanding).toBe(true);
    expect(v.eligible).toBe(true);
  });

  test('the grace period still applies to the current month', () => {
    const early = new Date('2026-11-05T12:00:00Z');
    const contributions = [1, 2, 3, 4, 5, 6].map((n) => {
      const d = new Date(Date.UTC(early.getUTCFullYear(), early.getUTCMonth() - n, 15));
      return paid(`${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`);
    });
    const v = assessEligibility({ contributions, now: early });
    expect(v.graceActive).toBe(true);
    expect(v.eligible).toBe(true);
  });

  test('past the grace period, an unpaid current month breaks eligibility', () => {
    const late = new Date('2026-11-20T12:00:00Z');
    const contributions = [1, 2, 3, 4, 5, 6].map((n) => {
      const d = new Date(Date.UTC(late.getUTCFullYear(), late.getUTCMonth() - n, 15));
      return paid(`${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`);
    });
    const v = assessEligibility({ contributions, now: late });
    expect(v.graceActive).toBe(false);
    expect(v.eligible).toBe(false);
    expect(v.reason).toBe('CONTRIBUTIONS_NOT_CURRENT');
  });

  test('wallet and payroll deposits count towards the run', () => {
    // These flows write no contributions row; ignoring them would report a
    // payroll member as never having paid.
    const deposits = [0, 1, 2, 3, 4, 5].map((n) => ({ created_at: `${monthBack(n)}-10T09:00:00Z` }));
    const v = assessEligibility({ contributions: [], deposits, now });
    expect(v.longestStreak).toBe(6);
    expect(v.eligible).toBe(true);
  });

  test('a gap in deposit months also breaks the run', () => {
    // Runs are 0-1 (two months) and 4-7 (four months); the longest is four.
    const deposits = [0, 1, 4, 5, 6, 7].map((n) => ({ created_at: `${monthBack(n)}-10T09:00:00Z` }));
    const v = assessEligibility({ contributions: [], deposits, now });
    expect(v.longestStreak).toBe(4);
    expect(v.eligible).toBe(false);
  });
});

describe('longestStreak', () => {
  test('is zero for no months', () => {
    expect(longestStreak(new Set())).toBe(0);
    expect(longestStreak(null)).toBe(0);
  });

  test('handles a single month', () => {
    expect(longestStreak(new Set(['2026-01']))).toBe(1);
  });

  test('spans a year boundary', () => {
    const months = new Set(['2025-11', '2025-12', '2026-01', '2026-02']);
    expect(longestStreak(months)).toBe(4);
  });

  test('finds the longest run, not the last one', () => {
    const months = new Set(['2026-01', '2026-02', '2026-03', '2026-04', '2026-06']);
    expect(longestStreak(months)).toBe(4);
  });
});

describe('eligibilityMessage', () => {
  const now = new Date('2026-11-20T12:00:00Z');
  const monthBack = (n) => {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - n, 15));
    return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
  };

  test('explains a short run and names the member\'s actual run', () => {
    const v = assessEligibility({ contributions: [0, 1, 2].map((n) => paid(monthBack(n))), now });
    const msg = eligibilityMessage(v);
    expect(msg).toContain('6 consecutive months');
    expect(msg).toContain('longest unbroken run is 3 months');
  });

  test('explains a lapse in terms of months behind', () => {
    const v = assessEligibility({ contributions: [2, 3, 4, 5, 6, 7].map((n) => paid(monthBack(n))), now });
    expect(eligibilityMessage(v)).toContain('behind');
  });
});


/**
 * A refusal has to tell the member what to do, not just that they failed.
 * There is no eligibility screen in the app, so this text is the only place a
 * refused member learns the remedy.
 */
describe('eligibilityRefusal — reason, remedy, and where to read the rule', () => {
  const now = new Date('2026-11-20T12:00:00Z');
  const monthBack = (n) => {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - n, 15));
    return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
  };
  const months = (...backs) => backs.map((n) => paid(monthBack(n)));

  describe('too few consecutive months', () => {
    const verdict = assessEligibility({ contributions: months(0, 1, 2), now });
    const refusal = eligibilityRefusal(verdict);

    test('states the rule and the member\'s own run', () => {
      expect(refusal.code).toBe('INSUFFICIENT_CONSECUTIVE_MONTHS');
      expect(refusal.reason).toContain('6 consecutive months');
      expect(refusal.reason).toContain('3 months');
    });

    test('tells the member how to become eligible', () => {
      expect(refusal.guidance).toContain('Keep contributing every month');
      expect(refusal.guidance).toContain('6 consecutive months');
    });

    test('explains that a gap resets the count', () => {
      expect(refusal.guidance.toLowerCase()).toContain('breaks the run');
      expect(refusal.guidance.toLowerCase()).toContain('restarts');
    });

    test('cites the Loan Policy', () => {
      expect(refusal.termsSectionId).toBe('loan_policy');
      expect(refusal.termsSectionTitle).toBe('Loan Policy');
    });
  });

  describe('never contributed', () => {
    const refusal = eligibilityRefusal(assessEligibility({ contributions: [], now }));

    test('does not accuse a new member of being behind', () => {
      expect(refusal.guidance).not.toMatch(/behind/i);
      expect(refusal.reason).toContain('0 months');
    });

    test('invites them to start contributing', () => {
      expect(refusal.guidance).toContain('first contribution starts your record');
    });
  });

  describe('contributions lapsed', () => {
    const verdict = assessEligibility({ contributions: months(2, 3, 4, 5, 6, 7), now });
    const refusal = eligibilityRefusal(verdict);

    test('says how far behind the member is', () => {
      expect(refusal.code).toBe('CONTRIBUTIONS_NOT_CURRENT');
      expect(refusal.reason).toContain('2 months behind');
    });

    test('tells them to pay up and that borrowing then resumes', () => {
      expect(refusal.guidance).toContain('Pay the outstanding');
      expect(refusal.guidance).toContain('resumes automatically');
    });

    test('reassures that a lapse carries no penalty', () => {
      expect(refusal.guidance.toLowerCase()).toContain('no penalty');
    });

    test('cites the Contribution Policy', () => {
      expect(refusal.termsSectionId).toBe('contribution_policy');
    });
  });

  test('an eligible member gets no refusal', () => {
    const verdict = assessEligibility({ contributions: months(0, 1, 2, 3, 4, 5), now });
    expect(eligibilityRefusal(verdict)).toBeNull();
  });

  describe('the message the member actually reads', () => {
    test('carries the reason, the remedy and a pointer to the terms', () => {
      const msg = eligibilityMessage(assessEligibility({ contributions: months(0, 1, 2), now }));
      expect(msg).toContain('6 consecutive months');      // reason
      expect(msg).toContain('What to do:');                // remedy heading
      expect(msg).toContain('Keep contributing');          // remedy
      expect(msg).toContain('Terms & Conditions');         // where to read it
      expect(msg).toContain('Loan Policy');                // which section
    });

    test('the lapsed message points at the Contribution Policy', () => {
      const msg = eligibilityMessage(
        assessEligibility({ contributions: months(2, 3, 4, 5, 6, 7), now }),
      );
      expect(msg).toContain('Contribution Policy');
      expect(msg).toContain('Terms & Conditions');
    });

    test('every refusal names a real section of the published terms', () => {
      const terms = require('../src/config/terms.json');
      const ids = new Set(terms.sections.map((s) => s.id));
      const cases = [[], months(0, 1, 2), months(2, 3, 4, 5, 6, 7)];
      for (const contributions of cases) {
        const refusal = eligibilityRefusal(assessEligibility({ contributions, now }));
        expect(ids.has(refusal.termsSectionId)).toBe(true);
      }
    });

    test('the cited section actually contains the rule', () => {
      const terms = require('../src/config/terms.json');
      const loanPolicy = terms.sections.find((s) => s.id === 'loan_policy');
      expect(loanPolicy.body).toContain('six (6) consecutive months');
    });
  });
});
