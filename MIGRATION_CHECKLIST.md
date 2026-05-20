# MongoDB → Supabase Migration Checklist

## Overview
This document tracks the completion status of the migration from MongoDB to Supabase (PostgreSQL) as outlined in `MIGRATION_PLAN.md`.

**Target Completion Date:** (Set by team)  
**Migration Lead:** (Assign)  
**Status:** 🟡 **IN PROGRESS** (Phase 1-2)

---

## Phase 1: Configuration Cleanup ✅

### Complete
- [x] Remove `MONGODB_URI` from old `.env` files
- [x] Create new `.env.example` with Supabase variables
- [x] Comment out `connectDB()` in `backend/src/server.js`
- [x] Update logging to remove MongoDB connection messages
- [x] Remove `src/config/database.js` reference

### Status: ✅ **DONE**

---

## Phase 2: Route & Service Migration ✅

### Auth Routes (`backend/src/routes/auth.js`)
- [x] Migrate `/register` to use Supabase Auth
- [x] Migrate `/login` to use Supabase Auth
- [x] Migrate `/refresh` to use Supabase refresh tokens
- [x] Migrate `/google` to use Supabase OAuth
- [x] Migrate `/sync` for profile syncing
- [x] Migrate password reset endpoints
- [x] Remove all MongoDB references
- [x] Add salary deduction consent endpoint

**Status:** ✅ **DONE** (All endpoints use Supabase)

### User Routes (`backend/src/routes/user.js`)
- [x] Migrate `/profile` GET to fetch from Supabase
- [x] Migrate `/profile` PUT to update Supabase
- [x] Migrate `/dashboard` to query Supabase tables
- [x] Migrate `/insights` for financial aggregation
- [x] Remove all Mongoose model references
- [x] Add proper error handling for Supabase responses

**Status:** ✅ **DONE** (All endpoints use Supabase)

### Middleware (`backend/src/middleware/auth.js`)
- [x] Update authentication middleware for Supabase JWT
- [x] Verify tokens against Supabase auth
- [x] Extract user context from token payload

**Status:** ✅ **DONE** (Uses Supabase auth)

### Configuration
- [x] Update `backend/src/config/supabase.js`
- [x] Verify Supabase client initialization
- [x] Add environment variable validation

**Status:** ✅ **DONE**

---

## Phase 3: Dependency Management 🟡

### Package.json Updates
- [ ] Remove `mongoose` dependency from `/backend/package.json`
- [ ] Remove `bcryptjs` dependency (Supabase handles hashing)
- [ ] Remove `jsonwebtoken` dependency (Supabase handles JWT)
- [ ] Verify all remaining dependencies are Supabase-compatible
- [ ] Run `npm install` to lock dependencies

**Status:** 🟡 **PENDING**

### Removed Scripts
- [ ] Remove `migrate` script
- [ ] Remove `migrate:status` script
- [ ] Remove `seed-admin` script
- [ ] Add `db:setup` script for running schema SQL in Supabase

**Status:** 🟡 **PENDING**

---

## Phase 4: Schema & Documentation 🟡

### Supabase Schema
- [ ] Update `backend/supabase_schema.sql` with missing columns:
  - `salary_deduction_consent` (BOOLEAN)
  - `salary_deduction_consent_date` (TIMESTAMPTZ)
- [ ] Add indexes for query performance
- [ ] Enable Row Level Security (RLS) on all tables
- [ ] Create RLS policies for member data isolation
- [ ] Run schema SQL in Supabase console

**Status:** 🟡 **PENDING**

### Documentation
- [ ] Update `README.md` to reference Supabase-only architecture
- [ ] Create `DEPLOYMENT.md` with Supabase setup instructions
- [ ] Add API endpoint documentation (Postman collection)
- [ ] Document environment variables
- [ ] Create troubleshooting guide

**Status:** 🟡 **PENDING**

### API Documentation
- [ ] Generate OpenAPI/Swagger documentation
- [ ] Document all auth endpoints
- [ ] Document all user endpoints
- [ ] Add example requests/responses

**Status:** 🟡 **PENDING**

---

## Phase 5: Testing 🔴

### Unit Tests
- [ ] Test auth endpoints with Supabase
- [ ] Test user profile endpoints
- [ ] Test error handling
- [ ] Test RLS policies

**Status:** 🔴 **NOT STARTED**

### Integration Tests
- [ ] Test registration flow end-to-end
- [ ] Test login flow end-to-end
- [ ] Test profile update flow
- [ ] Test JWT refresh flow

**Status:** 🔴 **NOT STARTED**

### Load Testing
- [ ] Simulate concurrent users
- [ ] Verify rate limiting works
- [ ] Monitor Supabase connection pooling

