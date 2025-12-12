# SIRA Community Ground Rules

**Last Updated:** December 11, 2025  
**Status:** Production-Ready Deployment with Automated Build & Security Hardening

## Overview

This document contains ground rules specific to the SIRA Community application deployment, based on lessons learned from production-grade deployment and infrastructure integration.

---

## Infrastructure Integration Rules

### Service Discovery
- **ALWAYS use Docker service names**, not container names or `localhost`
  - ✅ Correct: `postgres-community:5432`
  - ❌ Wrong: `sira_community_postgres`, `localhost:5433`, `127.0.0.1:5433`
- **Network**: All services must be on `sira_infra_network` to access infrastructure services
- **Ports**: Use internal Docker network ports, not external mapped ports
  - PostgreSQL: `5432` (internal), not `5433` (external)
  - Redis: `6380` (TLS), `6379` (non-TLS)

### Database Configuration
- **Host**: Must be service name `postgres-community` (per infrastructure team)
- **Credentials**: 
  - Username: `sira_community_user`
  - Password: `community_app_password_2025`
  - Database: `sira_community`
- **SSL Mode**: `require` (mTLS with client certificates mandatory)
- **Certificate Paths**: Use writable locations (`/var/www/community/tmp/ssl/`) not read-only mounts

### Redis Configuration
- **Host**: Service name `redis` (from infrastructure)
- **Port**: `6380` (TLS required)
- **Password**: `redis_password`
- **Database**: `0` (for Discourse)
- **TLS**: Mandatory with client certificates

---

## Certificate Management Rules

### Mount Strategy
- **Source**: Certificates mounted from Windows host path (read-only, root-owned)
- **Destination**: Copy to writable location in entrypoint script
- **Location**: `/var/www/community/tmp/ssl/` (writable by `community` user)

### Entrypoint Requirements
- **MUST run as root** to copy certificates from read-only mounts
- **MUST switch to application user** (`community`) after copying
- **MUST set correct permissions**:
  - Certificates: `644` (readable by all)
  - Keys: `600` (readable by owner only)
  - Ownership: `community:community`

### Environment Variables
- **Export after copying**: Set environment variables pointing to writable certificate paths
- **Priority**: Environment variables > config file values
- **Both services**: Export for both PostgreSQL and Redis certificates

---

## SSL/TLS Configuration Rules

### PostgreSQL (mTLS)
- **Library**: `pg` gem requires string paths for all SSL parameters
- **Parameters Required**:
  - `sslmode`: `require` (or `verify-full`)
  - `sslcert`: Client certificate path
  - `sslkey`: Client key path
  - `sslrootcert`: CA certificate path
- **Implementation**: Add to `GlobalSetting.database_config` method
- **Source**: Read from environment variables (`POSTGRES_SSL_CERT`, etc.)

### Redis (TLS)
- **Library**: `redis-rb` gem requires OpenSSL objects for cert/key, string path for CA
- **Parameters Required**:
  - `ssl: true`
  - `ssl_params` hash with:
    - `cert`: `OpenSSL::X509::Certificate.new(File.read(cert_path))`
    - `key`: `OpenSSL::PKey::RSA.new(File.read(key_path))`
    - `ca_file`: String path to CA certificate
    - `verify_mode`: `OpenSSL::SSL::VERIFY_PEER`
- **Implementation**: Add to `GlobalSetting.redis_config` method
- **Source**: Read from environment variables (`REDIS_SSL_CERT`, etc.)

---

## Docker Configuration Rules

### Health Checks
- **Web Servers (App, Nginx)**: Use HTTP endpoint checks
  - App: `curl -f http://localhost:3000/srv/status`
  - Nginx: `wget --spider http://127.0.0.1/health` (use `127.0.0.1` not `localhost` in Alpine)
- **Background Workers (Sidekiq)**: Use process checks
  - `cat /proc/1/cmdline | grep -q sidekiq`
- **Start Periods**: 
  - App: 90s (needs time to preload)
  - Sidekiq: 60s
  - Nginx: 10s

### Puma Configuration
- **APP_ROOT**: MUST be set to `/var/www/community` via environment variable
- **Port Binding**: MUST listen on both:
  - Unix socket: `unix:///var/www/community/tmp/sockets/puma.sock`
  - TCP port: `tcp://0.0.0.0:3000` (for health checks and nginx)
- **Directories**: Entrypoint must create:
  - `tmp/sockets/` (for Unix socket)
  - `tmp/pids/` (for PID files)
  - `log/` (for log files)

