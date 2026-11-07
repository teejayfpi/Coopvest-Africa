/**
 * The published fee schedule must be derived from the amounts we charge.
 *
 * `GET /api/v1/fees` is what the corporate website builds its Schedule of
 * Charges page from. If this response were assembled by hand, or if it stopped
 * reading `config/feeDisclosure.js`, the website could quote a figure the app
 * does not charge — the exact drift the disclosure module exists to prevent.
 *
 * The tests below mount the real route and assert the response agrees with the
 * constants and with the terms document the app shows members.
 */

const request = require('supertest');
const express = require('express');

const feeRoutes = require('../src/routes/fees');
const {
  LATE_REPAYMENT_FINE,
  REGISTRATION_FEE,
  MIN_MONTHLY_CONTRIBUTION,
  ADMINISTRATIVE_FEE,
  LOAN_INTEREST_RATES,
} = require('../src/config/feeDisclosure');
const terms = require('../src/config/terms.json');

const app = express();
app.use('/api/v1/fees', feeRoutes);

const get = () => request(app).get('/api/v1/fees');

function chargeById(body, id) {
  const found = (body.charges || []).find((c) => c.id === id);
  if (!found) throw new Error(`no charge '${id}' in the schedule`);
  return found;
}

describe('GET /api/v1/fees', () => {
  test('returns 200 and a success envelope', async () => {
    const res = await get();
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('it is public — no authentication is required', async () => {
    // A visitor reading the price list before joining must not need an account.
    const res = await get();
    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });

  describe('every amount equals the amount we charge', () => {
    test('the registration fee', async () => {
      const { body } = await get();
      expect(chargeById(body, 'registration_fee').amount).toBe(REGISTRATION_FEE);
    });

    test('the minimum monthly contribution', async () => {
      const { body } = await get();
      expect(chargeById(body, 'monthly_contribution').amount).toBe(MIN_MONTHLY_CONTRIBUTION);
    });

    test('the administrative fee, and each levy it is made of', async () => {
      const { body } = await get();
      const admin = chargeById(body, 'administrative_fee');
      expect(admin.amount).toBe(ADMINISTRATIVE_FEE.total);
      expect(admin.components).toEqual(
        ADMINISTRATIVE_FEE.components.map(({ name, amount }) => ({ name, amount })),
      );
    });

    test('the components add up to the total', async () => {
      const { body } = await get();
      const admin = chargeById(body, 'administrative_fee');
      const sum = admin.components.reduce((acc, c) => acc + c.amount, 0);
      expect(sum).toBe(admin.amount);
    });

    test('the late repayment fine', async () => {
      const { body } = await get();
      expect(chargeById(body, 'late_repayment_fine').amount).toBe(LATE_REPAYMENT_FINE);
    });
  });

  test('the loan interest rates match the rates we charge', async () => {
    const { body } = await get();
    const published = Object.fromEntries(body.loan_interest_rates.map((r) => [r.product, r.rate]));
    expect(published).toEqual(LOAN_INTEREST_RATES);
  });

  test('the schedule carries the same version as the terms document', async () => {
    const { body } = await get();
    expect(body.version).toBe(terms.version);
  });

  test('the schedule hash changes when an amount changes', () => {
    // Guards the revision marker: a consumer caches on it, so it must be a
    // function of the content rather than a constant.
    const before = feeRoutes.scheduleHash(feeRoutes.buildSchedule());
    const mutated = { ...feeRoutes.buildSchedule(), charges: [] };
    expect(feeRoutes.scheduleHash(mutated)).not.toBe(before);
  });

  test('it states which charges do not apply', async () => {
    const { body } = await get();
    const text = (body.not_charged || []).join(' ').toLowerCase();
    expect(text).toContain('withdrawal');
    expect(text).toContain('early-repayment');
  });

  test('no amount appears in prose — figures live only in the amount field', async () => {
    // A naira sign in a note is a figure that can disagree with the field
    // beside it, which is the failure this whole module exists to prevent.
    const { body } = await get();
    for (const charge of body.charges) {
      expect(charge.note || '').not.toMatch(/₦/);
    }
  });
});
