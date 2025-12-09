# SIRA Community - Local Deployment (Production-Grade)

**Quick Start Guide for Local Deployment with Production-Grade Standards**

---

## ⚠️ Important: Production-Grade Standards

This local deployment follows **100% production-grade standards**:
- ✅ **NO shortcuts or exceptions**
- ✅ **mTLS required** for all database connections
- ✅ **TLS required** for all Redis connections
- ✅ **SSL certificates mandatory**
- ✅ **Production security features enabled**
- ✅ **Production environment mode**

---

## 🚀 Quick Start

### Prerequisites

1. **Infrastructure Services Running**
   ```bash
   cd sira-infra/infra/docker/compose
   docker compose -f docker-compose.infra.yml --env-file env.local up -d
   ```

2. **SSL Certificates Available**
   - Certificates must be at `/opt/sira-ai/ssl/`
   - Run: `./docker/scripts/setup-local-ssl.sh` for setup instructions

### Deployment

**Option 1: Using Deployment Script (Recommended)**
```bash
# Generate secret key
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"

# Update docker/env.community.app.local with generated secret
# Then run:
./docker/scripts/deploy-local.sh
```

**Option 2: Using Makefile**
```bash
# Setup environment
make setup-local ENV=local

# Generate and update secret key in .env
# Then:
make build ENV=local
make up ENV=local
make migrate ENV=local
```

**Option 3: Manual Deployment**
```bash
# 1. Create configuration
cp config/discourse.conf.local.example config/discourse.conf
cp docker/env.community.app.local .env

# 2. Generate secret and update .env
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"

# 3. Build and start
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    build

docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    up -d

# 4. Initialize database
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rake db:migrate
```

---

## ✅ Verification

```bash
# Check services
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    ps

# Test database (mTLS)
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').values"

# Test Redis (TLS)
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec app bundle exec rails runner "puts Discourse.redis.ping"

# Test application
curl -k https://localhost:8443/health
```

---

## 📚 Full Documentation

See [docs/DEPLOYMENT/LOCAL_DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT/LOCAL_DEPLOYMENT_GUIDE.md) for complete deployment guide.

---

**Access**: https://localhost:8443  
**Status**: ✅ Production-Grade Standards Enforced

