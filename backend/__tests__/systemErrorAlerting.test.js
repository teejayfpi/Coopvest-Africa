/**
 * Operator alerting for server errors.
 *
 * Before this, a 5xx was written to the log and to audit_logs and seen by
 * nobody, so a failing endpoint stayed invisible until a member reported it.
 * These tests pin the two things that make the alerting safe to have on the
 * error path: it never throws, and it does not flood.
 */

// Read at require time, so set before requiring the service.
process.env.ALERT_WEBHOOK_URL = 'https://example.invalid/hook';
process.env.SYSTEM_ALERT_MIN_INTERVAL_MS = '10';

const alertService = require('../src/services/alertService');
const errorHandler = require('../src/middleware/errorHandler');

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

describe('sendSystemErrorAlert', () => {
  beforeEach(() => {
    alertService.sendWebhookAlert = jest.fn().mockResolvedValue(undefined);
    alertService._lastSystemAlertAt = 0;
    alertService._suppressedSystemAlerts = 0;
  });

  test('sends an alert through the webhook channel', async () => {
    await alertService.sendSystemErrorAlert({ title: 'GET /x failed', message: 'boom' });
    expect(alertService.sendWebhookAlert).toHaveBeenCalledTimes(1);
    const payload = alertService.sendWebhookAlert.mock.calls[0][0];
    expect(payload.title).toBe('GET /x failed');
    expect(payload.message).toContain('boom');
  });

  test('a burst is collapsed into one alert that reports the count', async () => {
    // A failing dependency makes every request 5xx at once. Without the floor
    // the channel is flooded and gets muted exactly when it matters.
    for (let i = 0; i < 50; i += 1) {
      await alertService.sendSystemErrorAlert({ title: 't', message: 'm' });
    }
    expect(alertService.sendWebhookAlert).toHaveBeenCalledTimes(1);
    expect(alertService._suppressedSystemAlerts).toBe(49);

    // The next alert after the window carries the suppressed count forward.
    await new Promise((r) => setTimeout(r, 15));
    await alertService.sendSystemErrorAlert({ title: 't', message: 'm' });
    expect(alertService.sendWebhookAlert).toHaveBeenCalledTimes(2);
    expect(alertService.sendWebhookAlert.mock.calls[1][0].message).toContain('49 further error');
  });

  test('never throws when the webhook itself fails', async () => {
    // This runs on the error path: a failed alert must not become a second
    // error, and must not stop the response.
    alertService.sendWebhookAlert = jest.fn().mockRejectedValue(new Error('network down'));
    await expect(
      alertService.sendSystemErrorAlert({ title: 't', message: 'm' })
    ).resolves.toBeUndefined();
  });
});

describe('errorHandler', () => {
  beforeEach(() => {
    jest.spyOn(alertService, 'sendSystemErrorAlert').mockResolvedValue(undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  test('a 5xx alerts operators', async () => {
    const req = { method: 'POST', path: '/api/x', user: { userId: 'u1' }, ip: '1.2.3.4' };
    await errorHandler(new Error('kaboom'), req, mockRes(), jest.fn());
    await flush();
    expect(alertService.sendSystemErrorAlert).toHaveBeenCalledTimes(1);
  });

  test('a 4xx does not alert, so ordinary client mistakes stay quiet', async () => {
    // A bad request is not an incident. Alerting on it would train operators to
    // ignore the channel.
    const req = { method: 'POST', path: '/api/x', user: { userId: 'u1' }, ip: '1.2.3.4' };
    const err = new Error('bad input');
    err.name = 'ValidationError';
    await errorHandler(err, req, mockRes(), jest.fn());
    await flush();
    expect(alertService.sendSystemErrorAlert).not.toHaveBeenCalled();
  });

  test('the response is still sent even if alerting throws', async () => {
    alertService.sendSystemErrorAlert.mockRejectedValue(new Error('alert failed'));
    const req = { method: 'GET', path: '/api/y', user: {}, ip: '1.2.3.4' };
    const res = mockRes();
    await errorHandler(new Error('kaboom'), req, res, jest.fn());
    await flush();
    expect(res.status).toHaveBeenCalledWith(500);
  });
});
