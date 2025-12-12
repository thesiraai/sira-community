# Connection User Verification - Critical Issue

**Date:** 2025-12-10  
**Status:** BLOCKED - Application cannot create tables despite SUPERUSER role  
**Priority:** CRITICAL

---

## Problem

Even though:
- ✅ User `sira_community_admin` is SUPERUSER
- ✅ User owns `public` schema
- ✅ CREATE privilege granted on schema
- ✅ Infrastructure team verified all privileges

The application **still cannot create tables**:
```
ERROR: permission denied for schema public
LINE 1: CREATE TABLE "ar_internal_metadata" ...
```

---

## Root Cause Hypothesis

The application may be connecting with a **different user** than expected, possibly due to:

1. **SSL Client Certificate Mapping**: PostgreSQL may be mapping the SSL client certificate to a different user
2. **Connection Pooling**: A connection pooler may be using a different user
3. **Environment Variable Not Applied**: The `DISCOURSE_DB_USERNAME` may not be correctly set
4. **Database Configuration**: The database.yml or connection configuration may override the env var

---

## Required Verification from Infrastructure Team

### 1. Check SSL Certificate User Mapping

```sql
-- Check if SSL certificates are mapped to specific users
SELECT 
    usename,
    ssl_is_used,
    client_addr
FROM pg_stat_ssl 
JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid
WHERE datname = 'sira_community';
```

### 2. Check Current Connections

```sql
-- See what user is actually connecting
SELECT 
    datname,
    usename,
    application_name,
    client_addr,
    state
FROM pg_stat_activity 
WHERE datname = 'sira_community';
```

### 3. Check pg_hba.conf for User Mapping

The `pg_hba.conf` file may be mapping SSL certificates to specific users. Check if there's a rule like:
```
hostssl sira_community sira_community_user 0.0.0.0/0 cert
```

This would force all SSL connections to use `sira_community_user` regardless of the connection string.

---

## Possible Solutions

### Solution 1: Update pg_hba.conf

If SSL certificates are mapped to `sira_community_user`, add a rule for the admin user:
```
hostssl sira_community sira_community_admin 0.0.0.0/0 cert map=admin_user_map
```

### Solution 2: Use Different SSL Certificates

Create separate SSL client certificates for the admin user and map them in `pg_ident.conf`.

### Solution 3: Verify Connection String

Ensure the application is actually using `sira_community_admin` in the connection string, not being overridden by:
- `database.yml` configuration
- Connection pooling
- Environment variable precedence

---

## Immediate Action Required

**Infrastructure team should:**

1. Check `pg_hba.conf` for SSL certificate user mapping rules
2. Check `pg_ident.conf` for user identity mapping
3. Verify what user is actually connecting when the application tries to create tables
4. Check if there's a connection pooler (PgBouncer, etc.) that might be using a different user

---

## Test Query for Infrastructure Team

Run this while the migration is attempting to connect:

```sql
-- See active connections and their users
SELECT 
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    state,
    query
FROM pg_stat_activity 
WHERE datname = 'sira_community' 
  AND state = 'active';
```

This will show what user the application is actually connecting as.



