# SIRA Community - Production-Grade Deployment Plan

**Date**: January 2025  
**Status**: Implementation Plan  
**Security Level**: Enterprise-Grade (mTLS, TLS 1.2+, Client Certificates)

---

## 🎯 Executive Summary

This plan outlines the comprehensive steps required to bring SIRA Community to **production-grade** standards, aligned with SIRA AI infrastructure architecture and security best practices from `sira-app`.

### Key Objectives
1. ✅ **Enterprise-Grade Security**: mTLS, client certificates, TLS 1.2+
2. ✅ **Infrastructure Integration**: Connect to `sira_infra_network` for shared services
3. ✅ **Production Configuration**: Proper environment management, secrets, SSL
4. ✅ **Security Hardening**: Non-root users, security headers, rate limiting
5. ✅ **Monitoring & Health**: Comprehensive health checks and logging

---

## 📋 Current State Analysis

### ✅ What's Ready
- Docker setup with docker-compose.yml
- Multi-stage Dockerfile
- Nginx reverse proxy configuration
- Environment file templates
- Database migrations structure
- Integration documentation

### ❌ Critical Gaps
1. **Missing Production Configuration**: No `config/discourse.conf`
2. **No SSL Certificate Support**: Missing mTLS client certificate mounting
3. **Infrastructure Disconnection**: Not connected to `sira_infra_network`
4. **Internal Services**: Running own postgres/redis instead of using infra
5. **Security Gaps**: Missing client certificate authentication
6. **Environment Variables**: Not aligned with infrastructure requirements
7. **Database SSL**: Not configured for mTLS connections
8. **Asset Precompilation**: Not verified in production build

---

## 🔒 Security Requirements (From Infrastructure)

### Mandatory Security Features
1. **Client Certificates Required** for all database connections
   - PostgreSQL: `/opt/sira-ai/ssl/postgres/postgres-client.crt` + `.key`
   - Redis: `/opt/sira-ai/ssl/redis/redis-client.crt` + `.key`
   - CA Certificate: `/opt/sira-ai/ssl/ca/ca.crt`

2. **TLS 1.2+ Only** for all connections
3. **No Password-Only Authentication** - certificates mandatory
4. **Network Isolation** - services on internal networks only
5. **Non-Root Users** in containers

### Infrastructure Connection Details
- **Network**: `sira_infra_network` (external)
- **PostgreSQL**: `postgres:5432` (requires mTLS)
- **Redis**: `redis:6380` (TLS) or `6379` (non-TLS, if configured)
- **SSL Path**: `/opt/sira-ai/ssl/` (mounted read-only)

---

## 📝 Implementation Plan

### Phase 1: Infrastructure Integration

#### 1.1 Update docker-compose.yml
**Changes Required**:
- Remove internal `postgres` and `redis` services
- Connect to `sira_infra_network` (external)
- Mount SSL certificates from `/opt/sira-ai/ssl`
- Update service dependencies
- Add SSL certificate paths to environment variables

**Files to Modify**:
- `docker-compose.yml`

#### 1.2 Update Environment Files
**Changes Required**:
- Add SSL certificate path variables
- Update database connection strings for mTLS
- Add Redis TLS configuration
- Remove internal service references
- Add infrastructure network configuration

**Files to Modify**:
- `docker/env.prod`
- `docker/env.example`
- All environment files

### Phase 2: Database Configuration

#### 2.1 Update database.yml
**Changes Required**:
- Add SSL configuration for PostgreSQL
- Support client certificate authentication
- Configure SSL mode: `require`
- Add certificate paths

**Files to Modify**:
- `config/database.yml`

#### 2.2 Create discourse.conf
**Changes Required**:
- Production hostname
- Database connection with SSL
- Redis connection with TLS
- Secret key base (from environment)
- SMTP configuration
- Security settings

**Files to Create**:
- `config/discourse.conf` (production template)

### Phase 3: Docker Security Hardening

#### 3.1 Update Dockerfile
**Changes Required**:
- Ensure non-root user (already has `community` user)
- Add SSL certificate directory structure
- Verify certificate paths
- Add health check improvements