### Entrypoint Script
- **User Context**: Start as root, switch to `community` user
- **Certificate Copying**: Copy from read-only mounts to writable location
- **Directory Creation**: Create required directories with correct ownership
- **Environment Variables**: Export all certificate paths after copying

---

## Problem-Solving Rules

### Debugging Approach
1. **Check logs with timestamps**: Always use `docker logs --timestamps` for chronological debugging
2. **Test manually first**: Verify health checks and endpoints work manually before relying on Docker health checks
3. **One service at a time**: Fix and verify each service individually
4. **Verify configuration**: Check environment variables, config files, and certificate paths

### POC Strategy
- **When to use**: For complex issues that need isolation (e.g., SSL/TLS connection problems)
- **Location**: Create POCs in `temp/` folder (can be deleted after verification)
- **Purpose**: Identify exact working configuration before applying to main application
- **Example**: `temp/postgres-connection-poc/`, `temp/redis-tls-poc/`

### Error Investigation
- **Check timestamps**: Use `--timestamps` flag to see when errors occurred
- **Check all logs**: App, Sidekiq, and Nginx logs may have different information
- **Verify connectivity**: Test connections manually (e.g., `curl`, `wget`, `psql`)
- **Check permissions**: Verify file permissions and ownership

---

## Configuration File Rules

### discourse.conf
- **Environment Variable Substitution**: Discourse does NOT automatically substitute `${VAR}` syntax
- **Password**: Set explicitly or rely on environment variable (set in docker-compose)
- **Host Names**: Use service names, not container names or localhost

### docker-compose.yml
- **Environment Variables**: Set all required variables explicitly
- **Certificate Paths**: Point to writable locations (where entrypoint copies them)
- **Health Checks**: Configure appropriate health check for each service type
- **Start Periods**: Set based on service startup time

---

## Production Readiness Checklist

### Before Deployment
- [ ] All services on `sira_infra_network`
- [ ] Correct service names in configuration
- [ ] Certificates mounted and copied by entrypoint
- [ ] **Server certificates have "Digital Signature" in Key Usage** (verify with `openssl x509 -text -noout`)
- [ ] **Certificate Key Usage verified** (Digital Signature, Key Encipherment, Data Encipherment)
- [ ] **Certificate Extended Key Usage verified** (TLS Web Server Authentication)
- [ ] **Certificate chain validated** (using `openssl verify`)
- [ ] Environment variables set correctly
- [ ] Health checks configured for all services
- [ ] APP_ROOT set for Puma
- [ ] Required directories created by entrypoint
- [ ] **Asset processor dependencies installed** (`pnpm install` in `frontend/asset-processor/`)
- [ ] **Asset processor built during Docker build** (verify `tmp/asset-processor.js` exists in image)
- [ ] **Docker BuildKit enabled** (`DOCKER_BUILDKIT=1`)
- [ ] **Security hardening applied** (non-root user, minimal image, file permissions)
- [ ] **Performance optimizations enabled** (YJIT, connection pooling, thread optimization)

### After Deployment
- [ ] All services show "healthy" status
- [ ] No connection errors in logs
- [ ] Health endpoints respond correctly
- [ ] Services can communicate (nginx → app, app → postgres, app → redis)
- [ ] **No SSL certificate errors in browser** (no `ERR_SSL_KEY_USAGE_INCOMPATIBLE`)
- [ ] **HTTPS connection works** (test in Chrome, Edge, Firefox)
- [ ] **Asset processor exists** (`ls -lh /var/www/community/tmp/asset-processor.js`)
- [ ] **No 500 errors on page load** (test root path `/`)
- [ ] **Application responds quickly** (< 1 second for health check)
- [ ] **Resource usage within limits** (check `docker stats`)

---

## Common Pitfalls to Avoid

