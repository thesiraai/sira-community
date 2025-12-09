# SIRA Community Deployment Fixes Summary

**Date:** December 9, 2025  
**Status:** ✅ All Services Healthy

## Overview

This document summarizes all fixes applied to bring the SIRA Community application to a production-ready state, ensuring all services are healthy and properly configured per infrastructure team guidance.

---

## Issues Fixed

### 1. PostgreSQL Connection Issues

#### Root Causes Identified:
- **Wrong host name**: Using `postgres` instead of `postgres-community` (service name)
- **Missing SSL parameters**: `database_config` method didn't include SSL certificate paths
- **Wrong password configuration**: Environment variable substitution not working in `discourse.conf`
- **Certificate permission issues**: Root-owned certificates on read-only mounts not accessible to `community` user
- **Wrong certificate paths**: Pointing to `/opt/sira-ai/ssl/postgres/` instead of `/opt/sira-ai/ssl/postgres-community/`

#### Fixes Applied:

**File: `config/discourse.conf`**
- Changed `db_host = postgres` → `db_host = postgres-community`
- Changed `db_password = ${DISCOURSE_DB_PASSWORD}` → `db_password = community_app_password_2025`

**File: `app/models/global_setting.rb`**
- Added SSL parameters to `database_config` method:
  - `sslmode` from `db_sslmode`
  - `sslcert`, `sslkey`, `sslrootcert` from environment variables
  - Reads from `POSTGRES_SSL_CERT`, `POSTGRES_SSL_KEY`, `POSTGRES_SSL_CA`

**File: `docker-entrypoint.sh`**
- Added PostgreSQL certificate copying (same approach as Redis)
- Copies certificates from `/opt/sira-ai/ssl/postgres-community/` to `/var/www/community/tmp/ssl/`
- Sets correct permissions (644 for certs, 600 for keys)
- Exports PostgreSQL environment variables pointing to writable paths

**File: `docker/docker-compose.sira-community.app.yml`**
- Updated PostgreSQL certificate paths to `/var/www/community/tmp/ssl/` (writable location)
- Updated certificate mount path to `/opt/sira-ai/ssl/postgres-community/`

#### POC Created:
- **Location**: `temp/postgres-connection-poc/`
- **Purpose**: Isolated testing of PostgreSQL connection configurations
- **Result**: Confirmed all 6 connection configurations work, including mTLS with client certificates

---

### 2. Redis TLS Connection Issues

#### Root Cause:
- `GlobalSetting.redis_config` was missing `ssl_params` with OpenSSL objects for client certificates
- Only had `ssl: true` but no client certificates or CA verification

#### Fix Applied:

**File: `app/models/global_setting.rb`**
- Modified `redis_config` method to include `ssl_params`:
  - `cert`: `OpenSSL::X509::Certificate` object
  - `key`: `OpenSSL::PKey::RSA` object
  - `ca_file`: String path to CA certificate
  - `verify_mode`: `OpenSSL::SSL::VERIFY_PEER`

**File: `docker-entrypoint.sh`**
- Copies Redis certificates to writable location
- Sets correct permissions and ownership

---

### 3. Puma Configuration Issues

#### Root Causes:
- **Wrong APP_ROOT**: Default was `/home/discourse/discourse` but app is at `/var/www/community`
- **Missing TCP port binding**: Puma only listening on Unix socket, not port 3000
- **Missing directories**: `tmp/sockets`, `tmp/pids`, `log` directories not created

#### Fixes Applied:

**File: `config/puma.rb`**
- Added TCP port binding: `bind "tcp://0.0.0.0:3000"`
- Kept Unix socket binding for local access

**File: `docker/docker-compose.sira-community.app.yml`**
- Added `APP_ROOT: /var/www/community` environment variable

**File: `docker-entrypoint.sh`**
- Creates required Puma directories: `tmp/sockets`, `tmp/pids`, `log`
- Sets correct ownership (`community:community`)

---

### 4. Health Check Issues

#### Root Causes:
- **Nginx**: Health check using `localhost` which doesn't resolve in Alpine
- **App**: Health check was incorrectly set to Sidekiq's check
- **Sidekiq**: Missing health check (was checking port 3000, which Sidekiq doesn't use)

#### Fixes Applied:

**File: `docker/docker-compose.sira-community.app.yml`**

**Nginx:**
- Changed health check from `http://localhost/health` to `http://127.0.0.1/health`
- Added `start_period: 10s`

**App:**
- Health check: `curl -f http://localhost:3000/srv/status`
- Added `start_period: 90s`

**Sidekiq:**
- Health check: `cat /proc/1/cmdline | grep -q sidekiq`
- Added `start_period: 60s`

---

## Files Modified

### Configuration Files:
1. `config/discourse.conf` - Database host and password
2. `config/puma.rb` - Added TCP port 3000 binding
3. `app/models/global_setting.rb` - Added SSL parameters for PostgreSQL and Redis

### Docker Files:
4. `docker/docker-compose.sira-community.app.yml` - All service configurations
5. `docker-entrypoint.sh` - Certificate copying and directory creation
6. `Dockerfile` - (No changes needed - already correct)

### Documentation:
7. `temp/postgres-connection-poc/` - POC files (can be deleted after verification)
8. `temp/redis-tls-poc/` - POC files (can be deleted after verification)

---

## Key Learnings

### 1. Infrastructure Service Names
- Always use service names (e.g., `postgres-community`) not container names or `localhost`
- Service names are resolved via Docker's internal DNS

### 2. Certificate Permissions
- Read-only volume mounts with root ownership require copying to writable locations
- Entrypoint script must run as root to copy certificates, then switch to application user

### 3. Health Checks
- Each service type needs appropriate health check:
  - Web servers: HTTP endpoint check
  - Background workers: Process check
  - Reverse proxies: HTTP endpoint check
- Use `127.0.0.1` instead of `localhost` in Alpine containers

### 4. POC Approach
- Isolating issues in POC before applying to main application is highly effective
- POCs help identify exact working configurations

### 5. SSL/TLS Configuration
- Different libraries require different formats:
  - `redis-rb`: OpenSSL objects for cert/key, string path for CA
  - `pg` gem: String paths for all SSL parameters
- Environment variables are more reliable than config file substitution

---

## Current Status

✅ **All Services Healthy:**
- `sira-community-app`: HEALTHY
- `sira-community-sidekiq`: HEALTHY
- `sira-community-nginx`: HEALTHY

✅ **All Connections Working:**
- PostgreSQL: Connected with mTLS
- Redis: Connected with TLS + client certificates
- Puma: Listening on port 3000 and Unix socket

✅ **All Configuration Per Infrastructure Team Guidance:**
- Host: `postgres-community:5432`
- Database: `sira_community`
- Username: `sira_community_user`
- Password: `community_app_password_2025`
- SSL Mode: `require` with client certificates

---

## Next Steps (Optional)

1. Clean up POC files in `temp/` directory
2. Monitor logs for any runtime issues
3. Verify application functionality through web interface
4. Consider adding monitoring/alerting for production

---

## Commands for Verification

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
```

