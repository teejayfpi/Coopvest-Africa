# Coopvest Africa - Production Deployment Guide

**Version:** 1.0  
**Date:** January 2026

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Environment Configuration](#environment-configuration)
3. [Database Setup](#database-setup)
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
| Environment | Configure JWT_SECRET, MONGODB_URI, and CORS_ORIGIN in .env | ✅ Done |
| Security | Enable IP whitelisting for the Admin Web Portal | ✅ Done |
| Database | Run initial database migrations and seed admin users | ✅ Done |
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
# REQUIRED: Generate a secure JWT secret
JWT_SECRET=your-256-bit-random-secret-here

# REQUIRED: MongoDB connection string
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/coopvest

# REQUIRED: Production origins only
CORS_ORIGIN=https://admin.coopvestafrica.org,https://coopvest.com
```

### 3. Generate Secure JWT Secret

```bash
# Generate a 64-character hex secret
openssl rand -hex 64
```

---

## Database Setup

### 1. Run Migrations

```bash
# Run pending database migrations
npm run migrate

# Check migration status
npm run migrate:status
```

### 2. Seed Admin User

```bash
# Create default admin user
npm run migrate:seed-admin
```

**Default admin credentials:**
- Email: `admin@coopvestafrica.org`
- Password: `Admin@123` (change immediately after first login!)

### 3. Create Indexes

The migration script automatically creates indexes for:
- Users (email, phone, createdAt)
- Referrals (referralCode, referrerId, referredEmail)
- Loans (userId, status, createdAt)
- Tickets (userId, status, priority)
- AuditLogs (createdAt, action)

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

### Nginx SSL Configuration

If using Nginx as a reverse proxy:

```nginx
server {
    listen 80;
    server_name api.coopvestafrica.org;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name api.coopvestafrica.org;
    
    ssl_certificate /etc/ssl/certs/coopvest.crt;
    ssl_certificate_key /etc/ssl/private/coopvest.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## IP Whitelisting

### Configure Admin IP Whitelist

In `.env`:

```env
# Comma-separated IP addresses
ADMIN_IP_WHITELIST=192.168.1.100,10.0.0.50,203.0.113.50

# Or use CIDR notation for ranges
ADMIN_IP_WHITELIST=192.168.1.0/24,10.0.0.0/16
```

### How It Works

- Admin routes (`/api/v1/admin/*`) are protected
- Requests from non-whitelisted IPs receive `403 Forbidden`
- Health check endpoints (`/health`, `/ws/stats`) are always accessible
- X-Forwarded-For header is respected for proxied requests

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

### Log File Structure

```
logs/
├── coopvest-2026-01-04.log      # Daily combined logs
├── coopvest-2026-01-04.error.log # Daily error logs
└── coopvest-error-2026-01-04.log # Long-term error archive
```

### Log Rotation (PM2)

If using PM2 for process management:

```bash
# Install log rotate addon
pm2 install pm2-logrotate

# Configure
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 30
```

### External Log Services (Optional)

For DataDog, Splunk, or other log aggregators:

```env
LOG_EXTERNAL_SERVICE=true
LOG_EXTERNAL_URL=https://logs.service.com/api/v1/logs
```

---

## Deployment Commands

### Option 1: Direct Node.js

```bash
cd backend
npm install
npm run migrate
NODE_ENV=production npm start
```

### Option 2: PM2 Process Manager

```bash
# Install PM2
npm install -g pm2

# Create ecosystem file
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'coopvest-api',
    script: 'src/server.js',
    instances: 2,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: 8080
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 8080,
      JWT_SECRET: 'your-production-secret'
    }
  }]
};
EOF

# Start in production
pm2 start ecosystem.config.js --env production

# Setup startup script
pm2 startup
pm2 save
```

### Option 3: Docker

```dockerfile
# Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN mkdir -p logs
RUN npm run migrate
EXPOSE 8080
CMD ["node", "src/server.js"]
```

```bash
# Build and run
docker build -t coopvest-api .
docker run -d -p 8080:8080 --env-file .env coopvest-api
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
  "timestamp": "2026-01-04T12:00:00.000Z",
  "version": "1.0.0",
  "environment": "production"
}
```

### 2. Test Admin Endpoints

```bash
# Get admin token first
curl -X POST https://api.coopvestafrica.org/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@coopvestafrica.org","password":"Admin@123"}'

# Test admin endpoint
curl https://api.coopvestafrica.org/api/v1/admin/referrals/stats \
  -H "Authorization: Bearer <token>"
```

### 3. Verify Security Headers

```bash
curl -I https://api.coopvestafrica.org/health
```

Expected headers:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
```

### 4. Check Logs

```bash
tail -f logs/coopvest-$(date +%Y-%m-%d).log
```

---

## Troubleshooting

### MongoDB Connection Failed

```bash
# Test MongoDB connection
mongosh "mongodb+srv://your-cluster.mongodb.net/coopvest"
```

### Admin IP Not Whitelisted

- Check `ADMIN_IP_WHITELIST` in `.env`
- Verify the IP format (IPv4, IPv6, or CIDR)
- Check proxy headers if behind load balancer

### JWT Token Issues

- Ensure `JWT_SECRET` is set in `.env`
- Tokens expire after 7 days (configurable)
- Use refresh token endpoint to get new access token

### SSL/HTTPS Issues

- Verify `ENFORCE_HTTPS=true` in `.env`
- Check reverse proxy SSL configuration
- Ensure HSTS header is present in responses

---

## Rollback Procedure

If issues occur after deployment:

```bash
# PM2 rollback
pm2 rollback coopvest-api

# Docker rollback
docker run -d -p 8080:8080 coopvest-api:previous-version

# Restore database from backup (if needed)
mongorestore --uri="mongodb+srv://..." --drop backup/
```

---

## Support

For deployment support:
- Email: devops@coopvestafrica.org
- Documentation: [Internal Wiki]
- On-call: [PagerDuty]

---

**Last Updated:** January 2026  
**Maintained by:** Coopvest Africa DevOps Team