1. **Using localhost instead of service names** → Connection failures
2. **Using external ports instead of internal** → Connection failures
3. **Not copying certificates to writable location** → Permission denied errors
4. **Wrong SSL parameter formats** → Library-specific requirements not met
5. **Missing APP_ROOT environment variable** → Puma can't find directories
6. **Health checks using wrong method** → Always unhealthy status
7. **Not using timestamps in logs** → Can't track error chronology
8. **Missing "Digital Signature" in certificate Key Usage** → `ERR_SSL_KEY_USAGE_INCOMPATIBLE` browser error
9. **Using client certificates as server certificates** → Certificate type mismatch errors
10. **Not verifying certificate Key Usage after generation** → Browser compatibility issues
11. **Asset processor not built during Docker build** → 500 errors on page load, slow startup
12. **Missing asset-processor dependencies** → Build failures during Docker build
13. **Not using BuildKit** → Slower builds, less efficient caching
14. **Running as root user** → Security vulnerability
15. **Not setting resource limits** → Resource exhaustion, poor performance
16. **Skipping health checks** → No visibility into service status
17. **Not verifying asset processor after build** → Runtime failures
18. **Including unnecessary files in Docker image** → Larger images, slower builds

---

## 🔒 SSL/TLS Certificate Rules (Production-Grade)
- **CRITICAL: Server certificates MUST include "Digital Signature" in Key Usage** - Required by modern browsers (Chrome, Edge, Firefox)
- **Key Usage Requirements for Server Certificates**:
  - ✅ Digital Signature (MANDATORY - browsers reject certificates without this)
  - ✅ Key Encipherment
  - ✅ Data Encipherment (optional for RSA, required for some algorithms)
- **Extended Key Usage Requirements**:
  - ✅ TLS Web Server Authentication (1.3.6.1.5.5.7.3.1) - MANDATORY
- **Certificate Generation**:
  - Use OpenSSL configuration files with proper Key Usage extensions
  - Always include `digitalSignature` in Key Usage for server certificates
  - Set Key Usage as `critical` to enforce browser validation
  - Include all required Subject Alternative Names (SANs)
- **Certificate Validation**:
  - Verify Key Usage includes Digital Signature before deployment
  - Verify Extended Key Usage includes serverAuth
  - Verify certificate chain is valid
  - Verify certificate purpose shows "SSL server: Yes"
- **Certificate Regeneration**:
  - When regenerating certificates, use proper OpenSSL config with Key Usage
  - Never use client certificates as server certificates
  - Always verify certificate after generation
  - Test certificate in browser to ensure no Key Usage errors
- **Certificate Files**:
  - Server certificates: Use `*-server.crt` and `*-server.key`
  - Client certificates: Use `*-client.crt` and `*-client.key`
  - Never mix client and server certificate types
- **Browser Compatibility**:
  - Certificates must pass Chrome/Edge validation (strictest)
  - Certificates must pass Firefox validation
  - Certificates must pass Safari validation
  - Test in all major browsers before production deployment
- **Troubleshooting Certificate Errors**:
  - If `ERR_SSL_KEY_USAGE_INCOMPATIBLE` appears, verify certificate has "Digital Signature" in Key Usage
  - Always verify certificate Key Usage, Extended Key Usage, and certificate chain before deployment

## Docker Build & Deployment Rules (Production-Grade)

### Asset Processor Build (CRITICAL)
- **MUST be built during Docker build**, not at runtime
- **Dependencies**: Install `pnpm install` in `frontend/asset-processor/` before building
- **Build Process**: `rake assets:precompile:asset_processor` runs during Docker build
- **Verification**: Dockerfile verifies `tmp/asset-processor.js` exists after build (fails if missing)
- **Runtime Fallback**: Entrypoint script attempts build if missing (safety net only)
- **Why**: Prevents 500 errors, faster startup, no runtime Node.js dependency

### Automated Deployment
- **Primary Method**: Use `docker/build-and-deploy.sh` for automated deployment
- **Features**: Pre-flight checks, health checks, error handling, logging
- **Manual Method**: `docker compose build && docker compose up -d` (fallback)
- **BuildKit**: Always use `DOCKER_BUILDKIT=1` for optimized builds

### Dockerfile Best Practices
- **Layer Caching**: Dependencies installed before application code
- **Security**: Use `--no-install-recommends` to reduce attack surface
- **Asset Precompilation**: Assets compiled during build, not runtime
- **Non-Root User**: Application runs as `community` user (UID 1000)
- **File Permissions**: Strict permissions (`u=rwX,g=rX,o=`)
- **Build Tools**: Keep build-essential for native gem compilation (or use multi-stage build)

### Build Optimization
- **BuildKit**: Enable for faster, more efficient builds
- **.dockerignore**: Exclude unnecessary files (docs, tests, .git, etc.)
- **Layer Ordering**: Copy dependency files first, then application code
- **Asset Processor**: Build before main asset precompilation

