# Database Migration Deployment Analysis

**Date:** December 9, 2025  
**Issue:** Database migrations not run automatically during deployment

## Question

**Can database migrations be part of the deployment process?**  
✅ **YES** - They absolutely should be part of the deployment process.

**Why haven't migrations been run so far?**  
This document explains the current state and why migrations weren't automated.

---

## Current State Analysis

### 1. Dockerfile
**Location:** `Dockerfile`  
**Status:** ✅ **CORRECT** - No migrations in Dockerfile
- Migrations should NOT run during image build
- Build time is for compiling code/assets, not database operations
- Database may not be available during build

### 2. Docker Entrypoint Script
**Location:** `docker-entrypoint.sh`  
**Status:** ❌ **GAP** - No migration logic
- **Current:** Only handles certificate copying and user switching
- **Missing:** No check for pending migrations
- **Missing:** No automatic migration on first startup

**Current Entrypoint Flow:**
1. Copy certificates (as root)
2. Create directories
3. Switch to community user
4. Execute application command (Puma)

**What's Missing:**
- Check if `schema_migrations` table exists
- Check if migrations are pending
- Run migrations if needed
- Only then start the application

### 3. Docker Compose Configuration
**Location:** `docker/docker-compose.sira-community.app.yml`  
**Status:** ❌ **GAP** - No migration step
- **Current:** Just starts services directly
- **Missing:** No init container for migrations
- **Missing:** No migration service
- **Missing:** No `depends_on` with migration completion check

### 4. Deployment Scripts
**Location:** `docker/scripts/deploy-local.sh` and `docker/scripts/deploy.sh`  
**Status:** ✅ **HAS MIGRATIONS** - But scripts are optional

**deploy-local.sh (Lines 169-178):**
```bash
echo "Running database migrations..."
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec -T app bundle exec rake db:migrate
```

**deploy.sh (Lines 54-57):**
```bash
# Run migrations
echo "📦 Running database migrations..."
docker-compose exec -T app bundle exec rake db:migrate || {
    echo "⚠️  Migration failed or database already migrated"
}
```

**Problem:**
- Scripts exist and include migrations
- But scripts are **OPTIONAL** - not required
- User can deploy using `docker-compose up` directly
- Direct deployment bypasses migration step

---

## Why Migrations Weren't Run

### Root Causes:

1. **Deployment Method Used:**
   - User likely ran: `docker-compose up -d` directly
   - Did NOT use `docker/scripts/deploy-local.sh`
   - Direct docker-compose doesn't include migration step

2. **No Automatic Migration:**
   - Entrypoint doesn't check/run migrations
   - No init container for migrations
   - No migration service in docker-compose

3. **Focus During Development:**
   - Primary focus: Infrastructure connectivity (PostgreSQL, Redis)
   - Primary focus: SSL/TLS certificate configuration
   - Primary focus: Health checks and service startup
   - Database initialization assumed to be manual step

4. **Documentation Gap:**
   - Deployment scripts exist but not prominently documented as required
   - No clear indication that migrations must be run manually if not using scripts

---

## Best Practice Options

### Option 1: Entrypoint Migration Check (Recommended)
**Add to `docker-entrypoint.sh`:**
- Check if `schema_migrations` table exists
- If not, run `rails db:migrate`
- Only then start the application

**Pros:**
- Automatic - no manual step needed
- Works regardless of deployment method
- Runs on every container start (idempotent)

**Cons:**
- Slightly slower startup on first run
- Need to ensure database is accessible

### Option 2: Init Container Pattern
**Add migration service to docker-compose:**
- Separate `migrate` service that runs before `app`
- Uses `depends_on` with condition
- Runs migrations, then exits

**Pros:**
- Clear separation of concerns
- Can see migration status separately
- Follows Kubernetes init container pattern

**Cons:**
- More complex docker-compose setup
- Requires migration service definition

### Option 3: Docker Compose Init Service
**Use docker-compose's init service:**
- Define migration as init service
- Runs once before app starts
- Uses healthcheck to wait for completion

**Pros:**
- Built-in docker-compose feature
- Clean separation

**Cons:**
- Requires docker-compose v3.8+
- More complex configuration

### Option 4: Require Deployment Scripts
**Make deployment scripts mandatory:**
- Document that scripts MUST be used
- Remove direct docker-compose usage
- Scripts handle migrations automatically

**Pros:**
- Scripts already exist and work
- Can add more deployment logic

**Cons:**
- Users might still use docker-compose directly
- Not truly automatic

---

## Recommended Solution

**Option 1: Entrypoint Migration Check** is recommended because:
1. ✅ Fully automatic - works regardless of deployment method
2. ✅ No additional docker-compose complexity
3. ✅ Idempotent - safe to run multiple times
4. ✅ Production-grade - ensures database is always initialized
5. ✅ Follows principle of least surprise

**Implementation:**
Add to `docker-entrypoint.sh` before starting application:
```bash
# Check if database needs migrations
if [ "$RAILS_ENV" = "production" ]; then
    echo "Checking database migrations..."
    cd /var/www/community
    # Check if schema_migrations table exists
    if ! bundle exec rails runner "ActiveRecord::Base.connection.table_exists?('schema_migrations')" 2>/dev/null; then
        echo "Database not initialized. Running migrations..."
        bundle exec rails db:migrate
    else
        echo "Checking for pending migrations..."
        bundle exec rails db:migrate:status | grep -q "down" && bundle exec rails db:migrate || echo "Database up to date"
    fi
fi
```

---

## Why This Gap Exists

1. **Development Focus:**
   - Initial focus was on infrastructure connectivity
   - SSL/TLS certificate configuration was complex
   - Database connection issues took priority
   - Migration step was assumed to be manual

2. **Deployment Scripts Existed:**
   - Scripts were created with migration steps
   - But scripts weren't made mandatory
   - Direct docker-compose usage bypassed scripts

3. **Production Assumptions:**
   - Assumed database would be initialized separately
   - Assumed migrations would be run manually
   - Didn't consider first-time deployment scenario

4. **Testing Gap:**
   - Testing focused on service health
   - Health endpoint doesn't require database
   - Root page error wasn't caught until user access

---

## Summary

**Can migrations be part of deployment?**  
✅ **YES** - They absolutely should be.

**Why weren't they run?**  
- Deployment scripts include migrations but are optional
- Direct `docker-compose up` bypasses migration step
- Entrypoint doesn't automatically run migrations
- No init container or migration service in docker-compose

**What's needed?**  
- Add automatic migration check to entrypoint (recommended)
- OR add migration service to docker-compose
- OR make deployment scripts mandatory with clear documentation

**Current Status:**  
- Infrastructure: ✅ All exist and healthy
- Database: ✅ Exists and accessible
- Schema: ❌ **MISSING** - Migrations not run
- Application: ❌ **500 Error** - Needs database schema



