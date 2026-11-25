/**
 * The client may choose how a payment is split, but not what a fee costs.
 *
 * Both holes were reproduced against the live API before these guards existed:
 *   - `{ amount: 100, allocations: [fee: 1, savings: 99] }` returned a Paystack
 *     checkout for NGN100, which would have cleared a NGN1,500 administrative
 *     fee (`settleFeeRow` marks the row paid on any positive amount).
 *   - a split summing to more than the amount charged would have credited the
 *     larger figure to the wallet, because the credit is read from the
 *     allocation rather than from the amount paid.
 *
 * These mount the real route so the guards are proven where they run.
 */

const express = require('express');

const state = {
  profile: { id: 'member-1', email: 'member@example.com', registration_fee_paid: true },
  feeTypes: [{ name: 'Administrative Fee', category: 'fee', amount: 1500 }],
  feeRows: [],
  paystackCalls: [],
};

jest.mock('../src/config/supabase', () => {
  const query = (table) => {
    const q = {
      select: () => q,
      eq: () => q,
      in: () => q,
      is: () => q,
      gte: () => q,
      order: () => q,
      limit: () => q,
      // Awaiting the builder resolves the table's rows, which is how the route
      // reads the fee catalogue and any targeted fee row.
      then: (res) => {
        const rows = table === 'fee_types' ? state.feeTypes
          : table === 'member_fees' ? state.feeRows
            : [];
        return Promise.resolve({ data: rows, error: null }).then(res);
      },
      maybeSingle: () => {
        const rows = table === 'fee_types' ? state.feeTypes
          : table === 'member_fees' ? state.feeRows
            : [];
        return Promise.resolve({ data: rows[0] || null, error: null });
      },
      single: () => Promise.resolve({ data: null, error: null }),
      update: () => ({ eq: () => Promise.resolve({ error: null }) }),
      insert: () => Promise.resolve({ error: null }),
    };
    return q;
  };
  return { from: query };
});

jest.mock('../src/middleware/auth', () => ({
  authenticate: (req, _res, next) => {
    req.user = state.profile;
    next();
  },
  requireActivated: (_req, _res, next) => next(),
  requireRegistrationPaid: (_req, _res, next) => next(),
  gateStatusFor: () => ({ activated: true }),
  attachGateStatus: (_req, _res, next) => next(),
}));

jest.mock('../src/services/notifyService', () => ({}));
jest.mock('../src/lib/failedChargeAudit', () => ({ recordFailedCharge: jest.fn() }));

// The gateway must never be reached for a refused payment.
jest.mock('../src/lib/paystackCharge', () => ({
  paystackFetch: jest.fn((path, options) => {
    state.paystackCalls.push({ path, options });
    return Promise.resolve({
      ok: true,
      status: 200,
      payload: {
        status: true,
        data: { authorization_url: 'https://checkout.paystack.com/test', reference: 'ref-1' },
      },
    });
  }),
  paystackVerify: jest.fn(),
}));

const request = require('supertest');
const paymentsRoutes = require('../src/routes/payments');

const app = express();
app.use(express.json());
app.use('/api/v1/payments', paymentsRoutes);

const initialize = (body) => request(app).post('/api/v1/payments/initialize').send(body);

describe('POST /payments/initialize refuses a part-paid fee', () => {
  beforeEach(() => { state.paystackCalls = []; });

  test('NGN1 against a NGN1,500 fee is refused', async () => {
    const res = await initialize({
      amount: 100,
      payment_type: 'other',
      allocation_type: 'mixed',
      allocations: [{ type: 'fee', amount: 1 }, { type: 'savings', amount: 99 }],
    });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('FEE_UNDERPAID');
    expect(res.body.required).toBe(1500);
  });

  test('the gateway is never called for an underpaid fee', async () => {
    await initialize({
      amount: 100,
      payment_type: 'other',
      allocation_type: 'mixed',
      allocations: [{ type: 'fee', amount: 1 }, { type: 'savings', amount: 99 }],
    });
    expect(state.paystackCalls).toHaveLength(0);
  });

  test('the fee paid in full is accepted', async () => {
    const res = await initialize({
      amount: 1500,
      payment_type: 'fee',
      allocation_type: 'fee',
      allocations: [{ type: 'fee', amount: 1500 }],
    });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('a savings-only payment of any size is accepted', async () => {
    // Savings is the member's own money; a small contribution is legitimate.
    const res = await initialize({
      amount: 100,
      payment_type: 'monthly_contribution',
      allocation_type: 'monthly_contribution',
      allocations: [{ type: 'savings', amount: 100 }],
    });
    expect(res.status).toBe(200);
  });
});

describe('POST /payments/initialize refuses a split that exceeds the charge', () => {
  beforeEach(() => { state.paystackCalls = []; });

  test('allocations summing above the amount are refused', async () => {
    const res = await initialize({
      amount: 1000,
      payment_type: 'monthly_contribution',
      allocation_type: 'monthly_contribution',
      allocations: [{ type: 'savings', amount: 5000 }],
    });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('ALLOCATION_MISMATCH');
  });

  test('the gateway is never called for a mismatched split', async () => {
    await initialize({
      amount: 1000,
      payment_type: 'monthly_contribution',
      allocation_type: 'monthly_contribution',
      allocations: [{ type: 'savings', amount: 5000 }],
    });
    expect(state.paystackCalls).toHaveLength(0);
  });
});