### Security Hardening
- **Non-Root Execution**: All services run as non-root user
- **Minimal Base Image**: Use `ruby:3.3-slim` (Debian-based, minimal)
- **File Permissions**: Lock down file permissions
- **Certificate Security**: Certificates with restricted permissions (644 for certs, 600 for keys)
- **Resource Limits**: CPU and memory limits configured in docker-compose
- **Health Checks**: All services have health checks configured

### Performance Optimizations
- **YJIT**: Enabled for Ruby JIT compilation (`DISCOURSE_ENABLE_YJIT: "true"`)
- **Connection Pooling**: Database pool size optimized (40 connections)
- **Thread Optimization**: Puma threads reduced to 8-12 (from 8-32)
- **Log Level**: Reduced to `warn` for production (from `info`)
- **Asset Precompilation**: All assets compiled at build time
- **Connection Timeout**: Reduced to 2 seconds (from 5)

### Entrypoint Script Enhancements
- **Asset Processor Check**: Verifies `tmp/asset-processor.js` exists at startup
- **Runtime Build Fallback**: Attempts to build if missing (requires pnpm/dependencies)
- **Error Handling**: Graceful handling of missing dependencies
- **Certificate Management**: Copies certificates from read-only mounts

## Reference Documents

- `docker/DEPLOYMENT.md` - Comprehensive deployment guide
- `docker/SECURITY.md` - Security configuration and best practices
- `docker/PRODUCTION_READY.md` - Production readiness summary
- `docker/build-and-deploy.sh` - Automated deployment script
- `DEPLOYMENT_FIXES_SUMMARY.md` - Detailed summary of all fixes applied
- `CERTIFICATE_REGENERATION_SUMMARY.md` - Certificate regeneration procedures and standards
- `SSL_CERTIFICATE_KEY_USAGE_FIX.md` - Certificate Key Usage issue analysis
- `temp/postgres-connection-poc/` - PostgreSQL connection POC
- `temp/redis-tls-poc/` - Redis TLS connection POC
- Infrastructure team docs:
  - `APP_TEAM_CONNECTION_GUIDE.md`
  - `APP_TEAM_HANDOFF_SUMMARY.md`

---

## Quick Reference Commands

### Deployment
```bash
# Automated deployment (recommended)
cd docker
./build-and-deploy.sh

# Manual deployment
cd docker
DOCKER_BUILDKIT=1 docker compose -f docker-compose.sira-community.app.yml build
docker compose -f docker-compose.sira-community.app.yml up -d

# Rebuild with no cache
./build-and-deploy.sh --no-cache
```

### Service Management
```bash
# Check all services status
docker ps --filter "name=sira-community" --format "table {{.Names}}\t{{.Status}}"

# Check logs with timestamps
docker logs sira-community-app --timestamps --tail 50
docker logs sira-community-sidekiq --timestamps --tail 50
docker logs sira-community-nginx --timestamps --tail 50

# Test health endpoints
docker exec sira-community-app curl -f http://localhost:3000/srv/status
docker exec sira-community-nginx wget -q -O- http://127.0.0.1/health
docker exec sira-community-sidekiq sh -c "cat /proc/1/cmdline | grep -q sidekiq && echo 'OK'"

# Recreate services
docker compose -f docker/docker-compose.sira-community.app.yml up -d --force-recreate
```

### Asset Processor Verification
```bash
# Check if asset processor exists
docker exec sira-community-app ls -lh /var/www/community/tmp/asset-processor.js

# Verify asset processor size (should be ~18MB)
docker exec sira-community-app du -h /var/www/community/tmp/asset-processor.js

# Test asset processor build (if missing)
docker exec sira-community-app bash -c "cd /var/www/community/frontend/asset-processor && pnpm install && pnpm -C=. node build.js > /var/www/community/tmp/asset-processor.js"
```

### Performance Monitoring
```bash
# Check resource usage
docker stats sira-community-app sira-community-sidekiq sira-community-nginx

# Check application performance
docker exec sira-community-app bundle exec rails runner "puts 'Rails loaded in: ' + (Time.now - $start_time).to_s" &
$start_time = Time.now
```

### Debugging
```bash
# Enter container
docker exec -it sira-community-app bash

# Check environment variables
docker exec sira-community-app env | grep -E "(DISCOURSE|COMMUNITY|POSTGRES|REDIS)"

# Test database connection
docker exec sira-community-app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"

# Test Redis connection
docker exec sira-community-app bundle exec rails runner "puts Discourse.redis.ping"
```
