# SIRA Community - Local Deployment Guide (Production-Grade)

**Status**: ✅ Production-Grade Standards  
**Security Level**: 🔒 Enterprise-Grade (mTLS, TLS 1.2+, Client Certificates)  
**NO SHORTCUTS**: All production security features enabled

---

## 🎯 Overview

This guide deploys SIRA Community locally with **100% production-grade standards**. There are **NO shortcuts or exceptions** - all security features, mTLS requirements, and production configurations are enforced even for local deployment.

---

## 🔒 Production-Grade Requirements

### Mandatory Security Features
- ✅ **Mutual TLS (mTLS)** - All database connections require client certificates
- ✅ **TLS 1.2+** - All communications encrypted
- ✅ **Client Certificates** - Mandatory for PostgreSQL and Redis
- ✅ **SSL Certificates** - Required for HTTPS
- ✅ **Production Environment** - `RAILS_ENV=production`
- ✅ **Security Headers** - All production security headers enabled
- ✅ **Rate Limiting** - Enabled
- ✅ **CSRF Protection** - Enabled

### Infrastructure Requirements
- ✅ **Infrastructure Services Running** - PostgreSQL and Redis from infrastructure
- ✅ **Network Connection** - Connected to `sira_infra_network`
- ✅ **SSL Certificates** - Available at `/opt/sira-ai/ssl/`

---

## 📋 Prerequisites

### 1. Infrastructure Services
Infrastructure services must be running and accessible:

```bash
# Start infrastructure services
cd sira-infra/infra/docker/compose
docker compose -f docker-compose.infra.yml --env-file env.local up -d

# Verify infrastructure network exists
docker network inspect sira_infra_network
```

### 2. SSL Certificates
SSL certificates must be available at `/opt/sira-ai/ssl/`:

```
/opt/sira-ai/ssl/
├── ca/
│   └── ca.crt
├── postgres/
│   ├── postgres-client.crt
│   └── postgres-client.key
└── redis/
    ├── redis-client.crt
    └── redis-client.key
```

**Note**: These certificates come from the infrastructure setup. If they're not available, you must obtain them from the infrastructure team.

### 3. Required Tools
- Docker and Docker Compose
- Ruby (for secret generation)
- OpenSSL (for certificate validation)

---

## 🚀 Deployment Steps

### Step 1: Validate Prerequisites

```bash
# Check infrastructure network
docker network inspect sira_infra_network

# Validate SSL certificates
./docker/scripts/validate-ssl.sh
```

### Step 2: Generate Secure Secrets

```bash
# Generate secret key base (128-character hex string)
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
```

Copy the generated secret and update `docker/env.community.app.local`:
```bash
COMMUNITY_SECRET_KEY_BASE=<generated-secret>
```

### Step 3: Create Configuration Files

```bash
# Create discourse.conf from template
cp config/discourse.conf.local.example config/discourse.conf

# Edit config/discourse.conf and update:
# - hostname = "localhost"
# - secret_key_base = <from environment variable>
# - smtp_password = <your-sendgrid-api-key>
```

```bash
# Create .env file
cp docker/env.community.app.local .env

# Edit .env and update:
# - COMMUNITY_SECRET_KEY_BASE=<generated-secret>
# - COMMUNITY_SMTP_PASSWORD=<sendgrid-api-key>
# - SIRA_API_KEY=<sira-api-key>
# - DISCOURSE_API_KEY=<discourse-api-key>
# - DISCOURSE_SSO_SECRET=<sso-secret>
```

### Step 4: Run Pre-Deployment Validation

```bash
./docker/scripts/pre-deploy-check.sh
```

This validates:
- Configuration files exist
- SSL certificates are valid
- Infrastructure network is accessible
- All required settings are configured

### Step 5: Deploy Using Script (Recommended)

```bash
# Make script executable
chmod +x docker/scripts/deploy-local.sh

# Run deployment script
./docker/scripts/deploy-local.sh
```

The script will:
1. Validate prerequisites
2. Check SSL certificates
3. Build Docker images
4. Start services
5. Run database migrations
6. Seed initial data
7. Verify deployment

### Step 5 (Alternative): Manual Deployment

```bash
# Build images
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    build

# Start services
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    up -d

# Wait for services to be ready
sleep 30

# Run migrations
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rake db:migrate

# Seed initial data
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rake db:seed_fu
```

---

## ✅ Verification

### Check Service Status

```bash
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    ps
```

All services should show as "healthy" or "running".

### Test Database Connection (mTLS)

