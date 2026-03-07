/**
 * Investment Pool Model
 * 
 * Managing cooperative investment pools and user participations
 */

const mongoose = require('mongoose');

const investmentParticipationSchema = new mongoose.Schema({
  participationId: {
    type: String,
    required: true
  },
  userId: {
    type: String,
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  units: {
    type: Number,
    default: 0
  },
  purchasePrice: {
    type: Number,
    default: 0
  },
  investedAt: {
    type: Date,
    default: Date.now
  },
  status: {
    type: String,
    enum: ['active', 'completed', 'withdrawn'],
    default: 'active'
  },
  currentValue: {
    type: Number,
    default: 0
  },
  profitLoss: {
    type: Number,
    default: 0
  },
  profitLossPercent: {
    type: Number,
    default: 0
  }
});

const investmentPoolSchema = new mongoose.Schema({
  poolId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    default: ''
  },
  type: {
    type: String,
    enum: ['savings', 'agriculture', 'real_estate', 'business', 'education', 'emergency', 'other'],
    required: true
  },
  
  // Pool Configuration
  targetAmount: {
    type: Number,
    required: true,
    min: 0
  },
  currentAmount: {
    type: Number,
    default: 0,
    min: 0
  },
  minimumInvestment: {
    type: Number,
    default: 1000,
    min: 0
  },
  maximumInvestment: {
    type: Number,
    default: 1000000,
    min: 0
  },
  
  // Returns
  expectedReturnRate: {
    type: Number,
    required: true,
    min: 0,
    max: 100
  },
  actualReturnRate: {
    type: Number,
    default: 0
  },
  
  // Duration
  durationMonths: {
    type: Number,
    required: true,
    min: 1
  },
  startDate: {
    type: Date,
    default: null
  },
  endDate: {
    type: Date,
    default: null
  },
  
  // Risk Level (1-5)
  riskLevel: {
    type: Number,
    default: 2,
    min: 1,
    max: 5
  },
  
  // Pool Status
  status: {
    type: String,
    enum: ['draft', 'open', 'funding', 'investing', 'completed', 'cancelled'],
    default: 'draft'
  },
  
  // Participation tracking
  participants: [investmentParticipationSchema],
  participantCount: {
    type: Number,
    default: 0
  },
  
  // Project details (if applicable)
  project: {
    name: { type: String, default: null },
    description: { type: String, default: null },
    location: { type: String, default: null },
    timeline: { type: String, default: null },
    status: { type: String, default: null }
  },
  
  // Manager/Admin
  managedBy: {
    type: String,
    default: null
  },
  
  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Virtual for progress percentage
investmentPoolSchema.virtual('progressPercentage').get(function() {
  if (this.targetAmount <= 0) return 0;
  return Math.min(100, (this.currentAmount / this.targetAmount) * 100);
});

// Virtual for remaining amount
investmentPoolSchema.virtual('remainingAmount').get(function() {
  return Math.max(0, this.targetAmount - this.currentAmount);
});

// Virtual for days remaining
investmentPoolSchema.virtual('daysRemaining').get(function() {
  if (!this.endDate) return 0;
  const now = new Date();
  const end = new Date(this.endDate);
  const diff = end - now;
  return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
});

// Calculate current value based on return rate
investmentPoolSchema.methods.calculateCurrentValue = function(userId) {
  const participation = this.participants.find(p => p.userId === userId && p.status === 'active');
  if (!participation) return 0;
  
  const growthRate = this.actualReturnRate || this.expectedReturnRate;
  const monthsElapsed = Math.floor((Date.now() - participation.investedAt) / (1000 * 60 * 60 * 24 * 30));
  const growthFactor = 1 + (growthRate / 100) * (monthsElapsed / 12);
  
  return participation.amount * growthFactor;
};

const InvestmentPool = mongoose.model('InvestmentPool', investmentPoolSchema);

module.exports = InvestmentPool;