**Status:** 🔴 **NOT STARTED**

---

## Phase 6: Cleanup & Optimization 🔴

### Repository Cleanup
- [ ] Remove `/repos/Latest-Coopvest/backend` (duplicate)
- [ ] Remove `/cloned-repo/backend` (duplicate)
- [ ] Consolidate to single `/backend` directory
- [ ] Remove old MongoDB migration scripts

**Status:** 🔴 **NOT STARTED**

### Performance
- [ ] Add database query caching where appropriate
- [ ] Optimize indexes in Supabase
- [ ] Monitor slow queries
- [ ] Set up query monitoring alerts

**Status:** 🔴 **NOT STARTED**

### Security
- [ ] Verify no secrets in `.env.example`
- [ ] Audit RLS policies
- [ ] Test SQL injection prevention
- [ ] Verify rate limiting effectiveness

**Status:** 🔴 **NOT STARTED**

---

## Phase 7: Deployment 🔴

### Staging Environment
- [ ] Set up staging Supabase project
- [ ] Deploy backend to staging
- [ ] Run full test suite
- [ ] Performance testing

**Status:** 🔴 **NOT STARTED**

### Production Deployment
- [ ] Back up MongoDB data (if applicable)
- [ ] Deploy to production
- [ ] Verify Supabase connections
- [ ] Monitor for errors

**Status:** 🔴 **NOT STARTED**

### Monitoring
- [ ] Set up error tracking (Sentry)
- [ ] Set up performance monitoring
- [ ] Set up database monitoring
- [ ] Create alert rules

**Status:** 🔴 **NOT STARTED**

---

## Key Files Modified

### ✅ Completed
- `backend/src/server.js` - Removed MongoDB connection
- `backend/src/routes/auth.js` - Fully Supabase-based
- `backend/src/routes/user.js` - Fully Supabase-based
- `backend/src/config/supabase.js` - Verified
- `backend/.env.example` - Created

### 🟡 In Progress / Pending
- `backend/package.json` - Remove old dependencies
- `backend/supabase_schema.sql` - Add missing columns
- `README.md` - Update documentation
- `DEPLOYMENT.md` - Create deployment guide

### 🔴 Not Started
- Unit and integration tests
- Repository cleanup
- Production deployment

---

## Blockers / Issues

### Current Blockers
None identified - Phase 1 & 2 complete

### Known Issues
- Multiple backend copies exist (`/backend`, `/repos/Latest-Coopvest/backend`, `/cloned-repo/backend`)
- Firebase Auth mentioned in some routes (needs clarification on which auth system to use)

### Questions for Team
1. Should we use Supabase Auth OR Firebase Auth OR both?
2. Should old MongoDB data be migrated or discarded?
3. What's the target date for production deployment?

---

## Commands to Run

```bash
# 1. Navigate to backend
cd backend

# 2. Remove old dependencies
npm remove mongoose bcryptjs jsonwebtoken

# 3. Install/update Supabase
npm install @supabase/supabase-js@latest

# 4. Copy .env.example to .env (and fill in values)
cp .env.example .env

# 5. Verify it works
npm run dev
# Should see: ✅ Supabase client initialized

# 6. Test an endpoint
curl -X GET http://localhost:3000/health
# Should return: { success: true, message: "Coopvest API is running", ... }
```

---

## Progress Summary

| Phase | Task | Status | % Complete |
|-------|------|--------|------------|
| 1 | Configuration Cleanup | ✅ Done | 100% |
| 2 | Route & Service Migration | ✅ Done | 100% |
| 3 | Dependency Management | 🟡 Pending | 0% |
| 4 | Schema & Documentation | 🟡 Pending | 10% |
| 5 | Testing | 🔴 Not Started | 0% |
| 6 | Cleanup & Optimization | 🔴 Not Started | 0% |
| 7 | Deployment | 🔴 Not Started | 0% |
| **Overall** | **Migration** | 🟡 **On Track** | **28.6%** |

---

## Next Steps (Priority Order)

1. **IMMEDIATE (Today):**
   - [ ] Review this checklist with team
   - [ ] Remove `mongoose`, `bcryptjs` from package.json
   - [ ] Run `npm install` in `/backend`
   - [ ] Test locally that everything still works

2. **THIS WEEK:**
   - [ ] Update `supabase_schema.sql` with missing columns
   - [ ] Run schema in Supabase console
   - [ ] Create basic integration tests

3. **NEXT WEEK:**
   - [ ] Clean up repository (remove duplicate backends)
   - [ ] Update documentation
   - [ ] Deploy to staging

---

**Last Updated:** 2026-05-20  
**Next Review:** (Set by team)
