# Production-Grade Database Security Recommendations

**Document Version:** 1.0  
**Date:** 2025-12-10  
**Purpose:** Production-grade, high-security approach for database user management and authentication

---

## Executive Summary

This document outlines production-grade best practices for database security, user separation, and authentication in a high-security environment with mTLS requirements.

---

## 1. User Architecture (Recommended)

### Three-Tier User Model

```
┌─────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                   │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │  Superuser/Admin  │  │  Migration User  │           │
│  │  (postgres)       │  │  (migrations)    │           │
│  │  - Full access    │  │  - DDL only      │           │
│  │  - Emergency only │  │  - Deployments  │           │
│  └──────────────────┘  └──────────────────┘           │
│                                                           │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │  Application User │  │  Read-Only User  │           │
│  │  (runtime)        │  │  (reporting)     │           │
│  │  - DML only       │  │  - SELECT only  │           │
│  │  - Normal ops     │  │  - Analytics    │           │
│  └──────────────────┘  └──────────────────┘           │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### User Roles and Responsibilities

| User | Purpose | Privileges | When Used | Security Level |
|------|---------|------------|-----------|----------------|
| **postgres** (superuser) | Emergency/admin | ALL | Manual intervention only | 🔴 CRITICAL |
| **sira_community_migrate** | Database migrations | DDL (CREATE, ALTER, DROP, extensions) | Deployments only | 🟠 HIGH |
| **sira_community_app** | Application runtime | DML (SELECT, INSERT, UPDATE, DELETE) | 24/7 operations | 🟡 MEDIUM |
| **sira_community_readonly** | Reporting/analytics | SELECT only | Read operations | 🟢 LOW |

---

## 2. SSL/mTLS Certificate Strategy

### Separate Certificates Per User (RECOMMENDED)

**Production-Grade Approach:**

```
SSL Certificates Structure:
├── ca/
│   └── ca.crt (Certificate Authority)
├── postgres/
│   ├── postgres-server.crt
│   └── postgres-server.key
├── sira-community/
│   ├── migrate/
│   │   ├── migrate-client.crt  ← Admin user certificate
│   │   └── migrate-client.key
│   ├── app/
│   │   ├── app-client.crt      ← Application user certificate
│   │   └── app-client.key
│   └── readonly/
│       ├── readonly-client.crt ← Read-only user certificate
│       └── readonly-client.key
```

### Certificate Mapping Configuration

**`pg_ident.conf` (User Identity Mapping):**
```
# Map SSL certificate CN to database user
migrate_map     migrate-client    sira_community_migrate
app_map         app-client       sira_community_app
readonly_map    readonly-client  sira_community_readonly
```

**`pg_hba.conf` (Host-Based Authentication):**
```
# Migration user - Full DDL access
hostssl sira_community sira_community_migrate 0.0.0.0/0 cert map=migrate_map

# Application user - DML only
hostssl sira_community sira_community_app 0.0.0.0/0 cert map=app_map

# Read-only user - SELECT only
hostssl sira_community sira_community_readonly 0.0.0.0/0 cert map=readonly_map

# Reject all other connections
hostssl all all 0.0.0.0/0 reject
```

---

## 3. Database User Configuration

### Migration User (`sira_community_migrate`)

```sql
-- Create migration user
CREATE USER sira_community_migrate WITH PASSWORD 'secure_random_password_here';

-- Grant necessary privileges (NOT superuser for security)
ALTER DATABASE sira_community OWNER TO sira_community_migrate;
ALTER SCHEMA public OWNER TO sira_community_migrate;

-- Explicit privileges
GRANT ALL ON SCHEMA public TO sira_community_migrate;
GRANT CREATE ON SCHEMA public TO sira_community_migrate;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sira_community_migrate;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO sira_community_migrate;

-- Default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sira_community_migrate;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO sira_community_migrate;

-- Extension creation (requires CREATEDB or specific grant)
-- Note: Some extensions require superuser, may need separate process
GRANT CREATE ON DATABASE sira_community TO sira_community_migrate;

-- Connection limits (security)
ALTER USER sira_community_migrate WITH CONNECTION LIMIT 5;
```

### Application User (`sira_community_app`)

```sql
-- Create application user
CREATE USER sira_community_app WITH PASSWORD 'secure_random_password_here';

-- Basic privileges
GRANT CONNECT ON DATABASE sira_community TO sira_community_app;
GRANT USAGE ON SCHEMA public TO sira_community_app;

-- DML privileges only (NO CREATE, ALTER, DROP)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sira_community_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sira_community_app;

-- Default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sira_community_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT USAGE, SELECT ON SEQUENCES TO sira_community_app;

-- Connection pooling (higher limit for app)
ALTER USER sira_community_app WITH CONNECTION LIMIT 100;

