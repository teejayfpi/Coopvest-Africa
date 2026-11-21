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
  standingFor,
  consistencyMessage,
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
