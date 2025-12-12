# Database User Privileges Requirements

**Document Version:** 1.0  
**Last Updated:** 2025-12-09  
**Prepared For:** Infrastructure Team  
**Purpose:** Clear specification of database user privileges required for SIRA Community deployment

---

## Overview

SIRA Community requires **two separate database users** with different privilege levels:

1. **Admin User** (`sira_community_admin`) - Used only for migrations/deployments
2. **Application User** (`sira_community_user`) - Used for runtime operations

This separation follows the **principle of least privilege** for security best practices.

---

## User 1: Admin User (`sira_community_admin`)

### Purpose
- **Used by**: `migrate` service only (runs during deployments)
- **When**: Only during `rails db:migrate` execution
- **Why**: Needs to create tables, indexes, extensions, and modify schema

### Required Privileges

#### Database-Level Privileges
```sql
-- Connect to database
GRANT CONNECT ON DATABASE sira_community TO sira_community_admin;

-- Create extensions (required for pgvector, unaccent, etc.)
-- Note: This requires CREATEDB privilege or superuser role
ALTER DATABASE sira_community OWNER TO sira_community_admin;
-- OR grant CREATE privilege if owner is different
GRANT CREATE ON DATABASE sira_community TO sira_community_admin;
```

#### Schema-Level Privileges
```sql
-- Full control over public schema
GRANT ALL ON SCHEMA public TO sira_community_admin;
ALTER SCHEMA public OWNER TO sira_community_admin;

-- Usage privilege
GRANT USAGE ON SCHEMA public TO sira_community_admin;
```

#### Table-Level Privileges
```sql
-- Full privileges on all existing tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sira_community_admin;

-- Full privileges on all sequences (for auto-increment IDs)
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO sira_community_admin;

-- Default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sira_community_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO sira_community_admin;
```

#### Extension Privileges
```sql
-- Ability to create extensions (required for pgvector, unaccent)
-- This typically requires superuser or CREATEDB privilege
-- Infrastructure team should enable these extensions:
--   - vector (pgvector)
--   - unaccent
--   - hstore (if needed)
--   - pg_trgm (if needed)
```

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

-- Extension creation (if not superuser, requires CREATEDB or explicit grant)
-- Note: Some extensions (like vector) may require superuser privileges
-- Infrastructure team should pre-install extensions or grant superuser role
```

### Critical Requirements

1. **CREATE Extension Privilege**: Must be able to create PostgreSQL extensions:
   - `vector` (pgvector) - **REQUIRED** for Discourse AI features
   - `unaccent` - Required by Discourse core
   - Other extensions as needed by migrations

2. **CREATE Table Privilege**: Must be able to create tables in `public` schema

3. **ALTER Table Privilege**: Must be able to modify table structure (add columns, indexes, etc.)

4. **CREATE Index Privilege**: Must be able to create indexes (including GIN, GiST indexes)

5. **Schema Ownership**: Should own the `public` schema or have full privileges

---

## User 2: Application User (`sira_community_user`)

### Purpose
- **Used by**: `app` and `sidekiq` services (runtime operations)
- **When**: All the time during normal application operation
- **Why**: Only needs to read/write data, not modify schema

### Required Privileges

#### Database-Level Privileges
```sql
-- Connect to database
GRANT CONNECT ON DATABASE sira_community TO sira_community_user;
```

#### Schema-Level Privileges
```sql
-- Usage on public schema
GRANT USAGE ON SCHEMA public TO sira_community_user;
```

#### Table-Level Privileges
```sql
-- DML operations only (no DDL)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sira_community_user;

-- Sequence privileges (for getting next ID values)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sira_community_user;

-- Default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sira_community_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sira_community_user;
```

### Complete SQL Script for Application User

```sql
-- Create application user
CREATE USER sira_community_user WITH PASSWORD 'community_app_password_2025';

-- Database-level privileges
GRANT CONNECT ON DATABASE sira_community TO sira_community_user;

-- Schema-level privileges
GRANT USAGE ON SCHEMA public TO sira_community_user;

-- Table-level privileges (DML only - no CREATE, ALTER, DROP)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sira_community_user;

