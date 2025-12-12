# Database User Setup - Infrastructure Team Requirements

**Document Version:** 1.0  
**Date:** 2025-12-09  
**Prepared For:** Infrastructure Team  
**Priority:** HIGH - Required for deployment

---

## Quick Summary

SIRA Community requires **TWO database users** with different privilege levels:

1. **Admin User** (`sira_community_admin`) - For migrations only
2. **Application User** (`sira_community_user`) - For runtime operations

---

## User 1: Admin User (`sira_community_admin`)

### Purpose
- Used ONLY during deployments to run database migrations
- Creates tables, indexes, extensions, and modifies schema
- **NOT used during normal application operation**

### Required Privileges - CRITICAL

The admin user **MUST** have the following privileges:

#### ✅ Database-Level
- `CONNECT` privilege on database `sira_community`
- `CREATE` privilege (to create extensions) **OR** database ownership
- **Alternative**: Grant `CREATEDB` privilege or `SUPERUSER` role

#### ✅ Schema-Level
- `ALL` privileges on schema `public`
- `USAGE` privilege on schema `public`
- **Recommended**: Make admin user the owner of `public` schema

#### ✅ Table-Level
- `ALL` privileges on all existing tables
- `ALL` privileges on all sequences
- Default privileges for future tables (CREATE, ALTER, DROP, SELECT, INSERT, UPDATE, DELETE)

#### ✅ Extension Privileges
- Ability to `CREATE EXTENSION` (required for):
  - `vector` (pgvector) - **REQUIRED** - Already installed by infra team
  - `unaccent` - Required by Discourse core
- **Note**: If extensions are pre-installed, admin user still needs CREATE privilege for future extensions

### Complete SQL Script for Admin User

```sql
-- Create admin user
CREATE USER sira_community_admin WITH PASSWORD 'community_admin_password_2025';

-- Database-level privileges
GRANT CONNECT ON DATABASE sira_community TO sira_community_admin;
ALTER DATABASE sira_community OWNER TO sira_community_admin;

-- Schema-level privileges
GRANT ALL ON SCHEMA public TO sira_community_admin;
ALTER SCHEMA public OWNER TO sira_community_admin;
GRANT USAGE ON SCHEMA public TO sira_community_admin;

-- Table-level privileges (existing tables)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sira_community_admin;

-- Sequence privileges (for auto-increment IDs)
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO sira_community_admin;

-- Default privileges (for future tables created by migrations)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sira_community_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO sira_community_admin;
```

### Alternative: Superuser Role (Simpler but Less Secure)

If granting individual privileges is complex, you can grant superuser role:

```sql
CREATE USER sira_community_admin WITH PASSWORD 'community_admin_password_2025' SUPERUSER;
```

**Note**: Superuser role gives full database access. This is acceptable for migration user since it's only used during deployments.

---

## User 2: Application User (`sira_community_user`)

### Purpose
- Used by application (`app` service) and background jobs (`sidekiq` service)
- Used continuously during normal operation
- Only needs to read/write data, **NOT modify schema**

### Required Privileges - RESTRICTED

The application user **MUST** have:

#### ✅ Database-Level
- `CONNECT` privilege on database `sira_community`
- **NO CREATE privilege** (cannot create extensions or databases)

#### ✅ Schema-Level
- `USAGE` privilege on schema `public`
- **NO CREATE privilege** (cannot create schemas)

#### ✅ Table-Level (DML Only)
- `SELECT` - Read data
- `INSERT` - Create records
- `UPDATE` - Modify records
- `DELETE` - Remove records
- **NO CREATE, ALTER, or DROP privileges**

#### ✅ Sequence Privileges
- `USAGE` - Use sequences
- `SELECT` - Get next value from sequences

### Complete SQL Script for Application User

```sql
-- Create application user
CREATE USER sira_community_user WITH PASSWORD 'community_app_password_2025';

-- Database-level privileges
GRANT CONNECT ON DATABASE sira_community TO sira_community_user;

-- Schema-level privileges
GRANT USAGE ON SCHEMA public TO sira_community_user;

-- Table-level privileges (DML only - NO CREATE, ALTER, DROP)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sira_community_user;

-- Sequence privileges (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sira_community_user;

-- Default privileges (for future tables)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sira_community_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sira_community_user;
```

### Critical Restrictions

❌ **MUST NOT** have:
- `CREATE` privilege on database
- `CREATE` privilege on schema
- `CREATE`, `ALTER`, or `DROP` privileges on tables
- Ability to create extensions
- Ability to create indexes (beyond what migrations create)

---

## Verification Queries

After creating users, verify privileges with these queries:

### Verify Admin User

```sql
-- Check database privileges
SELECT has_database_privilege('sira_community_admin', 'sira_community', 'CREATE');
-- Should return: TRUE

-- Check schema ownership
SELECT schema_owner FROM information_schema.schemata WHERE schema_name = 'public';
-- Should return: sira_community_admin

-- Check if can create extensions
SELECT has_database_privilege('sira_community_admin', 'sira_community', 'CREATE');
-- Should return: TRUE
```

### Verify Application User

```sql
-- Check user CANNOT create tables
SELECT has_schema_privilege('sira_community_user', 'public', 'CREATE');
-- Should return: FALSE

-- Check user CAN perform DML (after tables exist)
SELECT has_table_privilege('sira_community_user', 'users', 'SELECT');
SELECT has_table_privilege('sira_community_user', 'users', 'INSERT');
SELECT has_table_privilege('sira_community_user', 'users', 'UPDATE');
SELECT has_table_privilege('sira_community_user', 'users', 'DELETE');
-- All should return: TRUE (after migrations complete)
```

---

## Summary Table

| User | Used By | Privileges | Can Create Tables? | Can Create Extensions? | Can Modify Schema? |
|------|---------|------------|-------------------|----------------------|-------------------|
| **Admin** (`sira_community_admin`) | `migrate` service | **FULL** (DDL + DML) | ✅ YES | ✅ YES | ✅ YES |
| **Application** (`sira_community_user`) | `app`, `sidekiq` services | **RESTRICTED** (DML only) | ❌ NO | ❌ NO | ❌ NO |

---

## Environment Variables

After creating users, update these in `docker/env.community.app.local`:

```bash
# Admin User (for migrations)
COMMUNITY_DB_ADMIN_USER=sira_community_admin
COMMUNITY_DB_ADMIN_PASSWORD=<actual_password>

# Application User (for runtime)
COMMUNITY_DB_USER=sira_community_user
COMMUNITY_DB_PASSWORD=<actual_password>
```

---

## Questions for Infrastructure Team

1. **What are the actual usernames?** (Default: `sira_community_admin` and `sira_community_user`)
2. **What are the actual passwords?** (Update in env file)
3. **Is the database name `sira_community`?** (Confirm)
4. **Can admin user be granted superuser role?** (Simplest solution)
5. **Are extensions pre-installed?** (vector, unaccent) - If yes, admin still needs CREATE for future extensions

---

## Next Steps

1. ✅ Infrastructure team creates both users with appropriate privileges
2. ✅ Update `docker/env.community.app.local` with actual credentials
3. ✅ Test migration with admin user
4. ✅ Verify application runs with restricted user
5. ✅ Document final configuration

---

## Reference

See `docs/DATABASE_USER_PRIVILEGES.md` for detailed privilege specifications and security rationale.