**Files to Modify**:
- `Dockerfile`

#### 3.2 Update docker-compose.yml Security
**Changes Required**:
- Mount SSL certificates read-only
- Set proper user permissions
- Add security labels
- Configure resource limits

**Files to Modify**:
- `docker-compose.yml`

### Phase 4: Nginx Security Enhancement

#### 4.1 Update nginx.conf
**Changes Required**:
- Add security headers (HSTS, CSP, etc.)
- Enhance rate limiting
- Add SSL client certificate validation (if needed)
- Improve logging

**Files to Modify**:
- `docker/nginx/nginx.conf`

### Phase 5: Initialization & Validation

#### 5.1 Create Initialization Scripts
**Changes Required**:
- SSL certificate validation script
- Database connection test script
- Health check improvements
- Pre-deployment validation

**Files to Create**:
- `docker/scripts/validate-ssl.sh`
- `docker/scripts/test-db-connection.sh`
- `docker/scripts/pre-deploy-check.sh`

### Phase 6: Documentation Updates

#### 6.1 Update Documentation
**Changes Required**:
- Update deployment guides with SSL requirements
- Add certificate setup instructions
- Update integration guide
- Add troubleshooting for SSL issues

**Files to Modify**:
- `docker/README.md`
- `DEPLOYMENT_READINESS_CHECKLIST.md`
- `INTEGRATION_GUIDE.md`

---

## 🔧 Technical Implementation Details

### Database Connection (PostgreSQL with mTLS)

**Connection String Format**:
```
postgresql://username:password@postgres:5432/database_name?sslmode=require&sslcert=/opt/sira-ai/ssl/postgres/postgres-client.crt&sslkey=/opt/sira-ai/ssl/postgres/postgres-client.key&sslrootcert=/opt/sira-ai/ssl/ca/ca.crt
```

**Rails Configuration**:
```ruby
production:
  adapter: postgresql
  host: <%= ENV['DISCOURSE_DB_HOST'] || 'postgres' %>
  port: <%= ENV['DISCOURSE_DB_PORT'] || 5432 %>
  database: <%= ENV['DISCOURSE_DB_NAME'] || 'community' %>
  username: <%= ENV['DISCOURSE_DB_USERNAME'] || 'community' %>
  password: <%= ENV['DISCOURSE_DB_PASSWORD'] %>
  sslmode: require
  sslcert: /opt/sira-ai/ssl/postgres/postgres-client.crt
  sslkey: /opt/sira-ai/ssl/postgres/postgres-client.key
  sslrootcert: /opt/sira-ai/ssl/ca/ca.crt
```

### Redis Connection (with TLS)

**Connection Configuration**:
```ruby
redis_host = "redis"
redis_port = 6380  # TLS port
redis_password = "your-password"
redis_ssl = true
redis_ssl_cert = "/opt/sira-ai/ssl/redis/redis-client.crt"
redis_ssl_key = "/opt/sira-ai/ssl/redis/redis-client.key"
redis_ssl_ca = "/opt/sira-ai/ssl/ca/ca.crt"
```

### Environment Variables Structure

```bash
# Infrastructure Connection
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=community_prod
POSTGRES_USER=community
POSTGRES_PASSWORD=secure-password
POSTGRES_SSL_MODE=require
POSTGRES_SSL_CERT=/opt/sira-ai/ssl/postgres/postgres-client.crt
POSTGRES_SSL_KEY=/opt/sira-ai/ssl/postgres/postgres-client.key
POSTGRES_SSL_CA=/opt/sira-ai/ssl/ca/ca.crt

REDIS_HOST=redis
REDIS_PORT=6380
REDIS_PASSWORD=secure-password
REDIS_SSL=true
REDIS_SSL_CERT=/opt/sira-ai/ssl/redis/redis-client.crt
REDIS_SSL_KEY=/opt/sira-ai/ssl/redis/redis-client.key
REDIS_SSL_CA=/opt/sira-ai/ssl/ca/ca.crt

# SSL Certificate Paths
SSL_CERTS_DIR=/opt/sira-ai/ssl
SSL_CA_PATH=/opt/sira-ai/ssl/ca/ca.crt
```

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] SSL certificates available at `/opt/sira-ai/ssl/`
- [ ] Infrastructure services running and healthy
- [ ] `sira_infra_network` exists and accessible
- [ ] Environment variables configured
- [ ] `config/discourse.conf` created with production values
- [ ] Secret keys generated (not placeholders)

