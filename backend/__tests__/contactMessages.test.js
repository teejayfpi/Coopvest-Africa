const {
  validateContactSubmission,
  newContactReference,
  clean,
  TOPICS,
} = require('../src/lib/contactMessages');

/**
 * The public /api/contact endpoint writes an unauthenticated request straight
 * to the database, so this validation is the only guard. These tests pin the
 * reject path (so bad input never reaches a row) and the accept path (so a
 * legitimate enquiry from the live form is never turned away).
 */
describe('website contact submission validation', () => {
  const valid = {
    name: 'Ada Okonkwo',
    email: 'ada@example.com',
    phone: '+234 800 000 0000',
    topic: 'Loan enquiry',
    message: 'Please tell me what I need to qualify for a quick loan.',
    website: '',
  };

  test('accepts a well-formed enquiry and trims it', () => {
    const out = validateContactSubmission({ ...valid, name: '  Ada Okonkwo  ' });
    expect(out.ok).toBe(true);
    expect(out.errors).toEqual({});
    expect(out.honeypot).toBe(false);
    expect(out.value).toEqual({
      name: 'Ada Okonkwo',
      email: 'ada@example.com',
      phone: '+234 800 000 0000',
      topic: 'Loan enquiry',
      message: 'Please tell me what I need to qualify for a quick loan.',
    });
  });

  test('accepts an omitted phone and stores null', () => {
    const out = validateContactSubmission({ ...valid, phone: '' });
    expect(out.ok).toBe(true);
    expect(out.value.phone).toBeNull();
  });

  test.each([
    ['missing name', { name: '' }, 'name'],
    ['one-character name', { name: 'A' }, 'name'],
    ['missing email', { email: '' }, 'email'],
    ['malformed email', { email: 'not-an-email' }, 'email'],
    ['email without TLD', { email: 'a@b' }, 'email'],
    ['malformed phone', { phone: 'phone' }, 'phone'],
    ['unknown topic', { topic: 'Something else' }, 'topic'],
    ['short message', { message: 'too short' }, 'message'],
  ])('rejects %s', (_label, patch, field) => {
    const out = validateContactSubmission({ ...valid, ...patch });
    expect(out.ok).toBe(false);
    expect(out.errors[field]).toBeTruthy();
  });

  test('reports every invalid field at once, not just the first', () => {
    const out = validateContactSubmission({ name: '', email: 'x', topic: 'nope', message: '' });
    expect(Object.keys(out.errors).sort()).toEqual(['email', 'message', 'name', 'topic']);
  });

  test('strips control characters that could smuggle mail headers', () => {
    const out = validateContactSubmission({
      ...valid,
      name: 'Ada\r\nBcc: attacker@example.com',
    });
    expect(out.ok).toBe(true);
    expect(out.value.name).not.toMatch(/[\r\n]/);
  });

  test('length-caps an over-long message instead of rejecting it', () => {
    // A very long legitimate message should be accepted, truncated to the cap.
    const out = validateContactSubmission({ ...valid, message: 'x'.repeat(20000) });
    expect(out.ok).toBe(true);
    expect(out.value.message.length).toBe(5000);
  });

  test('flags a filled honeypot without validating the rest', () => {
    const out = validateContactSubmission({ ...valid, website: 'http://spam.example' });
    expect(out.honeypot).toBe(true);
  });

  test('handles a null or non-object body without throwing', () => {
    expect(validateContactSubmission(null).ok).toBe(false);
    expect(validateContactSubmission('string').ok).toBe(false);
    expect(validateContactSubmission(undefined).ok).toBe(false);
  });

  test('every advertised topic is accepted', () => {
    for (const topic of TOPICS) {
      expect(validateContactSubmission({ ...valid, topic }).ok).toBe(true);
    }
  });

  test('references are unique per millisecond and prefixed', () => {
    expect(newContactReference(1)).toBe('CM-1');
    expect(newContactReference(36)).toMatch(/^CM-/);
  });

  test('clean handles non-strings and collapses control characters to spaces', () => {
    expect(clean(42, 10)).toBe('');
    expect(clean('a\u0000b', 10)).toBe('a b');
  });
});