-- Sequence privileges (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sira_community_user;

-- Default privileges (for future tables)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sira_community_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sira_community_user;
```

### Critical Requirements

1. **NO CREATE Privilege**: Should NOT be able to create tables, indexes, or extensions
2. **NO ALTER Privilege**: Should NOT be able to modify table structure
3. **NO DROP Privilege**: Should NOT be able to drop tables or objects
4. **DML Only**: SELECT, INSERT, UPDATE, DELETE operations only

---

## Security Benefits

### Why Separate Users?

1. **Principle of Least Privilege**: Application code runs with minimal privileges
2. **Attack Surface Reduction**: If application is compromised, attacker cannot modify schema
3. **Audit Trail**: Clear separation between migration operations and application operations
4. **Compliance**: Meets security best practices for production deployments

### Risk Mitigation

- **Admin User**: Only used during deployments (short-lived connections)
- **Application User**: Used continuously but with restricted privileges
- **No Superuser**: Neither user should be PostgreSQL superuser unless absolutely necessary

---

## Verification Queries

### Verify Admin User Privileges

```sql
-- Check if admin user can create extensions
SELECT has_database_privilege('sira_community_admin', 'sira_community', 'CREATE');

-- Check schema privileges
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE grantee = 'sira_community_admin' AND table_schema = 'public';

-- Check if user owns schema
SELECT schema_name, schema_owner 
FROM information_schema.schemata 
WHERE schema_name = 'public';
```

### Verify Application User Privileges

```sql
-- Verify user CANNOT create tables
SELECT has_schema_privilege('sira_community_user', 'public', 'CREATE');
-- Should return FALSE

-- Verify user CAN perform DML
SELECT has_table_privilege('sira_community_user', 'users', 'SELECT');
SELECT has_table_privilege('sira_community_user', 'users', 'INSERT');
SELECT has_table_privilege('sira_community_user', 'users', 'UPDATE');
SELECT has_table_privilege('sira_community_user', 'users', 'DELETE');
-- All should return TRUE (after tables are created)
```

---

## Summary for Infrastructure Team

### Admin User (`sira_community_admin`) - REQUIRED PRIVILEGES:

✅ **Database**: CONNECT, CREATE (for extensions)  
✅ **Schema**: ALL privileges on `public` schema  
✅ **Tables**: ALL privileges (CREATE, ALTER, DROP, SELECT, INSERT, UPDATE, DELETE)  
✅ **Sequences**: ALL privileges  
✅ **Extensions**: Ability to CREATE extensions (vector, unaccent)  
✅ **Indexes**: Ability to CREATE indexes (including GIN, GiST)  

**OR** grant superuser role (less secure but simpler)

### Application User (`sira_community_user`) - REQUIRED PRIVILEGES:

✅ **Database**: CONNECT only  
✅ **Schema**: USAGE on `public` schema  
✅ **Tables**: SELECT, INSERT, UPDATE, DELETE (NO CREATE, ALTER, DROP)  
✅ **Sequences**: USAGE, SELECT  
❌ **Extensions**: NO privileges  
❌ **Indexes**: NO CREATE privileges  

---

## Environment Variables

The following environment variables control which user is used:

- `COMMUNITY_DB_ADMIN_USER` - Admin username (default: `sira_community_admin`)
- `COMMUNITY_DB_ADMIN_PASSWORD` - Admin password
- `COMMUNITY_DB_USER` - Application username (default: `sira_community_user`)
- `COMMUNITY_DB_PASSWORD` - Application password

These can be set in `docker/env.community.app.local` or passed via environment variables.

---

## Questions for Infrastructure Team

1. **Can the admin user be granted superuser role?** (Simplest solution)
2. **If not superuser, can CREATEDB privilege be granted?** (Required for extensions)
3. **Are extensions pre-installed?** (vector, unaccent) - If yes, admin user doesn't need CREATE extension privilege
4. **What is the database name?** (Currently configured as `sira_community`)
5. **What are the actual usernames/passwords?** (Update in env file after creation)

---

## Next Steps

1. Infrastructure team creates both users with appropriate privileges
2. Update `docker/env.community.app.local` with actual credentials
3. Test migration with admin user
4. Verify application runs with restricted user
5. Document final configuration



