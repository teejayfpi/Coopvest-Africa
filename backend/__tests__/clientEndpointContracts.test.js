/**
 * Guards the contract between the mobile client and the API.
 *
 * Two live features were broken by a silent spelling mismatch: the app posted
 * to `/tickets/:id/replies` while the server only had `/reply`, and it posted
 * `/wallet/statement` while the server only had GET. Both returned 404 and the
 * member saw a generic failure. These assert the server accepts what the
 * client actually sends.
 */

const fs = require('fs');
const path = require('path');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
const tickets = read('src/routes/tickets.js');
const wallet = read('src/routes/wallet.js');

describe('ticket replies', () => {
  it('accepts the plural path the mobile client posts to', () => {
    expect(tickets).toContain("router.post('/:id/replies'");
  });

  it('still accepts the singular path and the messages path', () => {
    expect(tickets).toContain("router.post('/:id/reply'");
    expect(tickets).toContain("router.post('/:id/messages'");
  });

  it('reads the `message` field the client sends', () => {
    const handler = tickets.slice(tickets.indexOf('const handleMemberReply'));
    expect(handler).toContain('req.body.message');
  });
});

describe('wallet statement', () => {
  it('accepts POST, which is what the mobile client uses', () => {
    expect(wallet).toContain("router.post('/statement'");
  });

  it('still accepts GET for the admin tooling', () => {
    expect(wallet).toContain("router.get('/statement'");
  });

  it('reads the start_date/end_date body fields the client sends', () => {
    const handler = wallet.slice(wallet.indexOf('const handleStatement'));
    expect(handler).toContain('body.start_date');
    expect(handler).toContain('body.end_date');
  });

  it('keeps the query-param form working', () => {
    const handler = wallet.slice(wallet.indexOf('const handleStatement'));
    expect(handler).toContain('req.query.from');
    expect(handler).toContain('req.query.to');
  });
});

describe('mobile loan application sends the referral flag', () => {
  it('posts applyReferralBonus, without which the discount is never applied', () => {
    // The Flutter app is part of this repository, but a CI job that checks out
    // only the backend would not have it. Guard rather than throw at load time.
    const screenPath = path.join(
      __dirname, '..', '..', 'lib', 'presentation', 'screens', 'loan', 'loan_application_screen.dart'
    );
    if (!fs.existsSync(screenPath)) {
      // Nothing to assert against; the endpoint contract above is still checked.
      return;
    }
    const screen = fs.readFileSync(screenPath, 'utf8');
    expect(screen).toContain("'applyReferralBonus'");
  });
});