```bash
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').values"
```

Should output: `[["1"]]`

### Test Redis Connection (TLS)

```bash
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rails runner "puts Discourse.redis.ping"
```

Should output: `PONG`

### Test HTTP Endpoint

```bash
# Health check
curl -k https://localhost:8443/health

# Application
curl -k https://localhost:8443
```

---

## 🔧 Configuration Details

### Environment Variables

The local environment (`docker/env.community.app.local`) is configured with:
- ✅ Production-grade database connection (mTLS)
- ✅ Production-grade Redis connection (TLS)
- ✅ Production security settings
- ✅ SSL certificate paths
- ✅ Infrastructure network connection

### Security Features Enabled

Even for local deployment:
- ✅ `RAILS_ENV=production`
- ✅ `FORCE_HTTPS=true`
- ✅ `ENABLE_RATE_LIMITING=true`
- ✅ `ENABLE_CSRF_PROTECTION=true`
- ✅ `ENABLE_SECURITY_HEADERS=true`
- ✅ mTLS for database connections
- ✅ TLS for Redis connections

---

## 🐛 Troubleshooting

### SSL Certificate Issues

**Error**: `SSL certificate directory not found`

**Solution**: Ensure SSL certificates are available at `/opt/sira-ai/ssl/`. These come from infrastructure setup.

```bash
# Check if certificates exist
ls -la /opt/sira-ai/ssl/ca/ca.crt
ls -la /opt/sira-ai/ssl/postgres/postgres-client.*
ls -la /opt/sira-ai/ssl/redis/redis-client.*
```

### Infrastructure Network Not Found

**Error**: `sira_infra_network not found`

**Solution**: Start infrastructure services first:

```bash
cd sira-infra/infra/docker/compose
docker compose -f docker-compose.infra.yml --env-file env.local up -d
```

### Database Connection Failed

**Error**: `Connection refused` or `SSL required`

**Solution**: 
1. Verify infrastructure PostgreSQL is running
2. Verify SSL certificates are mounted
3. Check certificate paths in environment variables
4. Verify mTLS is enabled in infrastructure

### Application Won't Start

**Error**: `Assets have not been precompiled`

**Solution**: Assets are precompiled during Docker build. If this fails:
```bash
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    build --no-cache
```

---

## 📊 Service Access

### Application URLs
- **HTTPS**: `https://localhost:8443`
- **HTTP**: `http://localhost:8080` (redirects to HTTPS)

### Service Ports
- **Nginx HTTP**: 8080
- **Nginx HTTPS**: 8443
- **App (internal)**: 3000 (not exposed externally)

### Container Names
- `sira-community-app` - Main application
- `sira-community-sidekiq` - Background jobs
- `sira-community-nginx` - Reverse proxy

---

## 🔐 Security Validation

### Verify mTLS is Working

```bash
# Check PostgreSQL connection uses SSL
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SHOW ssl').values"
```

Should show SSL is enabled.

### Verify TLS is Working

```bash
# Check Redis connection uses TLS
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rails runner "puts Discourse.redis.info('server')"
```

Should show TLS connection details.

---

## 📝 Important Notes

### NO Development Shortcuts
- ❌ No `RAILS_ENV=development`
- ❌ No password-only database connections
- ❌ No unencrypted Redis connections
- ❌ No disabled security features
- ❌ No self-signed certificates (use infrastructure certificates)

### Production Standards
- ✅ All security features enabled
- ✅ mTLS mandatory for databases
- ✅ TLS mandatory for Redis
- ✅ SSL certificates required
- ✅ Production environment mode
- ✅ Security headers enabled
- ✅ Rate limiting enabled

---

## 🎉 Success Criteria

Deployment is successful when:
- ✅ All services are running and healthy
- ✅ Database connection works with mTLS
- ✅ Redis connection works with TLS
- ✅ Application is accessible via HTTPS
- ✅ Health checks pass
- ✅ No SSL/certificate errors in logs

---

## 📚 Related Documentation

- [Production-Grade Deployment Plan](./PRODUCTION_GRADE_DEPLOYMENT_PLAN.md)
- [Docker Deployment Guide](./DOCKER_DEPLOYMENT_GUIDE.md)
- [Security Guide](../SECURITY/SECURITY.md)
- [Integration Guide](../INTEGRATION/INTEGRATION_GUIDE.md)

---

**Status**: ✅ Production-Grade Local Deployment Ready  
**Security Level**: 🔒 Enterprise-Grade  
**Last Updated**: January 2025



