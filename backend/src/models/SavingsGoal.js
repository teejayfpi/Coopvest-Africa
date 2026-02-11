/**
 * Savings Goal Model
 * 
 * Tracking user savings goals and progress
 */

const mongoose = require('mongoose');

const savingsGoalSchema = new mongoose.Schema({
  goalId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  userId: {
    type: String,
    required: true,
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
  monthlyContribution: {
    type: Number,
    default: 0,
    min: 0
  },
  targetDate: {
    type: Date,
    required: true
  },
  category: {
    type: String,
    enum: ['emergency', 'education', 'business', 'travel', 'vehicle', 'home', 'medical', 'wedding', 'other'],
    default: 'other'
  },
  status: {
    type: String,
    enum: ['active', 'completed', 'cancelled', 'paused'],
    default: 'active'
  },
  priority: {
    type: Number,
    default: 1,
    min: 1,
    max: 5
  },
  isAutoSave: {
    type: Boolean,
    default: false
  },
  reminderDay: {
    type: Number,
    min: 1,
    max: 28,
    default: 1
  },
  color: {
    type: String,
    default: '#4CAF50'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  },
  completedAt: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

// Virtual for progress percentage
savingsGoalSchema.virtual('progressPercentage').get(function() {
  if (this.targetAmount <= 0) return 0;
  return Math.min(100, (this.currentAmount / this.targetAmount) * 100);
});

// Virtual for months remaining
savingsGoalSchema.virtual('monthsRemaining').get(function() {
  if (!this.targetDate) return 0;
  const now = new Date();
  const target = new Date(this.targetDate);
  const months = (target.getFullYear() - now.getFullYear()) * 12 + 
                 (target.getMonth() - now.getMonth());
  return Math.max(0, months);
});

// Check if goal is achievable
savingsGoalSchema.methods.isAchievable = function() {
  if (this.monthsRemaining <= 0) return false;
  const requiredMonthly = (this.targetAmount - this.currentAmount) / this.monthsRemaining;
  return requiredMonthly <= this.monthlyContribution * 2; // Allow 2x current contribution
};

const SavingsGoal = mongoose.model('SavingsGoal', savingsGoalSchema);

module.exports = SavingsGoal;