-- NO CREATE privilege
-- NO ALTER privilege
-- NO DROP privilege
-- NO extension creation
```

### Read-Only User (`sira_community_readonly`)

```sql
-- Create read-only user
CREATE USER sira_community_readonly WITH PASSWORD 'secure_random_password_here';

-- Read-only privileges
GRANT CONNECT ON DATABASE sira_community TO sira_community_readonly;
GRANT USAGE ON SCHEMA public TO sira_community_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO sira_community_readonly;

-- Default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT SELECT ON TABLES TO sira_community_readonly;

-- Connection limits
ALTER USER sira_community_readonly WITH CONNECTION LIMIT 50;
```

---

## 4. Connection Pooling (PgBouncer)

### Production Configuration

**Why Use PgBouncer:**
- Reduces connection overhead
- Enforces connection limits
- Provides additional security layer
- Enables connection routing

**Configuration (`pgbouncer.ini`):**
```ini
[databases]
sira_community = host=postgres-community port=5432 dbname=sira_community

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
max_user_connections = 50

# User authentication (use auth_file or auth_query)
auth_type = cert
auth_file = /etc/pgbouncer/userlist.txt

# SSL configuration
ssl = require
ssl_cert_file = /etc/pgbouncer/ssl/pgbouncer.crt
ssl_key_file = /etc/pgbouncer/ssl/pgbouncer.key
ssl_ca_file = /etc/pgbouncer/ssl/ca.crt
```

**User Mapping:**
```
"migrate_user" "sira_community_migrate"
"app_user" "sira_community_app"
"readonly_user" "sira_community_readonly"
```

---

## 5. Network Security

### Network Isolation

```
┌─────────────────────────────────────────────────────────┐
│              Application Layer (Docker)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Migrate    │  │     App      │  │   Sidekiq     │  │
│  │   Service    │  │   Service   │  │   Service    │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                  │                  │          │
│         └──────────────────┼──────────────────┘          │
│                            │                             │
└────────────────────────────┼─────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  PgBouncer      │
                    │  (Connection    │
                    │   Pooler)       │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  PostgreSQL     │
                    │  (mTLS Only)    │
                    └─────────────────┘
```

### Firewall Rules

- **Database**: Only accept connections from PgBouncer IP
- **PgBouncer**: Only accept connections from application containers
- **Application**: No direct database access (must go through PgBouncer)

---

## 6. Secrets Management

### Production Secrets Storage

**DO NOT:**
- ❌ Store passwords in environment files
- ❌ Commit secrets to Git
- ❌ Hardcode credentials in code
- ❌ Use default passwords

**DO:**
- ✅ Use secrets management (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault)
- ✅ Rotate credentials regularly (90 days)
- ✅ Use strong, randomly generated passwords (32+ characters)
- ✅ Store certificates in secure storage
- ✅ Use environment-specific secrets

**Example (Docker Secrets):**
```yaml
services:
  migrate:
    secrets:
      - db_admin_password
      - migrate_client_cert
      - migrate_client_key
    environment:
      DISCOURSE_DB_PASSWORD_FILE: /run/secrets/db_admin_password

secrets:
  db_admin_password:
    external: true
  migrate_client_cert:
    external: true
  migrate_client_key:
    external: true
```

---

## 7. Audit and Monitoring

### Database Audit Logging

```sql
-- Enable audit logging
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'ddl';  -- Log all DDL (CREATE, ALTER, DROP)
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- Log slow queries (>1s)

-- Reload configuration
SELECT pg_reload_conf();
```

### Application-Level Monitoring

- **Track**: Who connects, when, from where
- **Alert**: Unusual connection patterns
- **Log**: All DDL operations
- **Monitor**: Failed authentication attempts
- **Audit**: Privilege changes

---

## 8. Deployment Workflow

### Secure Migration Process

```
1. Pre-Deployment
   ├── Verify migration user credentials
   ├── Check SSL certificates are valid
   ├── Verify network connectivity
   └── Backup database

2. Migration Execution
   ├── Connect as migrate user (via SSL cert)
   ├── Run migrations (DDL operations)
   ├── Verify migrations completed
   └── Log all operations

3. Post-Deployment
   ├── Verify application can connect
   ├── Test application operations
   ├── Monitor for errors
   └── Update audit logs
