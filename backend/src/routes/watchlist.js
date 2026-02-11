/**
 * Watchlist Routes
 * API endpoints for managing user's investment watchlist
 */

const express = require('express');
const router = express.Router();
const { Watchlist, InvestmentPool, SavingsGoal } = require('../models');
const { auth: authMiddleware } = require('../middleware/auth');

// All routes require authentication
router.use(authMiddleware);

/**
 * GET /api/v1/watchlist
 * Get user's watchlist
 */
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 20, type } = req.query;

    const result = await Watchlist.getWithDetails(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
      type
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/watchlist/investments
 * Get only investment pools in watchlist
 */
router.get('/investments', async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;

    const result = await Watchlist.getWithDetails(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
      type: 'InvestmentPool'
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/watchlist/savings
 * Get only savings goals in watchlist
 */
router.get('/savings', async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;

    const result = await Watchlist.getWithDetails(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
      type: 'SavingsGoal'
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/watchlist/check/:type/:id
 * Check if item is in watchlist
 */
router.get('/check/:type/:id', async (req, res) => {
  try {
    const { type, id } = req.params;

    const isInWatchlist = await Watchlist.isInWatchlist(req.user.id, type, id);

    res.json({
      success: true,
      data: { inWatchlist: isInWatchlist }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/watchlist
 * Add item to watchlist
 */
router.post('/', async (req, res) => {
  try {
    const { type, id, notes } = req.body;

    if (!type || !id) {
      return res.status(400).json({
        success: false,
        error: 'Type and ID are required'
      });
    }

    // Validate type
    if (!['InvestmentPool', 'SavingsGoal'].includes(type)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid type. Must be InvestmentPool or SavingsGoal'
      });
    }

    // Get the item to get its details
    let item;
    let price = 0;
    let name = '';
    let category = 'other';

    if (type === 'InvestmentPool') {
      item = await InvestmentPool.findById(id);
      if (item) {
        price = item.minimumInvestment || 0;
        name = item.name || '';
        category = item.category || 'other';
      }
    } else if (type === 'SavingsGoal') {
      item = await SavingsGoal.findById(id);
      if (item) {
        price = item.targetAmount || 0;
        name = item.name || '';
      }
    }

    if (!item) {
      return res.status(404).json({
        success: false,
        error: `${type} not found`
      });
    }

    const watchlistItem = await Watchlist.addItem(
      req.user.id,
      type,
      id,
      name,
      category,
      price
    );

    if (notes) {
      watchlistItem.notes = notes;
      await watchlistItem.save();
    }

    res.status(201).json({
      success: true,
      message: 'Item added to watchlist',
      data: watchlistItem
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        error: 'Item is already in watchlist'
      });
    }
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/watchlist/:id/notes
 * Update notes for watchlist item
 */
router.patch('/:id/notes', async (req, res) => {
  try {
    const { notes } = req.body;

    const item = await Watchlist.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        error: 'Watchlist item not found'
      });
    }

    item.notes = notes;
    await item.save();

    res.json({
      success: true,
      message: 'Notes updated',
      data: item
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/watchlist/:id/sort
 * Update sort order
 */
router.patch('/:id/sort', async (req, res) => {
  try {
    const { order } = req.body;

    const item = await Watchlist.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        error: 'Watchlist item not found'
      });
    }

    await item.updateSortOrder(order);

    res.json({
      success: true,
      message: 'Sort order updated'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * PATCH /api/v1/watchlist/:id/alerts
 * Update alert settings
 */
router.patch('/:id/alerts', async (req, res) => {
  try {
    const { alertType, key, value } = req.body;

    const item = await Watchlist.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        error: 'Watchlist item not found'
      });
    }

    if (!item.alerts[alertType]) {
      return res.status(400).json({
        success: false,
        error: 'Invalid alert type'
      });
    }

    item.alerts[alertType][key] = value;
    await item.save();

    res.json({
      success: true,
      message: 'Alert settings updated',
      data: item.alerts
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/watchlist/:id/toggle-alert/:alertType
 * Toggle specific alert
 */
router.post('/:id/toggle-alert/:alertType', async (req, res) => {
  try {
    const { alertType } = req.params;
    const { enabled } = req.body;

    const item = await Watchlist.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        error: 'Watchlist item not found'
      });
    }

    await item.toggleAlert(alertType, enabled);

    res.json({
      success: true,
      message: `Alert ${enabled ? 'enabled' : 'disabled'}`,
      data: item.alerts
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/watchlist/:id/view
 * Mark item as viewed
 */
router.post('/:id/view', async (req, res) => {
  try {
    const item = await Watchlist.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        error: 'Watchlist item not found'
      });
    }

    await item.updateLastViewed();

    res.json({
      success: true,
      message: 'Item marked as viewed'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * DELETE /api/v1/watchlist/:id
 * Remove item from watchlist
 */
router.delete('/:id', async (req, res) => {
  try {
    const item = await Watchlist.findOne({
      _id: req.params.id,
      user: req.user.id,
      isActive: true
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        error: 'Watchlist item not found'
      });
    }

    // Soft delete
    item.isActive = false;
    await item.save();

    res.json({
      success: true,
      message: 'Item removed from watchlist'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * DELETE /api/v1/watchlist/type/:type
 * Remove all items of a type from watchlist
 */
router.delete('/type/:type', async (req, res) => {
  try {
    const { type } = req.params;

    await Watchlist.updateMany(
      { user: req.user.id, 'item.type': type, isActive: true },
      { isActive: false }
    );

    res.json({
      success: true,
      message: `All ${type} items removed from watchlist`
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * DELETE /api/v1/watchlist
 * Clear entire watchlist
 */
router.delete('/', async (req, res) => {
  try {
    await Watchlist.updateMany(
      { user: req.user.id, isActive: true },
      { isActive: false }
    );

    res.json({
      success: true,
      message: 'Watchlist cleared'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
