# Application Team - Database Security Implementation Checklist

**Document Version:** 1.0  
**Date:** 2025-12-10  
**Team:** Application  
**Status:** Waiting for Infrastructure Team Handoff

---

## Overview

This checklist guides the application team through integrating the new database security configuration with separate users and SSL certificates.

**Estimated Time:** 2-3 hours  
**Prerequisites:** Infrastructure team handoff (certificates, credentials, connection details)

---

## Pre-Implementation: Receive Handoff from Infrastructure Team

### Step 0.1: Receive Deliverables

- [ ] **Receive SSL Certificates**
  - [ ] Migration user certificate: `migrate-client.crt` and `migrate-client.key`
  - [ ] Application user certificate: `app-client.crt` and `app-client.key`
  - [ ] Read-only user certificate: `readonly-client.crt` and `readonly-client.key` (if applicable)
  - [ ] CA certificate: `ca.crt`

- [ ] **Receive Database Credentials** (from secrets management)
  - [ ] Migration user password
  - [ ] Application user password
  - [ ] Read-only user password (if applicable)

- [ ] **Receive Connection Information**
  - [ ] Database host: `postgres-community` (or IP)
  - [ ] Database port: `5432`
  - [ ] Database name: `sira_community`
  - [ ] SSL mode: `require`
  - [ ] Certificate paths (where to mount in containers)

- [ ] **Receive Configuration Documentation**
  - [ ] User privileges summary
  - [ ] Certificate CN values
  - [ ] Any special requirements

**Deliverable:** All handoff materials received and reviewed

---

## Phase 1: Store SSL Certificates Securely

### Step 1.1: Create Certificate Directory Structure

- [ ] **Create Local Certificate Directories**
  ```bash
  # In project root or secure location
  mkdir -p ssl-certs/sira-community/{migrate,app,readonly,ca}
  ```

- [ ] **Copy Certificates to Project**
  ```bash
  # Copy from infrastructure team delivery
  cp migrate-client.crt ssl-certs/sira-community/migrate/
  cp migrate-client.key ssl-certs/sira-community/migrate/
  cp app-client.crt ssl-certs/sira-community/app/
  cp app-client.key ssl-certs/sira-community/app/
  cp readonly-client.crt ssl-certs/sira-community/readonly/  # if applicable
  cp readonly-client.key ssl-certs/sira-community/readonly/  # if applicable
  cp ca.crt ssl-certs/sira-community/ca/
  ```

- [ ] **Set Secure File Permissions**
  ```bash
  chmod 600 ssl-certs/sira-community/**/*.key
  chmod 644 ssl-certs/sira-community/**/*.crt
  ```

- [ ] **Add to .gitignore** (if storing locally)
  ```bash
  # Add to .gitignore
  echo "ssl-certs/**/*.key" >> .gitignore
  echo "ssl-certs/**/*.crt" >> .gitignore
  ```

**Deliverable:** Certificates stored securely in project

---

### Step 1.2: Verify Certificate Structure

- [ ] **Verify Certificate CN Values**
  ```bash
  openssl x509 -in ssl-certs/sira-community/migrate/migrate-client.crt -noout -subject
  # Should show: CN=migrate-client
  
  openssl x509 -in ssl-certs/sira-community/app/app-client.crt -noout -subject
  # Should show: CN=app-client
  ```

- [ ] **Verify Certificate Validity**
  ```bash
  openssl x509 -in ssl-certs/sira-community/migrate/migrate-client.crt -noout -dates
  # Check expiration date
  ```

**Deliverable:** Certificates verified and valid

---

## Phase 2: Update Docker Compose Configuration

### Step 2.1: Update docker-compose.sira-community.app.yml

- [ ] **Update Migrate Service Configuration**
  ```yaml
  services:
    migrate:
      environment:
        # Use migration user
        DISCOURSE_DB_USERNAME: ${COMMUNITY_DB_ADMIN_USER:-sira_community_migrate}
        DISCOURSE_DB_PASSWORD: ${COMMUNITY_DB_ADMIN_PASSWORD}
        DISCOURSE_DB_HOST: postgres-community
        DISCOURSE_DB_PORT: ${POSTGRES_PORT:-5432}
        DISCOURSE_DB_NAME: sira_community
        # SSL Configuration
        POSTGRES_SSL_MODE: require
        POSTGRES_SSL_CERT: /var/www/community/tmp/ssl/postgres-client.crt
        POSTGRES_SSL_KEY: /var/www/community/tmp/ssl/postgres-client.key
        POSTGRES_SSL_CA: /var/www/community/tmp/ssl/ca.crt
      volumes:
        # Mount migration user certificates
        - ./ssl-certs/sira-community/migrate:/opt/sira-ai/ssl/migrate:ro
        - ./ssl-certs/sira-community/ca:/opt/sira-ai/ssl/ca:ro
        # Entrypoint will copy to writable location
        - ../tmp:/var/www/community/tmp
  ```