```

### Rollback Strategy

- **Database backups** before each migration
- **Point-in-time recovery** capability
- **Migration rollback scripts** (where possible)
- **Blue-green deployment** for zero-downtime

---

## 9. Security Best Practices Summary

### ✅ DO

1. **Separate users** for different purposes (migrate, app, readonly)
2. **Use SSL/mTLS** for all connections
3. **Separate certificates** per user role
4. **Map certificates** to users in pg_hba.conf
5. **Grant minimum privileges** (principle of least privilege)
6. **Use connection pooling** (PgBouncer)
7. **Store secrets securely** (secrets management)
8. **Enable audit logging** (track all DDL operations)
9. **Network isolation** (database not publicly accessible)
10. **Regular credential rotation** (90 days)

### ❌ DON'T

1. **Don't use superuser** for application connections
2. **Don't share certificates** between users
3. **Don't store passwords** in code or config files
4. **Don't grant excessive privileges** (CREATE to app user)
5. **Don't skip SSL/mTLS** even in internal networks
6. **Don't expose database** to public internet
7. **Don't use default passwords**
8. **Don't disable audit logging**
9. **Don't allow direct database access** from application (use pooler)
10. **Don't ignore security alerts**

---

## 10. Implementation Checklist

### Phase 1: Certificate Setup
- [ ] Generate separate SSL certificates for each user role
- [ ] Configure `pg_ident.conf` for certificate mapping
- [ ] Update `pg_hba.conf` with certificate-based authentication
- [ ] Test certificate authentication for each user

### Phase 2: User Creation
- [ ] Create `sira_community_migrate` user with DDL privileges
- [ ] Create `sira_community_app` user with DML privileges only
- [ ] Create `sira_community_readonly` user with SELECT only
- [ ] Verify privileges with test queries

### Phase 3: Connection Pooling
- [ ] Install and configure PgBouncer
- [ ] Configure user mapping in PgBouncer
- [ ] Update application connection strings to use PgBouncer
- [ ] Test connection pooling

### Phase 4: Secrets Management
- [ ] Set up secrets management system
- [ ] Store database passwords securely
- [ ] Store SSL certificates securely
- [ ] Update application to use secrets

### Phase 5: Monitoring and Audit
- [ ] Enable PostgreSQL audit logging
- [ ] Set up monitoring for database connections
- [ ] Configure alerts for security events
- [ ] Document audit procedures

---

## 11. Recommended Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Containers                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Migrate    │  │     App     │  │  Sidekiq   │         │
│  │  (migrate   │  │   (app)     │  │   (app)    │         │
│  │   cert)     │  │   (app      │  │   (app     │         │
│  │             │  │    cert)    │  │    cert)   │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│         │                 │                 │               │
│         └─────────────────┼─────────────────┘               │
│                           │                                 │
│                  ┌────────▼────────┐                        │
│                  │   PgBouncer     │                        │
│                  │  (Port 6432)    │                        │
│                  │  - Pooling      │                        │
│                  │  - Routing      │                        │
│                  │  - SSL/TLS      │                        │
│                  └────────┬────────┘                        │
└───────────────────────────┼─────────────────────────────────┘
                            │
                   ┌────────▼────────┐
                   │   PostgreSQL    │
                   │  (Port 5432)    │
                   │  - mTLS Only    │
                   │  - Certificate  │
                   │    Mapping      │
                   │  - Audit Log    │
                   └─────────────────┘
```

---

## 12. Migration Path from Current Setup

### Step 1: Create Separate Certificates
```bash
# Generate certificates for each user
openssl req -new -key migrate-client.key -out migrate-client.csr
openssl x509 -req -in migrate-client.csr -CA ca.crt -CAkey ca.key -out migrate-client.crt

openssl req -new -key app-client.key -out app-client.csr
openssl x509 -req -in app-client.csr -CA ca.crt -CAkey ca.key -out app-client.crt
```

### Step 2: Update pg_hba.conf
```bash
# Add certificate-based authentication rules
hostssl sira_community sira_community_migrate 0.0.0.0/0 cert map=migrate_map
hostssl sira_community sira_community_app 0.0.0.0/0 cert map=app_map
```

### Step 3: Update pg_ident.conf
```bash
# Map certificate CN to database user
migrate_map     migrate-client    sira_community_migrate
app_map         app-client       sira_community_app
```

### Step 4: Update Docker Compose
```yaml
services:
  migrate:
    environment:
      DISCOURSE_DB_USERNAME: sira_community_migrate
    volumes:
      - ./ssl/migrate:/opt/sira-ai/ssl/migrate:ro
  
  app:
    environment:
      DISCOURSE_DB_USERNAME: sira_community_app
    volumes:
      - ./ssl/app:/opt/sira-ai/ssl/app:ro
```

---

## 13. Security Compliance

This approach meets requirements for:
- ✅ **PCI DSS**: Network segmentation, access control
- ✅ **SOC 2**: Access controls, audit logging
- ✅ **HIPAA**: Encryption in transit, access controls
- ✅ **GDPR**: Data protection, access controls
- ✅ **ISO 27001**: Access management, cryptography

---

## Conclusion

This production-grade approach provides:
1. **Strong Security**: Certificate-based authentication, least privilege
2. **Auditability**: Complete audit trail of all operations
3. **Scalability**: Connection pooling for high load
4. **Maintainability**: Clear separation of concerns
5. **Compliance**: Meets major security standards

**Next Steps**: Work with infrastructure team to implement certificate-based user mapping and update authentication configuration.



