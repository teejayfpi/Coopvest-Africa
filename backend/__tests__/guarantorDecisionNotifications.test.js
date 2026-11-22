/**
 * Guarantors must be told how a loan they backed was decided.
 *
 * The gap this closes: approval told guarantors, rejection told nobody, and a
 * decision made through the Approval Center told nobody either. A guarantor who
 * consents accepts liability if the borrower defaults, so the moment that
 * liability ends — a refusal — is exactly as important for them to know about
 * as the moment it begins.
 *
 * These drive the real module. Only the two boundaries are faked: the Supabase
 * query builder and the in-app notification transport.
 */

const notified = [];

jest.mock('../src/config/supabase', () => {
  const state = { guarantors: [], error: null };
  const builder = {
    select: () => builder,
    eq: () => builder,
    then: (resolve) => resolve({ data: state.guarantors, error: state.error }),
  };
  const client = { from: () => builder };
  client.__set = (guarantors, error = null) => {
    state.guarantors = guarantors;
    state.error = error;
  };
  return client;
});

jest.mock('../src/services/notifyService', () => ({
  broadcast: async (payload) => {
    // Record one entry per recipient so assertions read like an inbox.
    for (const profileId of payload.profileIds) {
      notified.push({ ...payload, profileId });
    }
    return [{ status: 'sent' }];
  },
}));

const supabase = require('../src/config/supabase');
const {
  notifyGuarantorsOfDecision,
  notifyGuarantorsOfRecovery,
} = require('../src/lib/guarantorNotifications');

const loan = { id: 'loan-1', amount: 500000 };

beforeEach(() => {
  notified.length = 0;
  supabase.__set([]);
});

describe('rejection reaches the guarantors', () => {
  test('a consented guarantor is told the loan was declined', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    const count = await notifyGuarantorsOfDecision(loan, false, 'Insufficient contribution history');

    expect(count).toBe(1);
    expect(notified).toHaveLength(1);
    expect(notified[0].profileId).toBe('g-1');
    expect(notified[0].title).toMatch(/declined/i);
    expect(notified[0].body).toContain('₦500,000');
  });

  test('the rejection tells them their liability has ended', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    await notifyGuarantorsOfDecision(loan, false, null);
    expect(notified[0].body).toMatch(/no longer liable/i);
  });

  test('the borrower\'s rejection reason is not repeated to guarantors', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    await notifyGuarantorsOfDecision(loan, false, 'Borrower has a poor repayment record');
    expect(notified[0].body).not.toMatch(/poor repayment record/i);
  });

  test('a rejection is categorised as a warning, not neutral info', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    await notifyGuarantorsOfDecision(loan, false, null);
    expect(notified[0].category).toBe('warning');
  });
});

describe('approval still reaches the guarantors', () => {
  test('a consented guarantor is told the loan was approved', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    const count = await notifyGuarantorsOfDecision(loan, true, null);

    expect(count).toBe(1);
    expect(notified[0].title).toMatch(/approved/i);
    expect(notified[0].body).toContain('₦500,000');
  });
});

