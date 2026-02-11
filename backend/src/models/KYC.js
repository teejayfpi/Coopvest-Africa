/**
 * KYC (Know Your Customer) Model
 * 
 * Tracking user identity verification documents and status
 */

const mongoose = require('mongoose');

const kycDocumentSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['national_id', 'passport', 'drivers_license', 'voters_card', 'utility_bill', 'bank_statement'],
    required: true
  },
  documentNumber: {
    type: String,
    default: null
  },
  expiryDate: {
    type: Date,
    default: null
  },
  frontImageUrl: {
    type: String,
    default: null
  },
  backImageUrl: {
    type: String,
    default: null
  },
  uploadedAt: {
    type: Date,
    default: Date.now
  },
  verifiedAt: {
    type: Date,
    default: null
  },
  status: {
    type: String,
    enum: ['pending', 'verified', 'rejected', 'expired'],
    default: 'pending'
  },
  rejectionReason: {
    type: String,
    default: null
  }
});

const kycSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  
  // Personal Information
  personalInfo: {
    firstName: {
      type: String,
      default: null
    },
    lastName: {
      type: String,
      default: null
    },
    middleName: {
      type: String,
      default: null
    },
    dateOfBirth: {
      type: Date,
      default: null
    },
    gender: {
      type: String,
      enum: ['male', 'female', 'other', null],
      default: null
    },
    nationality: {
      type: String,
      default: null
    },
    maritalStatus: {
      type: String,
      enum: ['single', 'married', 'divorced', 'widowed', null],
      default: null
    }
  },
  
  // Contact Information
  contactInfo: {
    address: {
      street: { type: String, default: null },
      city: { type: String, default: null },
      state: { type: String, default: null },
      lga: { type: String, default: null },
      postalCode: { type: String, default: null },
      country: { type: String, default: 'Nigeria' }
    },
    yearsAtCurrentAddress: {
      type: Number,
      default: null
    },
    primaryPhone: {
      type: String,
      default: null
    },
    alternatePhone: {
      type: String,
      default: null
    },
    preferredContactMethod: {
      type: String,
      enum: ['phone', 'email', 'sms', null],
      default: null
    }
  },
  
  // Employment Information
  employment: {
    status: {
      type: String,
      enum: ['employed', 'self_employed', 'unemployed', 'student', 'retired', null],
      default: null
    },
    employerName: {
      type: String,
      default: null
    },
    employerAddress: {
      type: String,
      default: null
    },
    jobTitle: {
      type: String,
      default: null
    },
    employmentDate: {
      type: Date,
      default: null
    },
    monthlyIncome: {
      type: Number,
      default: null
    },
    incomeFrequency: {
      type: String,
      enum: ['weekly', 'monthly', 'bi_weekly', null],
      default: null
    }
  },
  
  // Banking Information
  bankInfo: {
    bankName: {
      type: String,
      default: null
    },
    accountNumber: {
      type: String,
      default: null
    },
    accountName: {
      type: String,
      default: null
    },
    accountType: {
      type: String,
      enum: ['savings', 'current', null],
      default: null
    },
    bvn: {
      type: String,
      default: null
    },
    bankVerificationVerified: {
      type: Boolean,
      default: false
    }
  },
  
  // Identity Documents
  documents: [kycDocumentSchema],
  
  // Selfie Verification
  selfie: {
    imageUrl: {
      type: String,
      default: null
    },
    uploadedAt: {
      type: Date,
      default: null
    },
    verifiedAt: {
      type: Date,
      default: null
    },
    status: {
      type: String,
      enum: ['pending', 'verified', 'rejected', null],
      default: null
    },
    faceMatchScore: {
      type: Number,
      default: null
    }
  },
  
  // Verification Status
  status: {
    type: String,
    enum: ['pending', 'in_review', 'verified', 'rejected', 'expired'],
    default: 'pending'
  },
  
  verificationLevel: {
    type: Number,
    default: 0,
    min: 0,
    max: 3
  },
  
  rejectionReason: {
    type: String,
    default: null
  },
  
  verifiedAt: {
    type: Date,
    default: null
  },
  
  submittedAt: {
    type: Date,
    default: null
  },
  
  lastUpdatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Calculate completion percentage
kycSchema.virtual('completionPercentage').get(function() {
  let completed = 0;
  let total = 7; // 7 main sections
  
  if (this.personalInfo.firstName && this.personalInfo.lastName) completed++;
  if (this.contactInfo.address.street && this.contactInfo.address.state) completed++;
  if (this.employment.status) completed++;
  if (this.bankInfo.accountNumber && this.bankInfo.bankName) completed++;
  if (this.documents.length > 0) completed++;
  if (this.selfie.imageUrl) completed++;
  if (this.status === 'verified') completed++;
  
  return Math.round((completed / total) * 100);
});

// Check if KYC is complete
kycSchema.methods.isComplete = function() {
  return (
    this.personalInfo.firstName &&
    this.personalInfo.lastName &&
    this.contactInfo.address.street &&
    this.employment.status &&
    this.bankInfo.accountNumber &&
    this.documents.length > 0 &&
    this.selfie.imageUrl
  );
};

const KYC = mongoose.model('KYC', kycSchema);

module.exports = KYC;
