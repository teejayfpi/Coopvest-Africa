/**
 * Fee Schedule Routes
 *
 * Serves the cooperative's charges as structured data, derived entirely from
 * `config/feeDisclosure.js` — the same module the routes that levy a charge
 * import. Nothing is written here, so this cannot become a second source of
 * truth for an amount.
 *
 * The corporate website builds its Schedule of Charges page from this response
 * rather than restating the figures, so a visitor's price list cannot drift
 * from the price the app charges.
 *
 * Public, like `/api/v1/terms`: it is the published price list.
 */

const crypto = require('crypto');
const express = require('express');
const router = express.Router();

const logger = require('../utils/logger');
const {
  LATE_REPAYMENT_FINE,
  REGISTRATION_FEE,
  MIN_MONTHLY_CONTRIBUTION,
  ADMINISTRATIVE_FEE,
  LOAN_INTEREST_RATES,
} = require('../config/feeDisclosure');
const termsDocument = require('../config/terms.json');

/**
 * The charges a member bears, in the order the disclosure presents them.
 *
 * `note` strings carry no amounts on purpose: a figure written in prose is a
 * figure that can disagree with the field beside it. Amounts live in `amount`.
 */
function buildSchedule() {
  return {
    version: termsDocument.version,
    currency: 'NGN',
    charges: [
      {
        id: 'registration_fee',
        label: 'Registration fee',
        amount: REGISTRATION_FEE,
        frequency: 'one-time',
        refundable: false,
        note: 'A charge payable to the cooperative. Where an employer deducts contributions at source, it is recovered through that deduction instead.',
      },
      {
        id: 'monthly_contribution',
        label: 'Minimum monthly contribution',
        amount: MIN_MONTHLY_CONTRIBUTION,
        frequency: 'monthly',
        refundable: null,
        note: 'Your own money, held in your savings. It is not a charge.',
      },
      {
        id: 'administrative_fee',
        label: 'Monthly administrative fee',
        amount: ADMINISTRATIVE_FEE.total,
        frequency: 'monthly',
        refundable: null,
        components: ADMINISTRATIVE_FEE.components.map(({ name, amount }) => ({ name, amount })),
        note: 'Recovered from your contribution, or from salary where an employer deducts contributions.',
      },
      {
        id: 'late_repayment_fine',
        label: 'Late repayment fine',
        amount: LATE_REPAYMENT_FINE,
        frequency: 'per occurrence',
        refundable: null,
        trigger: 'Two consecutive missed monthly repayments',
        note: 'Recorded as a separate obligation. It is not added to your loan balance.',
      },
    ],
    loan_interest_rates: Object.entries(LOAN_INTEREST_RATES).map(([product, rate]) => ({
      product,
      rate,
    })),
    not_charged: [
      'Withdrawal fee',
      'Early-repayment penalty',
      'Loan application or processing fee',
      'Account-maintenance charge beyond the monthly administrative fee',
    ],
  };
}

/** Stable revision marker, so a consumer can tell when the schedule changed. */
function scheduleHash(schedule) {
  return crypto.createHash('sha256').update(JSON.stringify(schedule)).digest('hex').slice(0, 16);
}

/**
 * GET /api/v1/fees
 *
 * Public, non-sensitive published pricing.
 */
router.get('/', (req, res) => {
  try {
    const schedule = buildSchedule();
    res.json({ success: true, schedule_hash: scheduleHash(schedule), ...schedule });
  } catch (err) {
    logger.error('fee schedule error:', err);
    res.status(500).json({ success: false, error: 'Could not load the fee schedule' });
  }
});

router.buildSchedule = buildSchedule;
router.scheduleHash = scheduleHash;

module.exports = router;