describe('who is notified', () => {
  test('every consenting guarantor is told, exactly once', async () => {
    supabase.__set([
      { guarantor_profile_id: 'g-1', status: 'consented' },
      { guarantor_profile_id: 'g-2', status: 'accepted' },
    ]);
    const count = await notifyGuarantorsOfDecision(loan, false, null);

    expect(count).toBe(2);
    expect(notified.map((n) => n.profileId).sort()).toEqual(['g-1', 'g-2']);
  });

  test('a member listed twice is notified once', async () => {
    supabase.__set([
      { guarantor_profile_id: 'g-1', status: 'consented' },
      { guarantor_profile_id: 'g-1', status: 'consented' },
    ]);
    await notifyGuarantorsOfDecision(loan, false, null);
    expect(notified).toHaveLength(1);
  });

  test('guarantors who declined or withdrew are not told about the outcome', async () => {
    supabase.__set([
      { guarantor_profile_id: 'g-1', status: 'consented' },
      { guarantor_profile_id: 'g-2', status: 'rejected' },
      { guarantor_profile_id: 'g-3', status: 'revoked' },
    ]);
    await notifyGuarantorsOfDecision(loan, false, null);
    expect(notified.map((n) => n.profileId)).toEqual(['g-1']);
  });

  test('rows with no status are treated as bound, so old guarantees are not silent', async () => {
    supabase.__set([{ guarantor_profile_id: 'legacy-1', status: null }]);
    const count = await notifyGuarantorsOfDecision(loan, true, null);
    expect(count).toBe(1);
  });

  test('falls back to the legacy guarantor_id when the profile id is absent', async () => {
    supabase.__set([{ guarantor_profile_id: null, guarantor_id: 'legacy-2', status: 'consented' }]);
    await notifyGuarantorsOfDecision(loan, false, null);
    expect(notified[0].profileId).toBe('legacy-2');
  });

  test('rows with no usable id are skipped rather than throwing', async () => {
    supabase.__set([{ guarantor_profile_id: null, guarantor_id: null, status: 'consented' }]);
    const count = await notifyGuarantorsOfDecision(loan, false, null);
    expect(count).toBe(0);
    expect(notified).toHaveLength(0);
  });
});

describe('the decision is never blocked by a notification problem', () => {
  test('a loan with no guarantors notifies nobody and does not throw', async () => {
    supabase.__set([]);
    await expect(notifyGuarantorsOfDecision(loan, false, null)).resolves.toBe(0);
  });

  test('a guarantor lookup failure is swallowed', async () => {
    supabase.__set([], { message: 'connection reset' });
    await expect(notifyGuarantorsOfDecision(loan, false, null)).resolves.toBe(0);
  });

  test('a loan without an id is a no-op', async () => {
    await expect(notifyGuarantorsOfDecision({}, false, null)).resolves.toBe(0);
  });
});

describe('the guarantor is reached, not just recorded', () => {
  test('push is requested as well as in-app', async () => {
    // An in-app row alone sits unread: a guarantor has no reason to open the
    // app on the day someone else's loan is decided.
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    await notifyGuarantorsOfDecision(loan, true, null);
    expect(notified[0].channels).toEqual(expect.arrayContaining(['in_app', 'push']));
  });

  test('the notification carries the loan id so the app can deep-link', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    await notifyGuarantorsOfDecision(loan, false, null);
    expect(notified[0].data).toEqual({ loanId: 'loan-1', decision: 'rejected' });
  });
});

describe('the message reads correctly without an amount', () => {
  test('falls back to "a loan" when the amount is missing', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    await notifyGuarantorsOfDecision({ id: 'loan-1', amount: 0 }, false, null);
    expect(notified[0].body).toContain('a loan');
  });
});

describe('recovery notices reach guarantors who consented', () => {
  test("a 'consented' guarantor is told when the loan enters recovery", async () => {
    // The worker used to ask the database for status 'accepted'. Consent writes
    // 'consented', so the set was always empty and nobody was told.
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    const n = await notifyGuarantorsOfRecovery(loan);
    expect(n).toBe(1);
    expect(notified[0].title).toBe('Loan Recovery Notice');
    expect(notified[0].body).toMatch(/3 months overdue/);
  });

  test('recovery is pushed, not just stored', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'consented' }]);
    await notifyGuarantorsOfRecovery(loan);
    expect(notified[0].channels).toEqual(expect.arrayContaining(['in_app', 'push']));
  });

  test('a declined guarantor is not told they are in recovery', async () => {
    supabase.__set([{ guarantor_profile_id: 'g-1', status: 'declined' }]);
    expect(await notifyGuarantorsOfRecovery(loan)).toBe(0);
    expect(notified).toHaveLength(0);
  });
});
