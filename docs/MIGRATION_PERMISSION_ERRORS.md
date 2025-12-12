# Migration Permission Errors - Action Required

**Date:** 2025-12-10  
**Status:** BLOCKED - Admin user missing required privileges  
**Priority:** CRITICAL

---

## Error Summary

The migration container failed with the following permission errors:

### Error 1: Cannot Create Extension "unaccent"
```
ERROR: permission denied to create extension "unaccent"
HINT: Must have CREATE privilege on current database to create this extension.
```

### Error 2: Cannot Create Tables in Schema "public"
```
ERROR: permission denied for schema public
LINE 1: CREATE TABLE "schema_migrations" ("version" character varying...
```

---

## Root Cause

The admin user (`sira_community_admin`) is **missing** the following critical privileges:

1. **CREATE privilege on database** - Required to create extensions
2. **CREATE privilege on schema public** - Required to create tables

---

## Required Fix for Infrastructure Team

The admin user needs **additional privileges**. Please execute one of the following:

### Option 1: Grant Superuser Role (Simplest)
```sql
ALTER USER sira_community_admin WITH SUPERUSER;
```

### Option 2: Grant Individual Privileges (More Secure)
```sql
-- Grant CREATE privilege on database
ALTER DATABASE sira_community OWNER TO sira_community_admin;
-- OR
GRANT CREATE ON DATABASE sira_community TO sira_community_admin;

-- Grant CREATE privilege on schema
ALTER SCHEMA public OWNER TO sira_community_admin;
-- OR
GRANT CREATE ON SCHEMA public TO sira_community_admin;
```

### Option 3: Pre-create Extensions (If Superuser Not Available)
If granting superuser is not possible, infrastructure team can pre-create the required extensions:

```sql
-- Connect as superuser (postgres or admin)
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS vector;  -- Already installed per infra team
```

Then grant the admin user ownership of the public schema:
```sql
ALTER SCHEMA public OWNER TO sira_community_admin;
GRANT ALL ON SCHEMA public TO sira_community_admin;
```

---

## Verification Queries

After applying fixes, verify with these queries:

```sql
-- Check if admin user can create extensions
SELECT has_database_privilege('sira_community_admin', 'sira_community', 'CREATE');
-- Should return: TRUE

-- Check schema ownership
SELECT schema_owner FROM information_schema.schemata WHERE schema_name = 'public';
-- Should return: sira_community_admin

-- Check if user owns schema
SELECT has_schema_privilege('sira_community_admin', 'public', 'CREATE');
-- Should return: TRUE
```

---

## Current Configuration

- **Admin User:** `sira_community_admin`
- **Database:** `sira_community`
- **Required Extensions:** `unaccent`, `vector` (already installed)

---

## Next Steps

1. ✅ Infrastructure team grants missing privileges to `sira_community_admin`
2. ✅ Verify privileges with queries above
3. ✅ Retry migration: `docker-compose up migrate`
4. ✅ Verify migration completes successfully

---

## Reference

See `docs/INFRASTRUCTURE_TEAM_DATABASE_SETUP.md` for complete privilege requirements.



