# Production-Grade Migration Strategy Analysis

**Date:** December 9, 2025  
**Question:** Is entrypoint migration check production-grade? What are the risks?

---

## Recommended Approach: Entrypoint Migration Check

### Proposed Implementation
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

## Production-Grade Analysis

### ✅ Is This Production-Grade?

**YES, with considerations:**

#### Advantages:
1. ✅ **Idempotent**: Rails migrations are safe to run multiple times
2. ✅ **Automatic**: No manual intervention needed
3. ✅ **Works for all deployment methods**: docker-compose, scripts, manual
4. ✅ **First-time deployment**: Handles empty database automatically
5. ✅ **Subsequent deployments**: Only runs pending migrations

#### Concerns:
1. ⚠️ **Startup time**: Adds delay on first run (acceptable)
2. ⚠️ **Concurrent migrations**: Multiple containers starting simultaneously
3. ⚠️ **Migration failures**: What if migration fails?
4. ⚠️ **Zero-downtime deployments**: Migrations during rolling updates
5. ⚠️ **Table locking**: Some migrations may lock tables

---

## Rails Migration Behavior

### How Rails Migrations Work:

1. **schema_migrations Table:**
   - Rails tracks which migrations have run
   - Each migration version is stored
   - `db:migrate` only runs migrations not in this table

2. **Idempotency:**
   - Running `db:migrate` multiple times is **SAFE**
   - Already-run migrations are skipped
   - Only pending migrations execute

3. **Example:**
   ```ruby
   # First run: Creates schema_migrations table, runs all migrations
   rails db:migrate
   # Result: All migrations run, versions stored
   
   # Second run: Checks schema_migrations, finds all already run
   rails db:migrate
   # Result: "No pending migrations" - exits immediately
   
   # After new migration added: Only new migration runs
   rails db:migrate
   # Result: Only new migration executes
   ```

### Safety Guarantees:

✅ **No Data Loss:**
- Migrations typically add/modify schema
- Data is preserved unless migration explicitly deletes it
- Rails migrations are designed to be reversible

✅ **No Duplicate Execution:**
- `schema_migrations` table prevents re-running migrations
- Rails checks this table before executing

✅ **Atomic Operations:**
- Each migration runs in a transaction (PostgreSQL)
- If migration fails, transaction rolls back
- Database remains in consistent state

---

## Running Compose Multiple Times

### Scenario 1: First Deployment
**Action:** `docker-compose up -d`  
**Result:**
- Entrypoint checks: `schema_migrations` table doesn't exist
- Runs: `rails db:migrate`
- Creates: All tables, runs all migrations
- **Impact:** ✅ Safe, expected behavior

### Scenario 2: Subsequent Deployments (No New Migrations)
**Action:** `docker-compose up -d` (restart)  
**Result:**
- Entrypoint checks: `schema_migrations` table exists
- Checks: `rails db:migrate:status` - all migrations up
- Runs: `rails db:migrate` (idempotent)
- **Result:** "No pending migrations" - exits immediately
- **Impact:** ✅ Safe, minimal overhead (~1-2 seconds)

### Scenario 3: Deployment with New Migrations
**Action:** `docker-compose up -d` (after code update with new migration)  
**Result:**
- Entrypoint checks: `schema_migrations` table exists
- Checks: `rails db:migrate:status` - finds pending migrations
- Runs: `rails db:migrate` - executes only new migrations
- **Impact:** ✅ Safe, runs only what's needed

### Scenario 4: Multiple Containers Starting Simultaneously
**Action:** Rolling update or multiple app containers  
**Risk:** ⚠️ **CONCURRENT MIGRATION EXECUTION**

**Problem:**
- Multiple containers check migrations simultaneously
- All see "pending migrations"
- All try to run migrations at once
- PostgreSQL will serialize (one succeeds, others wait)
- But: Unnecessary load and potential conflicts

**Solution:**
- Use migration lock (PostgreSQL advisory locks)
- OR: Run migrations in separate init container
- OR: Use migration service that runs once

---

## Impact on Existing Data

### ✅ Data Safety:

1. **Schema Changes:**
   - Adding columns: ✅ Safe (adds NULL columns, no data loss)
   - Adding indexes: ✅ Safe (may take time on large tables)
   - Adding tables: ✅ Safe (no impact on existing data)
   - Modifying columns: ⚠️ Depends on migration (usually safe)

2. **Data Modifications:**
   - Migrations that modify data are explicit
   - Usually reversible
   - Should be tested in staging first

3. **Table Locking:**
   - Some migrations lock tables (e.g., adding NOT NULL constraint)
   - May cause brief unavailability
   - Usually acceptable for schema changes

### ⚠️ Production Considerations:

