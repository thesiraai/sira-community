# Team Responsibilities - Database Security Implementation

**Document Version:** 1.0  
**Date:** 2025-12-10  
**Purpose:** Clear division of responsibilities between Infrastructure and Application teams

---

## Overview

This document clearly defines which team is responsible for each component of the production-grade database security implementation.

---

## Infrastructure Team Responsibilities

### 1. PostgreSQL Server Configuration ✅ INFRA

**Infrastructure Team Owns:**
- [ ] PostgreSQL server installation and configuration
- [ ] `postgresql.conf` configuration (logging, performance, security settings)
- [ ] `pg_hba.conf` configuration (authentication rules)
- [ ] `pg_ident.conf` configuration (user identity mapping)
- [ ] SSL/TLS server certificate management
- [ ] Database server network security (firewall rules)
- [ ] PostgreSQL version and patch management
- [ ] Server-level backup and recovery procedures

**Key Files:**
```
/etc/postgresql/*/main/postgresql.conf
/etc/postgresql/*/main/pg_hba.conf
/etc/postgresql/*/main/pg_ident.conf
```

**Deliverables:**
- Configured `pg_hba.conf` with certificate-based authentication
- Configured `pg_ident.conf` with certificate-to-user mapping
- PostgreSQL server ready to accept SSL connections

---

### 2. SSL Certificate Management ✅ INFRA

**Infrastructure Team Owns:**
- [ ] Certificate Authority (CA) setup and management
- [ ] SSL server certificate generation for PostgreSQL
- [ ] SSL client certificate generation for each user role:
  - `migrate-client.crt` / `migrate-client.key`
  - `app-client.crt` / `app-client.key`
  - `readonly-client.crt` / `readonly-client.key`
- [ ] Certificate distribution to application team
- [ ] Certificate renewal procedures
- [ ] Certificate revocation (if needed)
- [ ] Certificate storage in secure location

**Deliverables:**
- Separate SSL certificates for each user role
- Certificates provided to application team in secure manner
- Certificate paths documented

**Certificate Structure:**
```
ssl-certs/
├── ca/
│   └── ca.crt
├── postgres/
│   ├── postgres-server.crt
│   └── postgres-server.key
└── sira-community/
    ├── migrate/
    │   ├── migrate-client.crt
    │   └── migrate-client.key
    ├── app/
    │   ├── app-client.crt
    │   └── app-client.key
    └── readonly/
        ├── readonly-client.crt
        └── readonly-client.key
```

---

### 3. Database User Creation and Privileges ✅ INFRA

**Infrastructure Team Owns:**
- [ ] Create database `sira_community`
- [ ] Create user `sira_community_migrate` with DDL privileges
- [ ] Create user `sira_community_app` with DML privileges only
- [ ] Create user `sira_community_readonly` with SELECT only
- [ ] Grant appropriate privileges to each user
- [ ] Set connection limits per user
- [ ] Configure default privileges for future objects
- [ ] Verify privileges with test queries

**SQL Scripts (Infrastructure Team Executes):**
```sql
-- Migration user
CREATE USER sira_community_migrate WITH PASSWORD 'secure_password';
ALTER DATABASE sira_community OWNER TO sira_community_migrate;
ALTER SCHEMA public OWNER TO sira_community_migrate;
GRANT ALL ON SCHEMA public TO sira_community_migrate;
GRANT CREATE ON SCHEMA public TO sira_community_migrate;
-- ... (see full script in recommendations doc)

-- Application user
CREATE USER sira_community_app WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE sira_community TO sira_community_app;
GRANT USAGE ON SCHEMA public TO sira_community_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sira_community_app;
-- ... (see full script in recommendations doc)
```

**Deliverables:**
- All database users created
- Privileges correctly assigned
- Verification queries passed
- User credentials provided securely to application team

---

### 4. Connection Pooling (PgBouncer) ✅ INFRA

**Infrastructure Team Owns:**
- [ ] PgBouncer installation and configuration
- [ ] `pgbouncer.ini` configuration
- [ ] User authentication configuration in PgBouncer
- [ ] SSL/TLS configuration for PgBouncer
- [ ] PgBouncer network configuration
- [ ] PgBouncer monitoring and health checks
- [ ] PgBouncer connection limits and pool sizing