- [ ] **Update App Service Configuration**
  ```yaml
  services:
    app:
      environment:
        # Use application user
        DISCOURSE_DB_USERNAME: ${COMMUNITY_DB_USER:-sira_community_app}
        DISCOURSE_DB_PASSWORD: ${COMMUNITY_DB_PASSWORD}
        DISCOURSE_DB_HOST: postgres-community
        DISCOURSE_DB_PORT: ${POSTGRES_PORT:-5432}
        DISCOURSE_DB_NAME: sira_community
        # SSL Configuration
        POSTGRES_SSL_MODE: require
        POSTGRES_SSL_CERT: /var/www/community/tmp/ssl/postgres-client.crt
        POSTGRES_SSL_KEY: /var/www/community/tmp/ssl/postgres-client.key
        POSTGRES_SSL_CA: /var/www/community/tmp/ssl/ca.crt
      volumes:
        # Mount application user certificates
        - ./ssl-certs/sira-community/app:/opt/sira-ai/ssl/app:ro
        - ./ssl-certs/sira-community/ca:/opt/sira-ai/ssl/ca:ro
        - ../tmp:/var/www/community/tmp
  ```

- [ ] **Update Sidekiq Service Configuration**
  ```yaml
  services:
    sidekiq:
      environment:
        # Use application user (same as app service)
        DISCOURSE_DB_USERNAME: ${COMMUNITY_DB_USER:-sira_community_app}
        DISCOURSE_DB_PASSWORD: ${COMMUNITY_DB_PASSWORD}
        # ... (same SSL config as app service)
      volumes:
        # Mount application user certificates
        - ./ssl-certs/sira-community/app:/opt/sira-ai/ssl/app:ro
        - ./ssl-certs/sira-community/ca:/opt/sira-ai/ssl/ca:ro
        - ../tmp:/var/www/community/tmp
  ```

**Deliverable:** Docker Compose updated with correct user and certificate paths

---

### Step 2.2: Verify Entrypoint Script Handles Certificates

- [ ] **Check Entrypoint Script**
  ```bash
  # Verify entrypoint copies certificates from mounted location
  # to writable location (/var/www/community/tmp/ssl/)
  # Check: docker/entrypoint.sh or similar
  ```

- [ ] **Update Entrypoint if Needed**
  ```bash
  # Entrypoint should copy certificates:
  # From: /opt/sira-ai/ssl/migrate/ or /opt/sira-ai/ssl/app/
  # To: /var/www/community/tmp/ssl/
  # Files: postgres-client.crt, postgres-client.key, ca.crt
  ```

**Deliverable:** Entrypoint script correctly handles certificate copying

---

## Phase 3: Update Environment Configuration

### Step 3.1: Update env.community.app.local

- [ ] **Update Database User Variables**
  ```bash
  # Application User (for app and sidekiq services)
  COMMUNITY_DB_USER=sira_community_app
  COMMUNITY_DB_PASSWORD=<retrieve_from_secrets_management>
  
  # Admin User (for migrate service)
  COMMUNITY_DB_ADMIN_USER=sira_community_migrate
  COMMUNITY_DB_ADMIN_PASSWORD=<retrieve_from_secrets_management>
  
  # Database Configuration
  COMMUNITY_DB_NAME=sira_community
  POSTGRES_HOST=postgres-community
  POSTGRES_PORT=5432
  ```

- [ ] **Verify SSL Certificate Paths**
  ```bash
  # Ensure paths match Docker volume mounts
  POSTGRES_SSL_CERT=/var/www/community/tmp/ssl/postgres-client.crt
  POSTGRES_SSL_KEY=/var/www/community/tmp/ssl/postgres-client.key
  POSTGRES_SSL_CA=/var/www/community/tmp/ssl/ca.crt
  ```

- [ ] **Remove Old Configuration** (if any)
  ```bash
  # Remove any hardcoded credentials
  # Remove any old certificate paths
  ```

**Deliverable:** Environment file updated with correct credentials

---

### Step 3.2: Integrate with Secrets Management

- [ ] **Retrieve Credentials from Secrets Management**
  ```bash
  # Example using HashiCorp Vault
  vault kv get -field=migrate_password secret/sira-community/database
  vault kv get -field=app_password secret/sira-community/database
  ```

- [ ] **Update Environment File with Secrets**
  ```bash
  # Option 1: Use secrets file (Docker Swarm)
  # Option 2: Use environment variables from CI/CD
  # Option 3: Use .env file (not committed to Git)
  ```

- [ ] **Verify .env is in .gitignore**
  ```bash
  echo ".env" >> .gitignore
  echo "*.env.local" >> .gitignore
  ```

**Deliverable:** Credentials retrieved from secrets management

