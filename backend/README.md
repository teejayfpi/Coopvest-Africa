# Coopvest Africa - Referral System Backend API (Supabase Edition)

A Node.js/Express backend API for the tiered referral-based interest reduction system, now fully integrated with **Supabase** for authentication and data persistence.

## Features

### Referral System
- **Tiered Bonus System**: 2 referrals = 2%, 4 referrals = 3%, 6+ referrals = 4% (max)
- **Lock-in Period**: 30 days after confirmation before bonus can be used
- **Qualification Rules**: KYC verification, 3 months savings, fraud check
- **Anti-Abuse**: Self-referral detection, duplicate account prevention

### Supabase Integration
- **Authentication**: Powered by Supabase Auth (JWT)
- **Database**: PostgreSQL on Supabase
- **Real-time**: Profile synchronization via database triggers

## Getting Started

### Prerequisites
- Node.js 18+
- Supabase Project

### Installation

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your Supabase credentials
# SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
```

### Database Setup

1.  Log in to your **Supabase Dashboard**.
2.  Open the **SQL Editor**.
3.  Execute the contents of `supabase_schema.sql` to set up the tables and triggers.

### Start Development Server

```bash
npm run dev
```

## Project Structure

```
backend/
├── src/
│   ├── config/
│   │   └── supabase.js          # Supabase client configuration
│   ├── routes/
│   │   ├── auth.js              # Authentication routes (Supabase)
│   │   ├── user.js              # User profile routes (Supabase)
│   │   ├── referrals.js         # Referral routes
│   │   └── admin.js             # Admin routes
│   ├── middleware/
│   │   ├── auth.js              # Supabase JWT authentication middleware
│   │   └── errorHandler.js      # Error handling
│   ├── utils/
│   │   └── logger.js            # Winston logger
│   └── server.js                # Entry point
├── supabase_schema.sql          # PostgreSQL schema for Supabase
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

## License

MIT
