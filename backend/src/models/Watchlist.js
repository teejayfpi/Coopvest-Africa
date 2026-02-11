/**
 * Watchlist Model
 * Tracks user's favorite investment pools and savings goals
 */

const mongoose = require('mongoose');

const watchlistSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  item: {
    type: {
      type: String,
      enum: ['InvestmentPool', 'SavingsGoal'],
      required: true
    },
    id: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'item.type'
    }
  },
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  category: {
    type: String,
    enum: ['agriculture', 'technology', 'real_estate', 'manufacturing', 'commerce', 'energy', 'education', 'healthcare', 'other'],
    default: 'other'
  },
  // Price/performance tracking
  priceAtAdd: {
    type: Number,
    default: 0
  },
  targetPrice: {
    type: Number
  },
  // Notification settings for this item
  alerts: {
    priceDrop: {
      enabled: { type: Boolean, default: false },
      percentage: { type: Number, default: 5 }
    },
    priceRise: {
      enabled: { type: Boolean, default: false },
      percentage: { type: Number, default: 10 }
    },
    milestone: {
      enabled: { type: Boolean, default: true },
      milestones: [{ type: Number }]
    },
    newReturns: {
      enabled: { type: Boolean, default: true }
    }
  },
  notes: {
    type: String,
    maxlength: 500
  },
  sortOrder: {
    type: Number,
    default: 0
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true
  },
  addedAt: {
    type: Date,
    default: Date.now
  },
  lastViewedAt: {
    type: Date
  }
}, {
  timestamps: true
});

// Compound index for user's watchlist
watchlistSchema.index({ user: 1, sortOrder: 1, createdAt: -1 });
watchlistSchema.index({ user: 1, 'item.type': 1, createdAt: -1 });
watchlistSchema.index({ 'item.id': 1 });

// Prevent duplicate items in watchlist
watchlistSchema.index({ user: 1, 'item.type': 1, 'item.id': 1 }, { unique: true });

// Virtual for current price (would fetch from InvestmentPool)
watchlistSchema.virtual('currentPrice').get(function() {
  return this.priceAtAdd; // Would need to fetch current from related model
});

// Virtual for price change percentage
watchlistSchema.virtual('priceChange').get(function() {
  if (!this.priceAtAdd) return 0;
  return ((this.currentPrice - this.priceAtAdd) / this.priceAtAdd * 100).toFixed(2);
});

// Instance method to update last viewed
watchlistSchema.methods.updateLastViewed = async function() {
  this.lastViewedAt = new Date();
  return this.save();
};

// Instance method to update sort order
watchlistSchema.methods.updateSortOrder = async function(order) {
  this.sortOrder = order;
  return this.save();
};

// Instance method to toggle alert
watchlistSchema.methods.toggleAlert = async function(alertType, enabled) {
  if (this.alerts[alertType]) {
    this.alerts[alertType].enabled = enabled;
    return this.save();
  }
  throw new Error('Invalid alert type');
};

// Static method to check if item is in watchlist
watchlistSchema.statics.isInWatchlist = async function(userId, itemType, itemId) {
  const count = await this.countDocuments({
    user: userId,
    'item.type': itemType,
    'item.id': itemId,
    isActive: true
  });
  return count > 0;
};

// Static method to get user's watchlist with details
watchlistSchema.statics.getWithDetails = async function(userId, options = {}) {
  const { page = 1, limit = 20, type } = options;
  const query = { user: userId, isActive: true };
  
  if (type) query['item.type'] = type;

  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    this.find(query)
      .sort({ sortOrder: 1, createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('item.id'),
    this.countDocuments(query)
  ]);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit)
    }
  };
};

// Static method to add item to watchlist
watchlistSchema.statics.addItem = async function(userId, itemType, itemId, name, category, price) {
  const existing = await this.findOne({
    user: userId,
    'item.type': itemType,
    'item.id': itemId
  });

  if (existing) {
    existing.isActive = true;
    existing.addedAt = new Date();
    return existing.save();
  }

  return this.create({
    user: userId,
    item: { type: itemType, id: itemId },
    name,
    category,
    priceAtAdd: price
  });
};

// Static method to remove item from watchlist
watchlistSchema.statics.removeItem = async function(userId, itemType, itemId) {
  return this.findOneAndUpdate(
    { user: userId, 'item.type': itemType, 'item.id': itemId },
    { isActive: false },
    { new: true }
  );
};

const Watchlist = mongoose.model('Watchlist', watchlistSchema);

module.exports = Watchlist;