**Deliverables:**
- PgBouncer service running and accessible
- Connection string for application team: `postgresql://pgbouncer:6432/sira_community`
- PgBouncer health check endpoint

---

### 5. Network Security ✅ INFRA

**Infrastructure Team Owns:**
- [ ] Database server firewall configuration
- [ ] Network segmentation (database in private network)
- [ ] Security group rules (if cloud)
- [ ] VPN/private network setup
- [ ] Network access control lists (ACLs)
- [ ] DDoS protection configuration

**Deliverables:**
- Database only accessible from authorized IPs/networks
- Network diagram showing security boundaries
- Firewall rules documented

---

### 6. Monitoring and Audit Infrastructure ✅ INFRA

**Infrastructure Team Owns:**
- [ ] PostgreSQL audit logging configuration
- [ ] Log aggregation setup (if centralized)
- [ ] Database connection monitoring
- [ ] Performance monitoring tools
- [ ] Alerting infrastructure
- [ ] Log retention policies

**Configuration:**
```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'ddl';
```

**Deliverables:**
- Audit logging enabled
- Monitoring dashboards accessible
- Alert rules configured

---

### 7. Secrets Management Infrastructure ✅ INFRA

**Infrastructure Team Owns:**
- [ ] Secrets management system setup (Vault, AWS Secrets Manager, etc.)
- [ ] Secrets storage configuration
- [ ] Access control for secrets
- [ ] Secrets rotation automation (infrastructure)
- [ ] Secrets backup and recovery

**Deliverables:**
- Secrets management system operational
- Application team has access to retrieve secrets
- Documentation on how to access secrets

---

## Application Team Responsibilities

### 1. Docker Configuration ✅ APP

**Application Team Owns:**
- [ ] Update `docker-compose.sira-community.app.yml` with correct user credentials
- [ ] Configure SSL certificate paths in Docker volumes
- [ ] Set environment variables for database connection
- [ ] Configure service dependencies (migrate → app → sidekiq)
- [ ] Update connection strings to use correct users

**Files to Update:**
```
docker/docker-compose.sira-community.app.yml
docker/env.community.app.local
```

**Example Configuration:**
```yaml
services:
  migrate:
    environment:
      DISCOURSE_DB_USERNAME: sira_community_migrate
      DISCOURSE_DB_PASSWORD_FILE: /run/secrets/db_migrate_password
    volumes:
      - ./ssl/migrate:/opt/sira-ai/ssl/migrate:ro
  
  app:
    environment:
      DISCOURSE_DB_USERNAME: sira_community_app
      DISCOURSE_DB_PASSWORD_FILE: /run/secrets/db_app_password
    volumes:
      - ./ssl/app:/opt/sira-ai/ssl/app:ro
```

**Deliverables:**
- Updated Docker Compose configuration
- Environment variables correctly set
- SSL certificate paths configured

---

### 2. Application Code Configuration ✅ APP

**Application Team Owns:**
- [ ] Update `config/database.yml` (if used)
- [ ] Ensure application uses environment variables for DB credentials
- [ ] Update connection string format for SSL/mTLS
- [ ] Test database connections from application
- [ ] Handle connection errors gracefully

**Deliverables:**
- Application code uses correct database user per service
- Connection strings include SSL configuration
- Application can connect successfully

---

### 3. SSL Certificate Integration ✅ APP

**Application Team Owns:**
- [ ] Receive SSL certificates from infrastructure team
- [ ] Store certificates securely in application repository (encrypted)
- [ ] Configure Docker volumes to mount certificates
- [ ] Update application to use certificate paths from environment
- [ ] Verify certificates are accessible in containers

**Certificate Paths in Container:**
```
/opt/sira-ai/ssl/migrate/migrate-client.crt
/opt/sira-ai/ssl/migrate/migrate-client.key
/opt/sira-ai/ssl/app/app-client.crt
/opt/sira-ai/ssl/app/app-client.key
```