### Deployment Steps
1. [ ] Validate SSL certificates: `docker/scripts/validate-ssl.sh`
2. [ ] Build Docker images: `docker-compose build`
3. [ ] Start services: `docker-compose up -d`
4. [ ] Verify health checks: `docker-compose ps`
5. [ ] Test database connection: `docker-compose exec app bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')"`
6. [ ] Run migrations: `docker-compose exec app bundle exec rake db:migrate`
7. [ ] Seed initial data: `docker-compose exec app bundle exec rake db:seed_fu`
8. [ ] Verify application: `curl https://community.sira.ai/health`

### Post-Deployment Verification
- [ ] All services healthy
- [ ] Database connection working with mTLS
- [ ] Redis connection working with TLS
- [ ] Application accessible via HTTPS
- [ ] Health endpoints responding
- [ ] Logs show no SSL/certificate errors

---

## 🔐 Security Validation

### Certificate Validation
```bash
# Verify certificates exist
ls -la /opt/sira-ai/ssl/postgres/postgres-client.*
ls -la /opt/sira-ai/ssl/redis/redis-client.*
ls -la /opt/sira-ai/ssl/ca/ca.crt

# Verify certificate validity
openssl x509 -in /opt/sira-ai/ssl/postgres/postgres-client.crt -text -noout
```

### Connection Testing
```bash
# Test PostgreSQL connection
docker-compose exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1')"

# Test Redis connection
docker-compose exec app bundle exec rails runner "puts Discourse.redis.ping"
```

---

## 📊 Success Criteria

### Security
- ✅ All database connections use mTLS with client certificates
- ✅ No password-only authentication
- ✅ TLS 1.2+ enforced
- ✅ Non-root users in containers
- ✅ Network isolation maintained

### Functionality
- ✅ Application starts without errors
- ✅ Database migrations run successfully
- ✅ Redis caching works
- ✅ Health checks pass
- ✅ HTTPS accessible

### Integration
- ✅ Connected to `sira_infra_network`
- ✅ Using shared PostgreSQL from infrastructure
- ✅ Using shared Redis from infrastructure
- ✅ SSL certificates properly mounted

---

## 🚀 Implementation Priority

### Critical (Must Do First)
1. Update docker-compose.yml for infrastructure integration
2. Create production discourse.conf
3. Update database.yml for SSL
4. Update environment files

### High Priority
5. Update Dockerfile security
6. Enhance nginx configuration
7. Create validation scripts

### Medium Priority
8. Update documentation
9. Add monitoring improvements
10. Performance optimizations

---

## 📚 Reference Architecture

### SIRA App Best Practices (Applied to Community)
- ✅ External network for infrastructure (`sira_infra_network`)
- ✅ SSL certificates mounted read-only
- ✅ Non-root users in containers
- ✅ Comprehensive health checks
- ✅ Environment-based configuration
- ✅ Security headers in Nginx
- ✅ Proper logging and monitoring

### Infrastructure Requirements
- ✅ Client certificates mandatory
- ✅ TLS 1.2+ only
- ✅ Network isolation
- ✅ Service discovery via Docker networks

---

## 🎯 Expected Outcomes

After implementation:
1. **100% Production-Grade Security**: Enterprise-level mTLS, certificates, encryption
2. **Infrastructure Integration**: Seamless connection to SIRA infrastructure
3. **Security Compliance**: Meets all infrastructure security requirements
4. **Operational Readiness**: Health checks, monitoring, logging in place
5. **Deployment Ready**: All gaps closed, ready for production deployment

---

**Status**: Ready for Implementation  
**Estimated Time**: 2-3 hours  
**Risk Level**: Low (following proven patterns from sira-app)

