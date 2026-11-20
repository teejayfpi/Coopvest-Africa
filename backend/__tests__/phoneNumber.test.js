const {
  normalizePhone,
  phoneLookupKey,
  phoneVariants,
  isNigerianMobile,
} = require('../src/lib/phoneNumber');

/**
 * A phone number may only be used to register once. That rule is only as good
 * as the definition of "same number", so these tests pin the equivalences the
 * live data already contains — the two production accounts that hold
 * 07038193753 and +2347038193753 are the same line, and a rule that treats them
 * as different would pass its own tests while letting the duplicate through.
 */
describe('normalizePhone', () => {
  test.each([
    ['07038193753', '+2347038193753'],
    ['+2347038193753', '+2347038193753'],
    ['2347038193753', '+2347038193753'],
    ['+234 703 819 3753', '+2347038193753'],
    ['0703-819-3753', '+2347038193753'],
    ['7038193753', '+2347038193753'],
    ['(0703) 819 3753', '+2347038193753'],
  ])('%s normalises to %s', (input, expected) => {
    expect(normalizePhone(input)).toBe(expected);
  });

  test('every notation of one number produces one key', () => {
    const keys = new Set(
      ['07038193753', '+2347038193753', '2347038193753', '7038193753'].map(phoneLookupKey)
    );
    expect(keys.size).toBe(1);
    expect([...keys][0]).toBe('7038193753');
  });

  test('different numbers produce different keys', () => {
    expect(phoneLookupKey('08031234567')).not.toBe(phoneLookupKey('08031234568'));
  });

  test('empty and missing input yield null', () => {
    expect(normalizePhone(null)).toBeNull();
    expect(normalizePhone(undefined)).toBeNull();
    expect(normalizePhone('')).toBeNull();
    expect(normalizePhone('   ')).toBeNull();
    expect(phoneLookupKey(null)).toBeNull();
  });
});

describe('isNigerianMobile', () => {
  test.each([
    '07038193753',
    '+2347038193753',
    '08031234567',
    '09031234567',
    '08131234567',
  ])('%s is a valid Nigerian mobile', (n) => {
    expect(isNigerianMobile(n)).toBe(true);
  });

  test.each([
    ['0703819375', 'too short'],
    ['070381937533', 'too long'],
    ['01038193753', 'not a mobile prefix'],
    ['+447031234567', 'not Nigerian'],
    ['not a number', 'not digits'],
    ['', 'empty'],
  ])('%s is rejected (%s)', (n) => {
    expect(isNigerianMobile(n)).toBe(false);
  });
});

describe('phoneVariants', () => {
  test('covers every stored form so a pre-migration lookup matches', () => {
    const variants = phoneVariants('07038193753');
    expect(variants).toEqual(
      expect.arrayContaining(['+2347038193753', '2347038193753', '07038193753', '7038193753'])
    );
  });

  test('is derived from the normalised form, not the input', () => {
    expect(phoneVariants('+234 703 819 3753')).toEqual(phoneVariants('07038193753'));
  });

  test('returns nothing for unusable input', () => {
    expect(phoneVariants('')).toEqual([]);
    expect(phoneVariants(null)).toEqual([]);
  });
});
