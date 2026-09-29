const { classifyFailure } = require('../src/lib/paystackCharge');

/**
 * Guards the rule that a failed charge which may have debited the member is
 * never treated as "no money moved".
 *
 * The behaviour these pin down: a `reversed` or `failed` event must be flagged
 * possibleDebit so it reaches the admin queue, while an abandoned checkout is
 * recorded quietly and produces no admin alarm.
 */
describe('classifyFailure', () => {
  test('a reversal is a debit, and is actionable', () => {
    const r = classifyFailure({ eventName: 'transfer.reversed' });
    expect(r.gatewayStatus).toBe('reversed');
    expect(r.possibleDebit).toBe(true);
    expect(r.alertAdmins).toBe(true);
  });

  test('a failed charge is treated as a possible debit', () => {
    const r = classifyFailure({ eventName: 'charge.failed', status: 'failed', gatewayResponse: 'Declined' });
    expect(r.gatewayStatus).toBe('failed');
    expect(r.possibleDebit).toBe(true);
    expect(r.alertAdmins).toBe(true);
    expect(r.gatewayMessage).toBe('Declined');
  });

  test('an abandoned checkout is recorded but does not alarm admins', () => {
    const r = classifyFailure({ eventName: 'charge.failed', status: 'abandoned' });
    expect(r.gatewayStatus).toBe('abandoned');
    expect(r.possibleDebit).toBe(false);
    expect(r.alertAdmins).toBe(false);
  });

  test('defaults to failed when the gateway gives no status', () => {
    const r = classifyFailure({ eventName: 'charge.failed' });
    expect(r.gatewayStatus).toBe('failed');
    expect(r.possibleDebit).toBe(true);
  });

  test('a reversal event wins over a stale success-looking status field', () => {
    // Paystack's transfer.reversed payload can carry status 'reversed' or a
    // blank/odd status; the event name is authoritative.
    const r = classifyFailure({ eventName: 'transfer.reversed', status: undefined });
    expect(r.gatewayStatus).toBe('reversed');
    expect(r.possibleDebit).toBe(true);
  });
});

describe('paystack charge modules load', () => {
  // A cycle through server.js / auth middleware would throw on require, so this
  // asserts the new shared modules are safe to import standalone.
  test('shared modules require cleanly', () => {
    expect(typeof require('../src/lib/paystackCharge').verifyCharge).toBe('function');
    expect(typeof require('../src/lib/failedChargeAudit').recordFailedCharge).toBe('function');
    expect(typeof require('../src/lib/failedChargeAudit').alertFailedCharge).toBe('function');
    expect(typeof require('../src/workers/failedChargeReconcileWorker').processSweep).toBe('function');
  });
});