**Deliverables:**
- Certificates stored securely
- Docker volumes configured correctly
- Application can access certificates

---

### 4. Secrets Integration ✅ APP

**Application Team Owns:**
- [ ] Retrieve database passwords from secrets management
- [ ] Configure Docker secrets (if using Docker Swarm)
- [ ] Update environment files to use secrets
- [ ] Test secret retrieval in containers
- [ ] Document secret names and locations

**Deliverables:**
- Application retrieves secrets correctly
- No hardcoded passwords in code
- Secrets rotation process documented

---

### 5. Migration Scripts ✅ APP

**Application Team Owns:**
- [ ] Ensure migrations use correct database user (migrate user)
- [ ] Test migrations with new user configuration
- [ ] Verify migrations can create tables, indexes, extensions
- [ ] Handle migration errors appropriately
- [ ] Document migration process

**Deliverables:**
- Migrations work with migrate user
- Migration process documented
- Rollback procedures tested

---

### 6. Application Testing ✅ APP

**Application Team Owns:**
- [ ] Test application startup with app user
- [ ] Test database operations (SELECT, INSERT, UPDATE, DELETE)
- [ ] Verify application cannot perform DDL operations
- [ ] Test connection pooling (if PgBouncer is used)
- [ ] Load testing with new connection configuration
- [ ] Error handling for connection failures

**Deliverables:**
- Application works correctly with app user
- All database operations functional
- Performance acceptable

---

### 7. Documentation ✅ APP

**Application Team Owns:**
- [ ] Update deployment documentation
- [ ] Document database user configuration
- [ ] Document SSL certificate requirements
- [ ] Create runbooks for common issues
- [ ] Document troubleshooting steps

**Deliverables:**
- Updated README with new configuration
- Deployment guide updated
- Troubleshooting documentation

---

## Shared Responsibilities

### 1. Testing and Verification 🤝 BOTH

**Infrastructure Team:**
- [ ] Provide test database for application team
- [ ] Verify database users can connect
- [ ] Test SSL certificate authentication

**Application Team:**
- [ ] Test application with new configuration
- [ ] Verify migrations work
- [ ] Test application operations

**Joint:**
- [ ] End-to-end testing session
- [ ] Verify all services work together
- [ ] Performance testing

---

### 2. Security Review 🤝 BOTH

**Infrastructure Team:**
- [ ] Review database security configuration
- [ ] Verify privilege separation
- [ ] Audit access controls

**Application Team:**
- [ ] Review application security
- [ ] Verify no hardcoded credentials
- [ ] Check certificate handling

**Joint:**
- [ ] Security audit
- [ ] Penetration testing (if applicable)
- [ ] Compliance review

---

### 3. Incident Response 🤝 BOTH

**Infrastructure Team:**
- [ ] Database-level incident response
- [ ] Connection issues
- [ ] Performance problems

**Application Team:**
- [ ] Application-level incident response
- [ ] Migration failures
- [ ] Application errors

**Joint:**
- [ ] Coordinate during incidents
- [ ] Post-incident review
- [ ] Documentation updates

---

## Implementation Checklist

### Phase 1: Infrastructure Setup (Infrastructure Team)
- [ ] Generate SSL certificates for each user role
- [ ] Configure `pg_hba.conf` with certificate authentication
- [ ] Configure `pg_ident.conf` with user mapping
- [ ] Create database users with correct privileges
- [ ] Set up PgBouncer (if using)
- [ ] Configure network security
- [ ] Enable audit logging
- [ ] Set up secrets management
- [ ] **Handoff:** Provide certificates, credentials, and connection details to application team

### Phase 2: Application Integration (Application Team)
- [ ] Receive SSL certificates from infrastructure team
- [ ] Update Docker Compose configuration
- [ ] Configure environment variables
- [ ] Update application code (if needed)
- [ ] Test database connections
- [ ] Test migrations
- [ ] Test application operations
- [ ] Update documentation

### Phase 3: Testing (Both Teams)
- [ ] Infrastructure team: Verify database configuration
- [ ] Application team: Test application functionality
- [ ] Joint: End-to-end testing
- [ ] Joint: Security review
- [ ] Joint: Performance testing

