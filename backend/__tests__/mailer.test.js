/**
 * The mailer must really send, and must pick the transport that can reach the
 * network. Render's free plan blocks outbound SMTP, so a regression that drops
 * the Resend path (or prefers SMTP over it) silently breaks admin replies —
 * which is exactly the bug these tests exist to catch.
 *
 * The Resend tests point RESEND_BASE_URL at a real local HTTP server, so the
 * production send path is exercised without stubbing fetch.
 */
const http = require('http');

function startServer(handler) {
  return new Promise((resolve) => {
    const server = http.createServer(handler);
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

function collect(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => resolve(body));
  });
}

const MAIL_VARS = [
  'RESEND_API_KEY',
  'RESEND_BASE_URL',
  'SMTP_HOST',
  'SMTP_PORT',
  'SMTP_SECURE',
  'SMTP_USER',
  'SMTP_PASS',
  'CONTACT_FROM',
  'SMTP_FROM',
];

function clearMailEnv() {
  MAIL_VARS.forEach((k) => delete process.env[k]);
}

describe('mailer', () => {
  let mailer;
  const saved = {};

  beforeAll(() => {
    MAIL_VARS.forEach((k) => (saved[k] = process.env[k]));
    clearMailEnv();
    jest.resetModules();
    mailer = require('../src/services/mailer');
  });

  afterAll(() => {
    clearMailEnv();
    MAIL_VARS.forEach((k) => {
      if (saved[k] !== undefined) process.env[k] = saved[k];
    });
  });

  beforeEach(() => clearMailEnv());

  test('reports not_configured when no transport is set, and does not throw', async () => {
    expect(mailer.isConfigured()).toBe(false);
    const result = await mailer.send({ to: 'a@example.com', subject: 's', text: 't' });
    expect(result).toEqual({ sent: false, reason: 'not_configured' });
  });

  test('isConfigured accepts Resend on its own, without any SMTP variables', () => {
    process.env.RESEND_API_KEY = 're_test';
    expect(mailer.hasResend()).toBe(true);
    expect(mailer.hasSmtp()).toBe(false);
    expect(mailer.isConfigured()).toBe(true);
  });

  test('sends through the Resend API over HTTP and reports success', async () => {
    const requests = [];
    const { server, port } = await startServer(async (req, res) => {
      requests.push({ url: req.url, auth: req.headers.authorization, body: await collect(req) });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ id: 'msg_1' }));
    });

    process.env.RESEND_API_KEY = 're_secret';
    process.env.RESEND_BASE_URL = `http://127.0.0.1:${port}`;
    process.env.CONTACT_FROM = 'Coopvest Africa <replies@coopvestafrica.org>';

    const result = await mailer.send({
      to: 'member@example.com',
      subject: 'Re: Loan enquiry',
      text: 'Your loan is approved.',
      replyTo: 'coopvestafrica@gmail.com',
    });

    server.close();

    expect(result).toEqual({ sent: true });
    expect(requests).toHaveLength(1);
    expect(requests[0].url).toBe('/emails');
    expect(requests[0].auth).toBe('Bearer re_secret');
    const sent = JSON.parse(requests[0].body);
    expect(sent.to).toEqual(['member@example.com']);
    expect(sent.subject).toBe('Re: Loan enquiry');
    expect(sent.reply_to).toBe('coopvestafrica@gmail.com');
    expect(sent.from).toBe('Coopvest Africa <replies@coopvestafrica.org>');
    expect(sent.text).toBe('Your loan is approved.');
    // Callers pass no html; the mailer must still produce an escaped one.
    expect(sent.html).toContain('Your loan is approved.');
  });

  test('prefers Resend over SMTP when both are configured', async () => {
    const requests = [];
    const { server, port } = await startServer(async (req, res) => {
      requests.push(req.url);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{}');
    });

    process.env.RESEND_API_KEY = 're_secret';
    process.env.RESEND_BASE_URL = `http://127.0.0.1:${port}`;
    // SMTP is deliberately bogus: if the mailer picked it, the send would fail.
    process.env.SMTP_HOST = 'smtp.gmail.com';
    process.env.SMTP_PORT = '465';
    process.env.SMTP_SECURE = 'true';
    process.env.SMTP_USER = 'coopvestafrica@gmail.com';
    process.env.SMTP_PASS = 'not-a-real-password';

    const result = await mailer.send({ to: 'a@example.com', subject: 's', text: 't' });

    server.close();

    expect(result).toEqual({ sent: true });
    expect(requests).toEqual(['/emails']);
  });

  test('surfaces a Resend API error instead of claiming success', async () => {
    const { server, port } = await startServer((req, res) => {
      res.writeHead(403, { 'Content-Type': 'application/json' });
      res.end('{"message":"The domain is not verified"}');
    });

    process.env.RESEND_API_KEY = 're_bad';
    process.env.RESEND_BASE_URL = `http://127.0.0.1:${port}`;

    const result = await mailer.send({ to: 'a@example.com', subject: 's', text: 't' });

    server.close();

    expect(result.sent).toBe(false);
    expect(result.reason).toBe('failed');
    expect(result.error).toContain('403');
    expect(result.error).toContain('not verified');
  });

  test('falls back to the Resend sandbox sender when no from-address is set', () => {
    process.env.RESEND_API_KEY = 're_test';
    expect(mailer.fromAddress()).toBe('Coopvest Africa <onboarding@resend.dev>');
  });

  test('escapes HTML in the generated body so enquiry text cannot inject markup', async () => {
    const requests = [];
    const { server, port } = await startServer(async (req, res) => {
      requests.push(JSON.parse(await collect(req)));
      res.writeHead(200).end('{}');
    });

    process.env.RESEND_API_KEY = 're_secret';
    process.env.RESEND_BASE_URL = `http://127.0.0.1:${port}`;

    await mailer.send({
      to: 'a@example.com',
      subject: 's',
      text: '<script>alert("x")</script>',
    });

    server.close();

    expect(requests[0].html).not.toContain('<script>');
    expect(requests[0].html).toContain('&lt;script&gt;');
  });
});
