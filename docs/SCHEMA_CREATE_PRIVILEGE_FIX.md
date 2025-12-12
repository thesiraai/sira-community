# Schema CREATE Privilege Issue - Action Required

**Date:** 2025-12-10  
**Status:** BLOCKED - Admin user needs explicit CREATE privilege on schema  
**Priority:** CRITICAL

---

## Current Error

```
ERROR: permission denied for schema public
LINE 1: CREATE TABLE "ar_internal_metadata" ("key" character varying...
```

---

## Root Cause

Even though `sira_community_admin` owns the `public` schema, PostgreSQL requires **explicit GRANT** of CREATE privilege on the schema for table creation to work.

**Ownership ≠ CREATE Privilege**

In PostgreSQL:
- **Schema ownership** allows ALTER/DROP operations
- **CREATE privilege** must be explicitly granted for CREATE TABLE operations

---

## Required Fix

The infrastructure team needs to execute:

```sql
-- Grant CREATE privilege explicitly on schema public
GRANT CREATE ON SCHEMA public TO sira_community_admin;

-- Verify the privilege
SELECT has_schema_privilege('sira_community_admin', 'public', 'CREATE');
-- Should return: TRUE
```

---

## Alternative: Verify Current Privileges

If the privilege is already granted, verify with:

```sql
-- Check schema privileges
SELECT 
    nspname as schema_name,
    nspowner::regrole as owner,
    has_schema_privilege('sira_community_admin', nspname, 'CREATE') as has_create
FROM pg_namespace 
WHERE nspname = 'public';

-- Should show:
-- schema_name: public
-- owner: sira_community_admin  
-- has_create: TRUE
```

---

## Why This Is Needed

Rails migrations need to:
1. Create `ar_internal_metadata` table (Rails internal)
2. Create `schema_migrations` table (migration tracking)
3. Create all application tables via migrations

All of these require CREATE privilege on the schema, not just ownership.

---

## Next Steps

1. ✅ Infrastructure team grants: `GRANT CREATE ON SCHEMA public TO sira_community_admin;`
2. ✅ Verify with: `SELECT has_schema_privilege('sira_community_admin', 'public', 'CREATE');`
3. ✅ Retry migration: `docker-compose up migrate`
4. ✅ Verify migration completes successfully

---

## Reference

- PostgreSQL Documentation: [GRANT on Schemas](https://www.postgresql.org/docs/current/sql-grant.html)
- Schema privileges are separate from ownership
- CREATE privilege is required for CREATE TABLE operations