### Phase 4: Deployment (Both Teams)
- [ ] Infrastructure team: Final database configuration review
- [ ] Application team: Deploy updated application
- [ ] Both: Monitor deployment
- [ ] Both: Verify all services operational
- [ ] Both: Post-deployment review

---

## Handoff Points

### Infrastructure → Application Team

**Required Deliverables:**
1. **SSL Certificates**
   - `migrate-client.crt` and `migrate-client.key`
   - `app-client.crt` and `app-client.key`
   - `readonly-client.crt` and `readonly-client.key` (if needed)
   - CA certificate: `ca.crt`

2. **Database Credentials** (via secrets management)
   - `sira_community_migrate` password
   - `sira_community_app` password
   - `sira_community_readonly` password (if needed)

3. **Connection Information**
   - Database host: `postgres-community` (or IP)
   - Database port: `5432` (or PgBouncer port `6432`)
   - Database name: `sira_community`
   - SSL mode: `require`
   - Certificate paths (where to mount in containers)

4. **Configuration Details**
   - User privileges summary
   - Connection limits
   - Any special requirements

### Application → Infrastructure Team

**Required Deliverables:**
1. **Certificate Requirements**
   - Certificate CN (Common Name) format needed
   - Certificate validity period preferences

2. **Connection Requirements**
   - Expected connection count
   - Connection timeout requirements
   - Pool size requirements (if using PgBouncer)

3. **Migration Requirements**
   - Extensions needed (vector, unaccent, etc.)
   - Any special DDL requirements

---

## Communication Protocol

### Regular Check-ins
- **Weekly**: Status updates during implementation
- **Daily**: During active implementation phase
- **As needed**: For blockers or questions

### Escalation Path
1. **Technical Questions**: Direct communication between teams
2. **Blockers**: Escalate to project manager
3. **Security Concerns**: Escalate to security team

### Documentation Updates
- Both teams update shared documentation
- Changes communicated immediately
- Version control for all configuration changes

---

## Summary Table

| Task | Infrastructure Team | Application Team | Notes |
|------|-------------------|------------------|-------|
| PostgreSQL Configuration | ✅ | ❌ | Server setup |
| SSL Certificate Generation | ✅ | ❌ | CA and client certs |
| Database User Creation | ✅ | ❌ | Users and privileges |
| pg_hba.conf Configuration | ✅ | ❌ | Authentication rules |
| pg_ident.conf Configuration | ✅ | ❌ | Certificate mapping |
| PgBouncer Setup | ✅ | ❌ | Connection pooling |
| Network Security | ✅ | ❌ | Firewall, ACLs |
| Audit Logging | ✅ | ❌ | Server-level |
| Secrets Management Setup | ✅ | ❌ | Infrastructure |
| Docker Configuration | ❌ | ✅ | Compose files |
| Application Code | ❌ | ✅ | DB connection code |
| Certificate Integration | ❌ | ✅ | Mounting in containers |
| Secrets Integration | ❌ | ✅ | Retrieving from vault |
| Migration Testing | ❌ | ✅ | Testing migrations |
| Application Testing | ❌ | ✅ | Testing app operations |
| Documentation | 🤝 | 🤝 | Both teams |
| End-to-End Testing | 🤝 | 🤝 | Joint effort |
| Security Review | 🤝 | 🤝 | Joint effort |

---

## Quick Reference

### Infrastructure Team Contact
- **Primary Contact**: [Infrastructure Team Lead]
- **Escalation**: [Infrastructure Manager]
- **Slack Channel**: `#infrastructure`

### Application Team Contact
- **Primary Contact**: [Application Team Lead]
- **Escalation**: [Application Manager]
- **Slack Channel**: `#application`

---

## Next Steps

1. **Infrastructure Team**: Begin certificate generation and database user setup
2. **Application Team**: Prepare Docker configuration updates
3. **Both Teams**: Schedule kickoff meeting to align on timeline
4. **Both Teams**: Set up communication channels for coordination



