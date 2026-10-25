/**
 * `notifyService.sendEmail` used to only log and return `{status:'sent'}`.
 * These tests pin the real behaviour: it delegates to `services/mailer.js` and
 * reports what actually happened, so a caller can never be told an email went
 * out when no transport was configured or the send failed.
 */

const mailer = require('../src/services/mailer');
const notifyService = require('../src/services/notifyService');

describe('notifyService.sendEmail delegates to the real mail transport', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('returns sent with the provider that actually sent it', async () => {
    jest.spyOn(mailer, 'isConfigured').mockReturnValue(true);
    jest.spyOn(mailer, 'hasResend').mockReturnValue(true);
    const send = jest.spyOn(mailer, 'send').mockResolvedValue({ sent: true });

    const result = await notifyService.sendEmail({ to: 'a@b.com', subject: 'Hi', text: 'body' });

    expect(send).toHaveBeenCalledWith({ to: 'a@b.com', subject: 'Hi', text: 'body', html: undefined, replyTo: undefined });
    expect(result).toEqual({ status: 'sent', provider: 'resend' });
  });

  test('reports smtp when Resend is not the transport', async () => {
    jest.spyOn(mailer, 'isConfigured').mockReturnValue(true);
    jest.spyOn(mailer, 'hasResend').mockReturnValue(false);
    jest.spyOn(mailer, 'send').mockResolvedValue({ sent: true });

    const result = await notifyService.sendEmail({ to: 'a@b.com', subject: 'Hi' });

    expect(result).toEqual({ status: 'sent', provider: 'smtp' });
  });

  test('skips without calling the transport when nothing is configured', async () => {
    jest.spyOn(mailer, 'isConfigured').mockReturnValue(false);
    const send = jest.spyOn(mailer, 'send');

    const result = await notifyService.sendEmail({ to: 'a@b.com', subject: 'Hi' });

    expect(send).not.toHaveBeenCalled();
    expect(result).toEqual({ status: 'skipped', reason: 'no_provider' });
  });

  test('surfaces a transport failure instead of claiming success', async () => {
    jest.spyOn(mailer, 'isConfigured').mockReturnValue(true);
    jest.spyOn(mailer, 'send').mockResolvedValue({ sent: false, reason: 'failed', error: 'resend 422' });

    const result = await notifyService.sendEmail({ to: 'a@b.com', subject: 'Hi' });

    expect(result.status).toBe('failed');
    expect(result.error).toBe('resend 422');
  });

  test('skips a message with no recipient', async () => {
    const send = jest.spyOn(mailer, 'send');

    const result = await notifyService.sendEmail({ subject: 'Hi' });

    expect(send).not.toHaveBeenCalled();
    expect(result).toEqual({ status: 'skipped', reason: 'no_recipient' });
  });
});
