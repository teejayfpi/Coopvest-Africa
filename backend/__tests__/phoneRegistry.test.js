/**
 * Who owns a phone number — the lookup shared by every route that has to
 * answer that question.
 *
 * `findPhoneOwner` runs against two database states: before migration 066
 * (`phone_normalized` does not exist, so it must fall back to comparing the
 * stored text) and after (the column answers). Both must give the same answer,
 * or registration behaviour would change silently when the migration lands.
 *
 * The fake client below is a small stand-in for the query builder, not for the
 * logic under test: it records the filters applied and returns a row for them,
 * so these tests assert what SQL would be sent.
 */

const { findPhoneOwner, PHONE_TAKEN_MESSAGE } = require('../src/lib/phoneRegistry');

/**
 * A minimal `.from(table).select().eq/in().limit().maybeSingle()` builder.
 *
 * `rows` is the table contents: [{ id, email, phone }]. `columnMissing`
 * simulates the pre-migration database.
 */
function fakeSupabase(rows, { columnMissing = false, failWith = null } = {}) {
  const queries = [];

  const build = (table) => {
    const q = { table, filters: [] };
    const chain = () => q;

    Object.assign(q, {
      select: chain,
      eq: (col, val) => { q.filters.push(['eq', col, val]); return q; },
      in: (col, val) => { q.filters.push(['in', col, val]); return q; },
      limit: chain,
      order: chain,
      maybeSingle: () => q,
      single: () => q,
      then: (resolve, reject) => {
        if (failWith) return Promise.resolve({ data: null, error: failWith }).then(resolve, reject);

        const usesNormalized = q.filters.some(([kind, col]) => kind === 'eq' && col === 'phone_normalized');
        if (usesNormalized && columnMissing) {
          return Promise.resolve({
            data: null,
            error: { code: '42703', message: 'column profiles.phone_normalized does not exist' },
          }).then(resolve, reject);
        }

        const match = rows.find((row) => {
          return q.filters.every(([kind, col, val]) => {
            if (kind === 'eq' && col === 'phone_normalized') {
              // PostgREST would apply normalize_phone_key(); the trigger keeps
              // the column in step with `phone`, so compare on the key.
              const { phoneLookupKey } = require('../src/lib/phoneNumber');
              return phoneLookupKey(row.phone) === val;
            }
            if (kind === 'eq') return row[col] === val;
            if (kind === 'in') return val.includes(row[col]);
            return true;
          });
        });

        // `.in(...)` is a list query and answers with an array; the single-row
        // forms answer with a row or null. The caller relies on that shape.
        const listQuery = q.filters.some(([kind]) => kind === 'in');
        const data = listQuery ? (match ? [match] : []) : (match || null);
        return Promise.resolve({ data, error: null }).then(resolve, reject);
      },
    });

    queries.push(q);
    return q;
  };

  return { from: build, __queries: queries };
}

// The two live production rows that share one Nigerian line, written two ways.
const DUPLICATED_NUMBER = [
  { id: 'f7fb1fd8', email: 'ayanlowo89@gmail.com', phone: '+2347038193753' },
  { id: 'e9aa3455', email: 'coopvestafrica@gmail.com', phone: '07038193753' },
];

describe('findPhoneOwner', () => {
  test('returns null for a number nobody holds', async () => {
    const supabase = fakeSupabase([{ id: 'a', email: 'a@example.com', phone: '08011112222' }]);
    await expect(findPhoneOwner(supabase, '08099998888')).resolves.toBeNull();
  });

  test('finds the owner when the stored number is in local form', async () => {
    const supabase = fakeSupabase([{ id: 'a', email: 'a@example.com', phone: '07038193753' }]);

    const owner = await findPhoneOwner(supabase, '+2347038193753');

    expect(owner).toMatchObject({ id: 'a' });
  });

  test('finds the owner when the stored number is in international form', async () => {
    const supabase = fakeSupabase([{ id: 'b', email: 'b@example.com', phone: '+2347038193753' }]);

    const owner = await findPhoneOwner(supabase, '07038193753');

    expect(owner).toMatchObject({ id: 'b' });
  });

  test.each([
    ['07038193753'],
    ['+2347038193753'],
    ['2347038193753'],
    ['0703 819 3753'],
    ['+234 703 819 3753'],
  ])('%s is recognised as the number already held', async (input) => {
    const supabase = fakeSupabase([{ id: 'held', email: 'held@example.com', phone: '+2347038193753' }]);
    const owner = await findPhoneOwner(supabase, input);
    expect(owner).toMatchObject({ id: 'held' });
  });

  test('queries the normalised key, not the raw input', async () => {
    const supabase = fakeSupabase([]);
    await findPhoneOwner(supabase, '+234 703 819 3753');

    expect(supabase.__queries[0].filters).toEqual([['eq', 'phone_normalized', '7038193753']]);
  });

  test('returns null without querying when there is no number', async () => {
    const supabase = fakeSupabase([]);
    await expect(findPhoneOwner(supabase, '')).resolves.toBeNull();
    expect(supabase.__queries).toHaveLength(0);
  });

  describe('before migration 066 has been applied', () => {
    test('falls back to the stored text and still finds the owner', async () => {
      const supabase = fakeSupabase(DUPLICATED_NUMBER, { columnMissing: true });

      const owner = await findPhoneOwner(supabase, '07038193753');

      expect(owner).not.toBeNull();
      expect(['e9aa3455', 'f7fb1fd8']).toContain(owner.id);
    });

    test('the fallback compares every notation of the number', async () => {
      const supabase = fakeSupabase(DUPLICATED_NUMBER, { columnMissing: true });
      await findPhoneOwner(supabase, '07038193753');

      const inFilter = supabase.__queries
        .flatMap((q) => q.filters)
        .find(([kind, col]) => kind === 'in' && col === 'phone');

      expect(inFilter[2]).toEqual(
        expect.arrayContaining(['+2347038193753', '2347038193753', '07038193753', '7038193753'])
      );
    });

    test('a free number is still reported free', async () => {
      const supabase = fakeSupabase(DUPLICATED_NUMBER, { columnMissing: true });
      await expect(findPhoneOwner(supabase, '08099998888')).resolves.toBeNull();
    });
  });

  test('a real database error is thrown, never read as "free"', async () => {
    // Returning null here would let a duplicate through on a transient failure,
    // so the caller must see the error.
    const supabase = fakeSupabase([], { failWith: { code: '57014', message: 'statement timeout' } });

    await expect(findPhoneOwner(supabase, '07038193753')).rejects.toThrow(/statement timeout/);
  });
});

describe('PHONE_TAKEN_MESSAGE', () => {
  test('tells the member the number has already been used, and what to do', () => {
    expect(PHONE_TAKEN_MESSAGE).toMatch(/already been used/i);
    expect(PHONE_TAKEN_MESSAGE).toMatch(/log in/i);
  });
});
