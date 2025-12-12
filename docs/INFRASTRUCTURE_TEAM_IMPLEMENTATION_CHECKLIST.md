# Infrastructure Team - Database Security Implementation Checklist

**Document Version:** 1.0  
**Date:** 2025-12-10  
**Team:** Infrastructure  
**Status:** Ready for Implementation

---

## Overview

This checklist guides the infrastructure team through implementing production-grade database security with certificate-based authentication and proper user separation.

**Estimated Time:** 4-6 hours  
**Prerequisites:** PostgreSQL server access, SSL certificate authority access

---

## Phase 1: SSL Certificate Generation

### Step 1.1: Generate Client Certificates for Each User Role

- [ ] **Generate Migration User Certificate**
  ```bash
  # Create private key
  openssl genrsa -out migrate-client.key 2048
  
  # Create certificate signing request
  openssl req -new -key migrate-client.key -out migrate-client.csr \
    -subj "/CN=migrate-client/O=SIRA/C=US"
  
  # Sign certificate with CA
  openssl x509 -req -in migrate-client.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out migrate-client.crt -days 365 \
    -extensions v3_req -extfile <(echo "[v3_req]"; echo "subjectAltName=DNS:migrate-client")
  ```

- [ ] **Generate Application User Certificate**
  ```bash
  openssl genrsa -out app-client.key 2048
  openssl req -new -key app-client.key -out app-client.csr \
    -subj "/CN=app-client/O=SIRA/C=US"
  openssl x509 -req -in app-client.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out app-client.crt -days 365 \
    -extensions v3_req -extfile <(echo "[v3_req]"; echo "subjectAltName=DNS:app-client")
  ```

- [ ] **Generate Read-Only User Certificate** (Optional)
  ```bash
  openssl genrsa -out readonly-client.key 2048
  openssl req -new -key readonly-client.key -out readonly-client.csr \
    -subj "/CN=readonly-client/O=SIRA/C=US"
  openssl x509 -req -in readonly-client.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out readonly-client.crt -days 365 \
    -extensions v3_req -extfile <(echo "[v3_req]"; echo "subjectAltName=DNS:readonly-client")
  ```

- [ ] **Verify Certificate CN (Common Name)**
  ```bash
  openssl x509 -in migrate-client.crt -noout -subject
  # Should show: CN=migrate-client
  openssl x509 -in app-client.crt -noout -subject
  # Should show: CN=app-client
  ```

- [ ] **Set Proper File Permissions**
  ```bash
  chmod 600 migrate-client.key app-client.key readonly-client.key
  chmod 644 migrate-client.crt app-client.crt readonly-client.crt
  ```

**Deliverable:** Three sets of client certificates (migrate, app, readonly)

---

## Phase 2: PostgreSQL User Identity Mapping

### Step 2.1: Configure pg_ident.conf

- [ ] **Locate pg_ident.conf**
  ```bash
  # Typically at:
  /etc/postgresql/*/main/pg_ident.conf
  # or
  $PGDATA/pg_ident.conf
  ```

- [ ] **Add Certificate-to-User Mapping**
  ```bash
  # Add these lines to pg_ident.conf:
  
  # Migration user mapping
  migrate_map     migrate-client    sira_community_migrate
  
  # Application user mapping
  app_map         app-client       sira_community_app
  
  # Read-only user mapping (if using)
  readonly_map    readonly-client  sira_community_readonly
  ```

- [ ] **Verify Configuration Syntax**
  ```bash
  # Test configuration
  sudo -u postgres psql -c "SHOW ident_file;"
  ```

**Deliverable:** Updated `pg_ident.conf` with certificate mappings

---

## Phase 3: PostgreSQL Host-Based Authentication

### Step 3.1: Configure pg_hba.conf

- [ ] **Backup Current pg_hba.conf**
  ```bash
  sudo cp /etc/postgresql/*/main/pg_hba.conf /etc/postgresql/*/main/pg_hba.conf.backup
  ```

- [ ] **Add Certificate-Based Authentication Rules**
  ```bash
  # Add to pg_hba.conf (before any other rules for sira_community):
  
  # Migration user - Full DDL access (deployments only)
  hostssl sira_community sira_community_migrate 0.0.0.0/0 cert map=migrate_map
  
  # Application user - DML only (runtime operations)
  hostssl sira_community sira_community_app 0.0.0.0/0 cert map=app_map
  
  # Read-only user - SELECT only (if using)
  hostssl sira_community sira_community_readonly 0.0.0.0/0 cert map=readonly_map
  
  # Reject all other connections to sira_community
  hostssl sira_community all 0.0.0.0/0 reject
  ```

