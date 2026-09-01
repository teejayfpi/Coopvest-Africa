/**
 * Banks Routes
 *
 * Serves the list of supported Nigerian banks (commercial + digital/fintech)
 * to the mobile app so the bank-selection list can be updated without an app
 * release. The list is refreshed from Paystack's public bank directory and
 * cached in memory; a bundled snapshot (config/banks.json) is the fallback
 * when Paystack is unreachable.
 */

const express = require('express');
const router = express.Router();

const logger = require('../utils/logger');
const fallbackDirectory = require('../config/banks.json');

const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24h
const FETCH_TIMEOUT_MS = 5000;

let cache = null; // { fetchedAt, payload }

const DIGITAL_CODES = new Set([
  '999992', // OPay
  '999991', // PalmPay
  '50211', // Kuda
  '50515', // Moniepoint
  '51318', // FairMoney
  '125', // Rubies
  '566', // VFD / VBank
  '51310', // Sparkle
  '565', // Carbon
  '100022', // GoMoney
  '035A', // ALAT
  '090567', // Flutterwave MFB
  '50304', // Mint MFB
  '51113', // Safe Haven
]);

const DIGITAL_KEYWORDS = [
  'opay', 'palmpay', 'kuda', 'moniepoint', 'fairmoney', 'rubies', 'vfd',
  'sparkle', 'carbon', 'gomoney', 'alat', 'mint', 'safe haven',
];

function categorize(name, code) {
  const n = name.toLowerCase();
  if (DIGITAL_CODES.has(code) || DIGITAL_KEYWORDS.some((k) => n.includes(k))) {
    return 'digital';
  }
  if (n.includes('mfb') || n.includes('microfinance')) return 'microfinance';
  if (n.includes('finance') || n.includes('mortgage')) return 'other';
  return 'commercial';
}

async function fetchPaystackBanks() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(
      'https://api.paystack.co/bank?country=nigeria&perPage=300',
      { signal: controller.signal }
    );
    if (!response.ok) throw new Error(`Paystack returned ${response.status}`);
    const payload = await response.json();
    if (!payload.status || !Array.isArray(payload.data)) {
      throw new Error('Unexpected Paystack response shape');
    }
    const seen = new Set();
    const banks = [];
    for (const b of payload.data) {
      if (!b.active || b.is_deleted) continue;
      const key = `${b.name}|${b.code}`;
      if (seen.has(key)) continue;
      seen.add(key);
      banks.push({ name: b.name, code: b.code, category: categorize(b.name, b.code) });
    }
    banks.sort((a, b) => a.name.localeCompare(b.name));
    return banks;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * GET /api/v1/banks
 *
 * Public, non-sensitive directory of supported banks.
 */
router.get('/', async (req, res) => {
  try {
    if (cache && Date.now() - cache.fetchedAt < CACHE_TTL_MS) {
      return res.json(cache.payload);
    }

    try {
      const banks = await fetchPaystackBanks();
      const payload = {
        success: true,
        version: new Date().toISOString().slice(0, 10),
        source: 'paystack',
        banks,
      };
      cache = { fetchedAt: Date.now(), payload };
      return res.json(payload);
    } catch (err) {
      logger.warn('banks: Paystack refresh failed, serving bundled list:', err.message);
      if (cache) return res.json(cache.payload); // stale cache beats nothing
      return res.json({
        success: true,
        version: fallbackDirectory.version,
        source: 'bundled',
        banks: fallbackDirectory.banks,
      });
    }
  } catch (err) {
    logger.error('banks list error:', err);
    res.status(500).json({ success: false, error: 'Could not load bank list' });
  }
});

module.exports = router;