1. **Large Tables:**
   - Adding indexes to large tables can take time
   - May lock table during index creation
   - Consider `algorithm: :concurrently` for large tables

2. **Zero-Downtime:**
   - Migrations during rolling updates can cause issues
   - Old code may not work with new schema
   - Solution: Run migrations before deploying new code

3. **Migration Failures:**
   - If migration fails, container startup fails
   - Application won't start until migration succeeds
   - This is actually GOOD (prevents running with bad schema)

---

## Production-Grade Alternatives

### Option 1: Entrypoint with Migration Lock (Recommended Enhancement)

**Enhanced Implementation:**
```bash
# Use PostgreSQL advisory lock to prevent concurrent migrations
if [ "$RAILS_ENV" = "production" ]; then
    echo "Checking database migrations..."
    cd /var/www/community
    
    # Try to acquire migration lock (prevents concurrent execution)
    bundle exec rails runner "
      require 'pg'
      conn = ActiveRecord::Base.connection.raw_connection
      lock_acquired = conn.exec('SELECT pg_try_advisory_lock(123456789)').first['pg_try_advisory_lock']
      if lock_acquired == 't'
        begin
          ActiveRecord::Base.connection.migration_context.migrate
        ensure
          conn.exec('SELECT pg_advisory_unlock(123456789)')
        end
      else
        puts 'Migration already running, waiting...'
        sleep 5
      end
    " 2>/dev/null || {
        # Fallback to simple migration if lock fails
        bundle exec rails db:migrate
    }
fi
```

**Pros:**
- Prevents concurrent migrations
- Still automatic
- Safe for multiple containers

**Cons:**
- More complex
- Requires PostgreSQL advisory locks

### Option 2: Init Container Pattern (Most Production-Grade)

**docker-compose.yml:**
```yaml
services:
  migrate:
    build:
      context: ..
      dockerfile: Dockerfile
    command: bundle exec rails db:migrate
    environment:
      # Same as app service
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - sira_infra_network
    restart: "no"  # Run once and exit

  app:
    depends_on:
      migrate:
        condition: service_completed_successfully
    # ... rest of app config
```

**Pros:**
- ✅ Clear separation of concerns
- ✅ Runs once before app starts
- ✅ No concurrent migration risk
- ✅ Can see migration status separately
- ✅ Follows Kubernetes best practices

**Cons:**
- More complex docker-compose
- Requires migration service definition

### Option 3: Pre-Deployment Migration Step

**Separate migration command before starting app:**
```bash
# Step 1: Run migrations
docker-compose run --rm migrate

# Step 2: Start services
docker-compose up -d
```

**Pros:**
- Explicit control
- No startup delay
- Clear migration step

**Cons:**
- Manual step required
- Not automatic
- Easy to forget

---

## Recommended Production-Grade Solution

### For Single Container Deployments:
**Use: Entrypoint Migration Check (Simple)**
- ✅ Automatic
- ✅ Idempotent
- ✅ Safe for single container
- ⚠️ Consider adding migration lock for safety

### For Multi-Container/Production:
**Use: Init Container Pattern**
- ✅ Most production-grade
- ✅ Prevents concurrent migrations
- ✅ Clear separation
- ✅ Zero-downtime friendly

### Hybrid Approach (Best of Both):
1. **Init container runs migrations** (for first deployment)
2. **Entrypoint checks for pending migrations** (for updates)
3. **Migration lock prevents concurrent execution**

---

## Risk Assessment

### Low Risk:
- ✅ Running migrations multiple times (idempotent)
- ✅ Data safety (Rails migrations preserve data)
- ✅ Schema changes (typically safe)

### Medium Risk:
- ⚠️ Concurrent migrations (multiple containers)
- ⚠️ Large table migrations (locking)
- ⚠️ Migration failures (container won't start)

### Mitigation:
- Use migration lock or init container
- Test migrations in staging first
- Monitor migration execution time
- Have rollback plan for critical migrations

---

## Conclusion

**Is entrypoint migration check production-grade?**
✅ **YES, with enhancements:**
- Basic approach: ✅ Safe and idempotent
- Enhanced approach: ✅ Add migration lock for concurrent safety
- Best approach: ✅ Use init container pattern for production

**Will running compose multiple times cause issues?**
✅ **NO:**
- Rails migrations are idempotent
- Already-run migrations are skipped
- Safe to run multiple times

**Impact on existing data?**
✅ **SAFE:**
- No data loss
- Migrations preserve existing data
- Schema changes are additive (typically)
- Some migrations may lock tables (briefly)

**Recommendation:**
- **For development/local:** Entrypoint migration check is sufficient
- **For production:** Use init container pattern or enhanced entrypoint with lock