---

## Phase 4: Update Application Code (If Needed)

### Step 4.1: Check Database Configuration

- [ ] **Review config/database.yml** (if exists)
  ```yaml
  # Ensure it uses environment variables, not hardcoded values
  production:
    host: <%= ENV['DISCOURSE_DB_HOST'] %>
    username: <%= ENV['DISCOURSE_DB_USERNAME'] %>
    password: <%= ENV['DISCOURSE_DB_PASSWORD'] %>
    sslmode: require
    sslcert: <%= ENV['POSTGRES_SSL_CERT'] %>
    sslkey: <%= ENV['POSTGRES_SSL_KEY'] %>
    sslrootcert: <%= ENV['POSTGRES_SSL_CA'] %>
  ```

- [ ] **Verify No Hardcoded Credentials**
  ```bash
  # Search for hardcoded passwords or usernames
  grep -r "sira_community_user" --exclude-dir=node_modules --exclude-dir=.git
  grep -r "community_app_password" --exclude-dir=node_modules --exclude-dir=.git
  # Should only find in .env files or documentation
  ```

**Deliverable:** Application code uses environment variables

---

## Phase 5: Test Database Connections

### Step 5.1: Test Migration Service Connection

- [ ] **Start Migration Container**
  ```bash
  cd docker
  docker-compose -f docker-compose.sira-community.app.yml \
    --env-file env.community.app.local up -d migrate
  ```

- [ ] **Check Migration Container Logs**
  ```bash
  docker logs sira-community-migrate --tail 50
  # Should show successful connection
  # Should NOT show permission errors
  ```

- [ ] **Verify Certificate Usage**
  ```bash
  docker exec sira-community-migrate ls -la /var/www/community/tmp/ssl/
  # Should show: postgres-client.crt, postgres-client.key, ca.crt
  ```

- [ ] **Test Database Connection from Container**
  ```bash
  docker exec sira-community-migrate bundle exec rails runner \
    "puts ActiveRecord::Base.connection.execute('SELECT current_user').first"
  # Should show: sira_community_migrate
  ```

**Deliverable:** Migration service can connect successfully

---

### Step 5.2: Test Application Service Connection

- [ ] **Start Application Container** (after migrations)
  ```bash
  docker-compose -f docker-compose.sira-community.app.yml \
    --env-file env.community.app.local up -d app
  ```

- [ ] **Check Application Container Logs**
  ```bash
  docker logs sira-community-app --tail 50
  # Should show successful connection
  ```

- [ ] **Verify Application User**
  ```bash
  docker exec sira-community-app bundle exec rails runner \
    "puts ActiveRecord::Base.connection.execute('SELECT current_user').first"
  # Should show: sira_community_app
  ```

**Deliverable:** Application service can connect successfully

---

## Phase 6: Test Migrations

### Step 6.1: Run Database Migrations

- [ ] **Stop Existing Containers**
  ```bash
  docker-compose -f docker-compose.sira-community.app.yml \
    --env-file env.community.app.local down
  ```

- [ ] **Start Migration Service**
  ```bash
  docker-compose -f docker-compose.sira-community.app.yml \
    --env-file env.community.app.local up -d migrate
  ```

- [ ] **Monitor Migration Progress**
  ```bash
  docker logs -f sira-community-migrate
  # Watch for:
  # - Successful table creation
  # - No permission errors
  # - Migration completion
  ```

- [ ] **Verify Migration Success**
  ```bash
  docker ps -a --filter "name=sira-community-migrate"
  # Status should be: Exited (0) - success
  ```

- [ ] **Check Migration Logs for Errors**
  ```bash
  docker logs sira-community-migrate 2>&1 | grep -i "error\|permission\|denied"
  # Should be empty (no errors)
  ```

**Deliverable:** Migrations complete successfully

---

### Step 6.2: Verify Tables Created

- [ ] **Check Tables Exist** (if possible)
  ```bash
  # Connect to database and verify
  # Or check migration logs for table creation messages
  ```

**Deliverable:** Database tables created successfully

---

## Phase 7: Test Application Operations

### Step 7.1: Start All Services

- [ ] **Start Application Services**
  ```bash
  docker-compose -f docker-compose.sira-community.app.yml \
    --env-file env.community.app.local up -d
  ```

- [ ] **Verify All Services Running**
  ```bash
  docker ps --filter "name=sira-community"
  # Should show: migrate (exited 0), app (running), sidekiq (running), nginx (running)
  ```

**Deliverable:** All services started successfully

---

### Step 7.2: Test Application Functionality

- [ ] **Test Database Read Operations**
  ```bash
  # Application should be able to SELECT from tables
  # Check application logs for successful queries
  ```

- [ ] **Test Database Write Operations**
  ```bash
  # Application should be able to INSERT, UPDATE, DELETE
  # Test through application UI or API
  ```

