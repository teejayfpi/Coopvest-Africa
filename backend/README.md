# Coopvest Africa - Referral System Backend API

A Node.js/Express backend API for the tiered referral-based interest reduction system.

## Features

### Referral System
- **Tiered Bonus System**: 2 referrals = 2%, 4 referrals = 3%, 6+ referrals = 4% (max)
- **Lock-in Period**: 30 days after confirmation before bonus can be used
- **Qualification Rules**: KYC verification, 3 months savings, fraud check
- **Anti-Abuse**: Self-referral detection, duplicate account prevention

### API Endpoints

#### User Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Login user |
| GET | `/api/user/profile` | Get user profile |
| POST | `/api/loans/apply` | Apply for a loan |
| GET | `/api/wallet/balance` | Get wallet balance |
| GET | `/api/v1/referrals/summary` | Get user's referral summary |
| GET | `/api/v1/referrals/my-code` | Get user's referral code |
| GET | `/api/v1/referrals` | Get all user's referrals |
| GET | `/api/v1/referrals/:id` | Get specific referral |
| GET | `/api/v1/referrals/:id/status` | Check referral status |
| POST | `/api/v1/referrals/register` | Register new referral |
| POST | `/api/v1/referrals/:id/confirm` | Confirm a referral |
| POST | `/api/v1/referrals/apply-bonus` | Apply bonus to loan |
| POST | `/api/v1/referrals/calculate-interest` | Calculate interest with bonus |
| GET | `/api/v1/referrals/share-link` | Get share link & QR code |

#### Admin Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/admin/referrals` | Get all referrals |
| GET | `/api/v1/admin/referrals/stats` | Get referral statistics |
| GET | `/api/v1/admin/referrals/:id` | Get referral details |
| POST | `/api/v1/admin/referrals/:id/confirm` | Manually confirm referral |
| POST | `/api/v1/admin/referrals/:id/flag` | Flag referral |
| POST | `/api/v1/admin/referrals/:id/unflag` | Unflag referral |
| POST | `/api/v1/admin/referrals/:id/revoke` | Revoke bonus |
| GET | `/api/v1/admin/referrals/audit` | Get audit logs |
| PUT | `/api/v1/admin/referrals/settings` | Update settings |
| GET | `/api/v1/admin/referrals/settings` | Get settings |

## Getting Started

### Prerequisites
- Node.js 18+
- MongoDB

### Installation

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
nano .env

# Seed the database (Initial setup)
npm run seed

# Start development server
npm run dev
```

### Environment Variables

```env
# Server
NODE_ENV=development
PORT=8080
MONGODB_URI=mongodb://localhost:27017/coopvest

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d

# Referral Settings
REFERRAL_LOCK_IN_DAYS=30
REFERRAL_MIN_SAVINGS_MONTHS=3
REFERRAL_MIN_SAVINGS_AMOUNT=5000
```

## Project Structure

```
backend/
├── src/
│   ├── config/
│   │   └── database.js          # MongoDB connection
│   ├── models/
│   │   ├── Referral.js          # Referral model
│   │   ├── User.js              # User model
│   │   ├── AuditLog.js          # Audit log model
│   │   └── index.js             # Models index
│   ├── routes/
│   │   ├── auth.js              # Authentication routes
│   │   ├── referrals.js         # Referral routes
│   │   ├── admin.js             # Admin routes
│   │   └── loans.js             # Loan routes
│   ├── services/
│   │   └── referralService.js   # Core business logic
│   ├── middleware/
│   │   └── errorHandler.js      # Error handling
│   ├── utils/
│   │   └── logger.js            # Winston logger
│   └── server.js                # Entry point
├── package.json
└── README.md
```

## Tier System

| Confirmed Referrals | Tier | Interest Reduction |
|---------------------|------|-------------------|
| 0-1 | None | 0% |
| 2-3 | Bronze | 2% |
| 4-5 | Silver | 3% |
| 6+ | Gold | 4% (Max) |

## Qualification Rules

A referral counts only when the referred member:
1. ✅ Registers with a valid referral code
2. ✅ Completes KYC verification
3. ✅ Saves consistently for 3 months
4. ✅ Meets minimum cumulative savings (default: ₦5,000)
5. ✅ Is not flagged for fraud or duplication

## Anti-Abuse Measures

- **Self-referral detection**: Blocks users from referring themselves
- **Duplicate detection**: Prevents duplicate accounts
- **Lock-in period**: 30-day waiting period before bonus can be used
- **Fraud flags**: Admin can flag suspicious referrals
- **Audit logging**: All actions are logged for compliance

## API Examples

### Calculate Interest with Bonus

```bash
curl -X POST http://localhost:8080/api/v1/referrals/calculate-interest \
  -H "Content-Type: application/json" \
  -d '{
    "loanType": "Quick Loan",
    "loanAmount": 50000,
    "tenureMonths": 4
  }'
```

Response:
```json
{
  "success": true,
  "calculation": {
    "loanType": "Quick Loan",
    "baseInterestRate": 7.5,
    "referralBonusPercent": 3.0,
    "effectiveInterestRate": 4.5,
    "monthlyRepaymentBeforeBonus": 13125,
    "monthlyRepaymentAfterBonus": 12750,
    "totalSavingsFromBonus": 1500,
    "bonusApplied": true
  },
  "bonusAvailable": true,
  "bonusPercent": 3.0
}
```

### Get Referral Summary

```bash
curl http://localhost:8080/api/v1/referrals/summary \
  -H "x-user-id: USER123"
```

Response:
```json
{
  "success": true,
  "summary": {
    "userId": "USER123",
    "referralCode": "COOPUSER123",
    "pendingReferrals": 3,
    "confirmedReferrals": 4,
    "totalReferrals": 7,
    "currentTierBonus": 3.0,
    "currentTierDescription": "Silver Tier (3% OFF)",
    "isBonusAvailable": true,
    "referralsToNextTier": 2
  }
}
```

## License

MIT
