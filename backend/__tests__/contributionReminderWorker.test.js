const {
  decideReminder,
  daysSincePreferredDay,
} = require('../src/workers/contributionReminderWorker');

/**
 * Regression guard for the recurring false "overdue" push.
 *
 * Members who had already paid kept receiving:
 *   "Your contribution of ₦5,000 is 24 days overdue. Please pay immediately
 *    to maintain your good standing."
 *
 * The worker now derives the decision from `savings_due`, which already encodes
 * paid-this-month and joined-this-month. These tests pin that a paid or new
 * member produces no reminder at all, and that only genuinely overdue, non-
 * payroll members are told anything.
 */
describe('decideReminder', () => {
  const overdueInput = {
    savingsDue: 5000,
    days: 24,
    contributionMethod: 'manual',
    isFlagged: false,
  };

  test('a member with nothing due is never reminded', () => {
    // Paid this month, joined this month, or no obligation — savings_due is 0.
    expect(decideReminder({ ...overdueInput, savingsDue: 0 })).toBeNull();
    expect(decideReminder({ ...overdueInput, savingsDue: null })).toBeNull();
  });

  test('a payroll member is never told they are overdue', () => {
    for (const method of ['payroll', 'salary_deduction', 'salary-based']) {
      expect(decideReminder({ ...overdueInput, contributionMethod: method })).toBeNull();
    }
  });

  test('a flagged or deactivated member is skipped', () => {
    expect(decideReminder({ ...overdueInput, isFlagged: true })).toBeNull();
  });

  test('a due-but-not-yet-past member is not told they are overdue', () => {
    expect(decideReminder({ ...overdueInput, days: -3 })).toBeNull();
    expect(decideReminder({ ...overdueInput, days: -1 })).toBeNull();
  });

  test('a genuinely overdue member gets the warning, with the real amount', () => {
    const d = decideReminder(overdueInput);
    expect(d.kind).toBe('overdue');
    expect(d.body).toContain('24 days overdue');
    expect(d.body).toContain('5,000');
    // Singular day is not pluralised wrongly.
    expect(decideReminder({ ...overdueInput, days: 1 }).body).toContain('1 day overdue');
  });

  test('a member due today is prompted without calling it overdue', () => {
    const d = decideReminder({ ...overdueInput, days: 0 });
    expect(d.kind).toBe('due_today');
    expect(d.body).not.toContain('overdue');
  });
});

describe('reminder de-dupe tag stays out of the visible text', () => {
  const fs = require('fs');
  const path = require('path');
  const src = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'workers', 'contributionReminderWorker.js'),
    'utf8'
  );

  test('the tag is stored in data, not interpolated into the body', () => {
    // Regression: `${decision.body} [${tag}]` leaked `[reminder:2026-09]` into
    // every member's notification feed.
    expect(src).not.toMatch(/body:\s*`\$\{decision\.body\}\s*\[/);
    expect(src).toContain('data: { tag }');
  });

  test('de-dupe reads the structured tag, not an ILIKE on body', () => {
    expect(src).toContain("eq('data->>tag', tag)");
    expect(src).not.toContain("ilike('body'");
  });
});

describe('daysSincePreferredDay', () => {
  test('a due date later this month is still upcoming', () => {
    const now = new Date(2026, 8, 10); // 10 Sep 2026
    expect(daysSincePreferredDay(25, now)).toBe(-15);
  });

  test('the due date itself is zero', () => {
    expect(daysSincePreferredDay(10, new Date(2026, 8, 10))).toBe(0);
  });

  test('a past due date is positive', () => {
    expect(daysSincePreferredDay(5, new Date(2026, 8, 29))).toBe(24);
  });
});