- [ ] **Verify Application Cannot Create Tables**
  ```bash
  # This is expected - application user should NOT be able to CREATE
  # If application tries to CREATE and fails, that's correct behavior
  ```

- [ ] **Check Application Health**
  ```bash
  curl http://localhost:8080/srv/status
  # Should return: 200 OK
  ```

**Deliverable:** Application operations work correctly

---

## Phase 8: Verify Security

### Step 8.1: Verify User Separation

- [ ] **Verify Migration User Has CREATE Privilege**
  ```bash
  # Migration should be able to create tables
  # This was tested in Phase 6
  ```

- [ ] **Verify Application User Cannot CREATE**
  ```bash
  docker exec sira-community-app bundle exec rails runner \
    "ActiveRecord::Base.connection.execute('CREATE TABLE test (id int)')"
  # Should FAIL with: permission denied
  ```

- [ ] **Verify Application User Can Perform DML**
  ```bash
  # Application should be able to SELECT, INSERT, UPDATE, DELETE
  # This was tested in Phase 7
  ```

**Deliverable:** User privileges correctly enforced

---

### Step 8.2: Verify Certificate Authentication

- [ ] **Verify Wrong Certificate is Rejected**
  ```bash
  # Try connecting with wrong certificate → should fail
  # (This may require manual testing with psql)
  ```

- [ ] **Verify Certificate Mapping**
  ```bash
  # Migration certificate → connects as sira_community_migrate
  # Application certificate → connects as sira_community_app
  ```

**Deliverable:** Certificate authentication working correctly

---

## Phase 9: Update Documentation

### Step 9.1: Update Deployment Documentation

- [ ] **Update README.md**
  - Document new database user configuration
  - Document SSL certificate requirements
  - Update deployment steps

- [ ] **Update docker/README.md** (if exists)
  - Document certificate paths
  - Document environment variables
  - Document user separation

- [ ] **Create Troubleshooting Guide**
  - Common connection issues
  - Certificate problems
  - Permission errors

**Deliverable:** Documentation updated

---

### Step 9.2: Update CI/CD Configuration (If Applicable)

- [ ] **Update CI/CD Secrets**
  - Add database credentials to CI/CD secrets
  - Add certificate paths to CI/CD configuration

- [ ] **Update Deployment Scripts**
  - Ensure scripts use correct users
  - Ensure scripts mount certificates correctly

**Deliverable:** CI/CD updated (if applicable)

---

## Phase 10: Final Verification

### Step 10.1: End-to-End Testing

- [ ] **Full Deployment Test**
  ```bash
  # Clean deployment from scratch
  docker-compose down -v
  docker-compose build --no-cache
  docker-compose up -d migrate
  # Wait for migrations
  docker-compose up -d
  # Verify all services healthy
  ```

- [ ] **Verify Application Functionality**
  - [ ] Application starts successfully
  - [ ] Database operations work
  - [ ] No permission errors in logs
  - [ ] Health checks pass

- [ ] **Performance Check**
  - [ ] Connection times acceptable
  - [ ] No connection pool exhaustion
  - [ ] Application responsive

**Deliverable:** Full system verified and working

---

## Final Checklist

Before considering implementation complete:

- [ ] SSL certificates received and stored securely
- [ ] Docker Compose updated with correct users and certificates
- [ ] Environment variables updated
- [ ] Credentials retrieved from secrets management
- [ ] Application code reviewed (no hardcoded credentials)
- [ ] Migration service connects successfully
- [ ] Application service connects successfully
- [ ] Migrations complete successfully
- [ ] Application operations work correctly
- [ ] User privileges verified (migrate can CREATE, app cannot)
- [ ] Certificate authentication verified
- [ ] Documentation updated
- [ ] CI/CD updated (if applicable)
- [ ] End-to-end testing passed

---

## Rollback Plan

If issues occur:

- [ ] **Stop All Services**
  ```bash
  docker-compose down
  ```

- [ ] **Revert Docker Compose Changes**
  ```bash
  git checkout docker/docker-compose.sira-community.app.yml
  git checkout docker/env.community.app.local
  ```

- [ ] **Contact Infrastructure Team**
  - Report issues
  - Request support
  - Coordinate rollback if needed

---

## Support and Escalation

**Questions or Issues:**
- Contact: [Application Team Lead]
- Infrastructure Team: [Infrastructure Team Contact]
- Slack: `#application` or `#infrastructure`
- Escalation: [Project Manager]

**Estimated Completion Time:** 2-3 hours  
**Priority:** High  
**Dependencies:** Infrastructure team handoff

---

## Notes

- Keep backup of original configuration files
- Test in development environment first (if available)
- Document any deviations from this checklist
- Coordinate with infrastructure team for any issues
- Verify certificate expiration dates and renewal process