- [ ] **Verify Configuration Syntax**
  ```bash
  sudo -u postgres /usr/lib/postgresql/*/bin/pg_ctl -D $PGDATA -t 5 reload
  # Should not show errors
  ```

- [ ] **Test Configuration**
  ```bash
  # Verify pg_hba.conf is valid
  sudo -u postgres psql -c "SHOW hba_file;"
  ```

**Deliverable:** Updated `pg_hba.conf` with certificate authentication rules

---

## Phase 4: Database User Creation

### Step 4.1: Create Migration User

- [ ] **Connect as PostgreSQL Superuser**
  ```bash
  sudo -u postgres psql
  ```

- [ ] **Create Migration User**
  ```sql
  -- Create user
  CREATE USER sira_community_migrate WITH PASSWORD 'GENERATE_SECURE_PASSWORD_HERE';
  
  -- Make user owner of database and schema
  ALTER DATABASE sira_community OWNER TO sira_community_migrate;
  ALTER SCHEMA public OWNER TO sira_community_migrate;
  
  -- Grant schema privileges
  GRANT ALL ON SCHEMA public TO sira_community_migrate;
  GRANT CREATE ON SCHEMA public TO sira_community_migrate;
  GRANT USAGE ON SCHEMA public TO sira_community_migrate;
  
  -- Grant table privileges (existing tables)
  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sira_community_migrate;
  
  -- Grant sequence privileges
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO sira_community_migrate;
  
  -- Default privileges for future objects
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sira_community_migrate;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO sira_community_migrate;
  
  -- Database-level privileges
  GRANT CREATE ON DATABASE sira_community TO sira_community_migrate;
  
  -- Connection limits (security)
  ALTER USER sira_community_migrate WITH CONNECTION LIMIT 5;
  ```

- [ ] **Verify Migration User Privileges**
  ```sql
  -- Check schema ownership
  SELECT nspname, nspowner::regrole as owner 
  FROM pg_namespace 
  WHERE nspname = 'public';
  -- Should show: sira_community_migrate
  
  -- Check CREATE privilege
  SELECT has_schema_privilege('sira_community_migrate', 'public', 'CREATE');
  -- Should return: TRUE (t)
  
  -- Check database ownership
  SELECT datname, datdba::regrole as owner 
  FROM pg_database 
  WHERE datname = 'sira_community';
  -- Should show: sira_community_migrate
  ```

**Deliverable:** Migration user created with correct privileges

---

### Step 4.2: Create Application User

- [ ] **Create Application User**
  ```sql
  -- Create user
  CREATE USER sira_community_app WITH PASSWORD 'GENERATE_SECURE_PASSWORD_HERE';
  
  -- Basic privileges
  GRANT CONNECT ON DATABASE sira_community TO sira_community_app;
  GRANT USAGE ON SCHEMA public TO sira_community_app;
  
  -- DML privileges only (NO CREATE, ALTER, DROP)
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sira_community_app;
  
  -- Sequence privileges
  GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sira_community_app;
  
  -- Default privileges for future tables
  ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sira_community_app;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT USAGE, SELECT ON SEQUENCES TO sira_community_app;
  
  -- Connection limits
  ALTER USER sira_community_app WITH CONNECTION LIMIT 100;
  ```

- [ ] **Verify Application User Privileges**
  ```sql
  -- Verify NO CREATE privilege
  SELECT has_schema_privilege('sira_community_app', 'public', 'CREATE');
  -- Should return: FALSE (f)
  
  -- Verify DML privileges
  SELECT has_table_privilege('sira_community_app', 'users', 'SELECT');
  SELECT has_table_privilege('sira_community_app', 'users', 'INSERT');
  SELECT has_table_privilege('sira_community_app', 'users', 'UPDATE');
  SELECT has_table_privilege('sira_community_app', 'users', 'DELETE');
  -- All should return: TRUE (after tables exist)
  ```

**Deliverable:** Application user created with DML-only privileges

---

### Step 4.3: Create Read-Only User (Optional)

- [ ] **Create Read-Only User**
  ```sql
  CREATE USER sira_community_readonly WITH PASSWORD 'GENERATE_SECURE_PASSWORD_HERE';
  
  GRANT CONNECT ON DATABASE sira_community TO sira_community_readonly;
  GRANT USAGE ON SCHEMA public TO sira_community_readonly;
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO sira_community_readonly;
  
  ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT ON TABLES TO sira_community_readonly;
  
  ALTER USER sira_community_readonly WITH CONNECTION LIMIT 50;
  ```

