# Database Migration Plan: MongoDB to Supabase

This document outlines the steps to migrate the Coopvest Africa backend from MongoDB to Supabase (PostgreSQL).

## 1. Current State Assessment
The project currently uses a hybrid approach:
- **Authentication**: Partially migrated to Supabase Auth.
- **Data Persistence**: Primary data (Users, Loans, Wallets, etc.) is stored in MongoDB.
- **Supabase Integration**: A `supabase.js` client exists, and some routes (like `auth.js`) use it for identity management while still mirroring data to MongoDB.

## 2. Migration Strategy
We will transition to a **Supabase-first** architecture by:
1.  **Deactivating MongoDB**: Removing the connection logic and dependencies.
2.  **Updating Data Access**: Modifying routes and services to use the Supabase client instead of Mongoose models.
3.  **Schema Alignment**: Ensuring the Supabase PostgreSQL schema supports all existing features.

## 3. Implementation Steps

### Phase 1: Configuration Cleanup
- [ ] Remove `MONGODB_URI` and MongoDB-related settings from `.env.example`.
- [ ] Update `src/server.js` to remove the `connectDB()` call and MongoDB logging.
- [ ] Remove `src/config/database.js`.

### Phase 2: Route & Service Migration
- [ ] **Auth Route (`src/routes/auth.js`)**: Remove MongoDB mirroring logic in the `/register` endpoint.
- [ ] **User Profile (`src/routes/user.js`)**: Rewrite to fetch and update data from Supabase `profiles` table.
- [ ] **Middleware**: Ensure `authenticate` middleware correctly handles user context without needing a MongoDB lookup.

### Phase 3: Dependency Management
- [ ] Uninstall `mongoose` and `bcryptjs` (Supabase handles password hashing).
- [ ] Update `package.json` scripts to remove MongoDB migration commands.

### Phase 4: Schema & Documentation
- [ ] Update `supabase_schema.sql` to include missing tables (Wallets, Loans, etc.) if needed for full functionality.
- [ ] Update `README.md` and `DEPLOYMENT.md` to reflect the new Supabase-only architecture.

## 4. Verification
- [ ] Verify registration flow creates users only in Supabase.
- [ ] Verify profile retrieval works via Supabase client.
- [ ] Ensure all environment variables for Supabase are correctly documented.
