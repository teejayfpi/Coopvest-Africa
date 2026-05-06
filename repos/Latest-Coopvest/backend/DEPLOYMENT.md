# Coopvest Africa - Production Deployment Guide (Supabase Edition)

**Version:** 2.0  
**Date:** March 2026

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Environment Configuration](#environment-configuration)
3. [Database Setup (Supabase)](#database-setup-supabase)
4. [SSL/TLS Configuration](#ssltls-configuration)
5. [IP Whitelisting](#ip-whitelisting)
6. [Monitoring & Logging](#monitoring--logging)
7. [Deployment Commands](#deployment-commands)
8. [Post-Deployment Verification](#post-deployment-verification)

---

## Pre-Deployment Checklist

Before deploying to production, ensure all items from the deployment review are completed:

| Category | Task | Status |
|----------|------|--------|
| Environment | Configure SUPABASE_URL, SUPABASE_ANON_KEY, and CORS_ORIGIN in .env | ✅ Done |
| Security | Enable IP whitelisting for the Admin Web Portal | ✅ Done |
| Database | Apply `supabase_schema.sql` to your Supabase project | ✅ Done |
| SSL/TLS | Ensure all API communication is over HTTPS | ✅ Done |
| Monitoring | Configure winston logs to point to persistent storage | ✅ Done |

---

## Environment Configuration

### 1. Copy Environment File

```bash
cd backend
cp .env.example .env
```

### 2. Configure Critical Variables

Edit `.env` with production values:

```env
# REQUIRED: Supabase project URL
SUPABASE_URL=https://your-project.supabase.co

# REQUIRED: Supabase API keys
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# REQUIRED: Production origins only
CORS_ORIGIN=https://admin.coopvestafrica.org,https://coopvest.com
```

---

## Database Setup (Supabase)

### 1. Apply Schema

The project now uses Supabase for all data persistence. MongoDB is no longer required.

1.  Go to the **Supabase Dashboard**.
2.  Open the **SQL Editor**.
3.  Copy the contents of `backend/supabase_schema.sql` and run it.
4.  This will create the necessary tables (`profiles`, `kyc`, `savings`, `referrals`) and set up the `on_auth_user_created` trigger.

### 2. Authentication

Supabase Auth is the primary identity provider. Ensure that:
- Email confirmations are enabled in Supabase settings.
- Redirect URLs are correctly configured for your frontend.

---

## SSL/TLS Configuration

### Production HTTPS Enforcement

The server automatically enforces HTTPS in production mode:

```env
ENFORCE_HTTPS=true
HSTS_MAX_AGE=31536000  # 1 year
HSTS_INCLUDE_SUBDOMAINS=true
HSTS_PRELOAD=false
```

---

## IP Whitelisting

### Configure Admin IP Whitelist

In `.env`:

```env
# Comma-separated IP addresses
ADMIN_IP_WHITELIST=192.168.1.100,10.0.0.50,203.0.113.50
```

---

## Monitoring & Logging

### Log Configuration

```env
LOG_LEVEL=info
LOG_DIR=./logs
LOG_TO_FILE=true
LOG_MAX_SIZE=10485760  # 10MB
LOG_MAX_FILES=30       # Keep 30 days
```

---

## Deployment Commands

### Option 1: Direct Node.js

```bash
cd backend
npm install
NODE_ENV=production npm start
```

### Option 2: PM2 Process Manager

```bash
# Install PM2
npm install -g pm2

# Start in production
pm2 start src/server.js --name coopvest-api --env production
```

---

## Post-Deployment Verification

### 1. Health Check

```bash
curl https://api.coopvestafrica.org/health
```

Expected response:
```json
{
  "success": true,
  "message": "Coopvest API is running",
  "timestamp": "2026-03-25T12:00:00.000Z",
  "version": "1.0.0",
  "environment": "production"
}
```

### 2. Test Registration

Verify that registering a user in the API correctly creates:
1.  A user in **Supabase Auth**.
2.  A corresponding row in the **public.profiles** table via the trigger.

---

## Troubleshooting

### Supabase Connection Failed
- Check `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `.env`.
- Ensure the project is not paused in the Supabase dashboard.

### Admin IP Not Whitelisted
- Check `ADMIN_IP_WHITELIST` in `.env`.
- Verify the IP format (IPv4, IPv6, or CIDR).

---

## Support

For deployment support:
- Email: devops@coopvestafrica.org
- Documentation: [Internal Wiki]

---

**Last Updated:** March 2026  
**Maintained by:** Coopvest Africa DevOps Team