**Deliverable:** Read-only user created (if needed)

---

## Phase 5: Test Certificate Authentication

### Step 5.1: Test Migration User Connection

- [ ] **Test with Migration Certificate**
  ```bash
  # Test connection using migrate certificate
  psql "postgresql://sira_community_migrate@postgres-community:5432/sira_community?sslmode=require" \
    --set=sslcert=/path/to/migrate-client.crt \
    --set=sslkey=/path/to/migrate-client.key \
    --set=sslrootcert=/path/to/ca.crt \
    -c "SELECT current_user, current_database();"
  # Should show: sira_community_migrate
  ```

- [ ] **Test CREATE TABLE Privilege**
  ```sql
  -- As migration user
  CREATE TABLE test_migrate_privilege (id integer);
  DROP TABLE test_migrate_privilege;
  -- Should succeed
  ```

**Deliverable:** Migration user can connect and create tables

---

### Step 5.2: Test Application User Connection

- [ ] **Test with Application Certificate**
  ```bash
  psql "postgresql://sira_community_app@postgres-community:5432/sira_community?sslmode=require" \
    --set=sslcert=/path/to/app-client.crt \
    --set=sslkey=/path/to/app-client.key \
    --set=sslrootcert=/path/to/ca.crt \
    -c "SELECT current_user, current_database();"
  # Should show: sira_community_app
  ```

- [ ] **Verify Application User Cannot Create Tables**
  ```sql
  -- As application user
  CREATE TABLE test_app_privilege (id integer);
  -- Should FAIL with: permission denied for schema public
  ```

**Deliverable:** Application user can connect but cannot create tables

---

## Phase 6: Enable Audit Logging

### Step 6.1: Configure PostgreSQL Logging

- [ ] **Enable Connection Logging**
  ```sql
  ALTER SYSTEM SET log_connections = 'on';
  ALTER SYSTEM SET log_disconnections = 'on';
  ```

- [ ] **Enable DDL Statement Logging**
  ```sql
  ALTER SYSTEM SET log_statement = 'ddl';
  -- Logs all CREATE, ALTER, DROP statements
  ```

- [ ] **Enable Slow Query Logging** (Optional)
  ```sql
  ALTER SYSTEM SET log_min_duration_statement = 1000;
  -- Log queries taking longer than 1 second
  ```

- [ ] **Reload Configuration**
  ```sql
  SELECT pg_reload_conf();
  ```

- [ ] **Verify Logging**
  ```bash
  # Check PostgreSQL logs
  tail -f /var/log/postgresql/postgresql-*-main.log
  # Should show connection attempts
  ```

**Deliverable:** Audit logging enabled and verified

---

## Phase 7: Network Security Configuration

### Step 7.1: Configure Firewall Rules

- [ ] **Restrict Database Access**
  ```bash
  # Only allow connections from application network
  # Example (adjust for your network):
  ufw allow from 172.20.0.0/16 to any port 5432
  ufw deny 5432
  ```

- [ ] **Verify Firewall Rules**
  ```bash
  ufw status numbered
  # or
  iptables -L -n | grep 5432
  ```

**Deliverable:** Database port restricted to authorized networks

---

## Phase 8: Prepare Deliverables for Application Team

### Step 8.1: Package SSL Certificates

- [ ] **Create Certificate Package**
  ```bash
  # Create directory structure
  mkdir -p sira-community-ssl-certs/{migrate,app,readonly,ca}
  
  # Copy certificates
  cp migrate-client.crt sira-community-ssl-certs/migrate/
  cp migrate-client.key sira-community-ssl-certs/migrate/
  cp app-client.crt sira-community-ssl-certs/app/
  cp app-client.key sira-community-ssl-certs/app/
  cp readonly-client.crt sira-community-ssl-certs/readonly/  # if using
  cp readonly-client.key sira-community-ssl-certs/readonly/  # if using
  cp ca.crt sira-community-ssl-certs/ca/
  
  # Create archive (encrypted if possible)
  tar -czf sira-community-ssl-certs.tar.gz sira-community-ssl-certs/
  ```

- [ ] **Set Secure Permissions**
  ```bash
  chmod 600 sira-community-ssl-certs/**/*.key
  chmod 644 sira-community-ssl-certs/**/*.crt
  ```

**Deliverable:** SSL certificates packaged and ready for distribution

---

### Step 8.2: Store Credentials in Secrets Management

