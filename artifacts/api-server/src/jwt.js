const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const ACCESS_SECRET = process.env.SESSION_SECRET || 'coopvest-access-secret-change-in-prod';
const REFRESH_SECRET = process.env.SESSION_SECRET
  ? process.env.SESSION_SECRET + '-refresh'
  : 'coopvest-refresh-secret-change-in-prod';

const ACCESS_TTL = '7d';
const REFRESH_TTL = '30d';

function signAccess(payload) {
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn: ACCESS_TTL });
}

function signRefresh(payload) {
  return jwt.sign(payload, REFRESH_SECRET, { expiresIn: REFRESH_TTL });
}

function verifyAccess(token) {
  return jwt.verify(token, ACCESS_SECRET);
}

function verifyRefresh(token) {
  return jwt.verify(token, REFRESH_SECRET);
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function expiresAt(days = 7) {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

module.exports = { signAccess, signRefresh, verifyAccess, verifyRefresh, hashToken, expiresAt };
