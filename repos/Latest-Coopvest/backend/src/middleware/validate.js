/**
 * Express-validator error aggregator.
 *
 * Routes register validation chains with express-validator and terminate
 * with this middleware so every handler gets a consistent 400 response
 * shape on input-validation failures.
 */

const { validationResult } = require('express-validator');

module.exports = function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};