- [ ] **Store Database Passwords**
  ```bash
  # Example using HashiCorp Vault
  vault kv put secret/sira-community/database \
    migrate_password="<migrate_password>" \
    app_password="<app_password>" \
    readonly_password="<readonly_password>"
  ```

- [ ] **Document Secret Paths**
  - Migration user password: `secret/sira-community/database#migrate_password`
  - Application user password: `secret/sira-community/database#app_password`
  - Read-only user password: `secret/sira-community/database#readonly_password`

**Deliverable:** Credentials stored in secrets management system

---

### Step 8.3: Create Handoff Document

- [ ] **Document Connection Details**
  ```
  Database Host: postgres-community (or IP address)
  Database Port: 5432
  Database Name: sira_community
  SSL Mode: require
  
  Certificate Paths (in container):
  - Migration: /opt/sira-ai/ssl/migrate/
  - Application: /opt/sira-ai/ssl/app/
  - Read-only: /opt/sira-ai/ssl/readonly/
  - CA: /opt/sira-ai/ssl/ca/
  ```

- [ ] **Document User Privileges Summary**
  - Migration user: DDL (CREATE, ALTER, DROP, extensions)
  - Application user: DML (SELECT, INSERT, UPDATE, DELETE)
  - Read-only user: SELECT only

- [ ] **Document Certificate CN Values**
  - Migration certificate CN: `migrate-client`
  - Application certificate CN: `app-client`
  - Read-only certificate CN: `readonly-client`

**Deliverable:** Handoff document with all connection details

---

## Phase 9: Verification and Testing

### Step 9.1: End-to-End Testing

- [ ] **Test Migration User Can Create Tables**
  ```sql
  -- Connect as migration user
  CREATE TABLE infrastructure_test (id serial PRIMARY KEY);
  INSERT INTO infrastructure_test DEFAULT VALUES;
  SELECT * FROM infrastructure_test;
  DROP TABLE infrastructure_test;
  -- All should succeed
  ```

- [ ] **Test Application User Can Perform DML**
  ```sql
  -- Connect as application user
  -- (After tables are created by migrations)
  SELECT COUNT(*) FROM users;  -- Should work
  -- CREATE TABLE test (id int);  -- Should fail
  ```

- [ ] **Test Certificate Mapping**
  ```bash
  # Verify certificate maps to correct user
  # Connect with migrate certificate → should be sira_community_migrate
  # Connect with app certificate → should be sira_community_app
  ```

- [ ] **Test Connection Rejection**
  ```bash
  # Try connecting without certificate → should be rejected
  # Try connecting with wrong certificate → should be rejected
  ```

**Deliverable:** All tests pass

---

## Phase 10: Documentation

### Step 10.1: Document Configuration

- [ ] **Document pg_hba.conf Changes**
  - List all rules added
  - Explain certificate mapping

- [ ] **Document pg_ident.conf Changes**
  - List all mappings
  - Explain certificate CN to user mapping

- [ ] **Document User Privileges**
  - Create privilege matrix
  - Document connection limits

- [ ] **Document Certificate Locations**
  - Where certificates are stored
  - How to rotate certificates
  - Certificate expiration dates

**Deliverable:** Complete infrastructure documentation

---

## Final Checklist

Before handing off to application team:

- [ ] All SSL certificates generated and verified
- [ ] `pg_ident.conf` configured with certificate mappings
- [ ] `pg_hba.conf` configured with certificate authentication
- [ ] All database users created with correct privileges
- [ ] Certificate authentication tested and working
- [ ] Audit logging enabled
- [ ] Network security configured
- [ ] Credentials stored in secrets management
- [ ] SSL certificates packaged for application team
- [ ] Handoff document created
- [ ] All tests passed
- [ ] Documentation complete

---

## Handoff to Application Team

**Deliverables Checklist:**

- [ ] SSL certificates package (encrypted transfer)
- [ ] Secrets management access details
- [ ] Connection information document
- [ ] User privileges summary
- [ ] Certificate CN values
- [ ] Support contact information

---

## Support and Escalation

**Questions or Issues:**
- Contact: [Infrastructure Team Lead]
- Slack: `#infrastructure`
- Escalation: [Infrastructure Manager]

**Estimated Completion Time:** 4-6 hours  
**Priority:** High  
**Dependencies:** None

---

## Notes

- All passwords should be randomly generated (32+ characters)
- Certificates should be valid for 1 year (adjust as needed)
- Keep backup of all configuration files before changes
- Test in staging environment first (if available)
- Document any deviations from this checklist



