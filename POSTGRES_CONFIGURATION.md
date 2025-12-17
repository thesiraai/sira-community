# Discourse PostgreSQL Configuration Guide

## Overview

Discourse uses PostgreSQL as its primary database. This document outlines the complete PostgreSQL configuration required for Discourse to function properly.

## Required Environment Variables

Discourse reads PostgreSQL configuration from the following environment variables:

### Core Database Connection

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `DISCOURSE_DB_HOST` | PostgreSQL server hostname or IP | `postgres-community` | ✅ Yes |
| `DISCOURSE_DB_PORT` | PostgreSQL server port | `5432` | ✅ Yes |
| `DISCOURSE_DB_NAME` | Database name | `sira_community` | ✅ Yes |
| `DISCOURSE_DB_USERNAME` | Database username | `sira_community_user` | ✅ Yes |
| `DISCOURSE_DB_PASSWORD` | Database password | `community_app_password_2025` | ✅ Yes |
| `DISCOURSE_DB_POOL` | Connection pool size | `8` | ⚠️ Optional (default: 5) |

### SSL/TLS Configuration (Optional but Recommended for Production)

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `DISCOURSE_DB_SSL_MODE` | SSL connection mode | `require`, `prefer`, `disable` | ⚠️ Optional |
| `DISCOURSE_DB_SSL_CERT` | Client certificate path | `/opt/sira-ai/ssl/postgres-community/client/app-client.crt` | ⚠️ If using mTLS |
| `DISCOURSE_DB_SSL_KEY` | Client private key path | `/opt/sira-ai/ssl/postgres-community/client/app-client.key` | ⚠️ If using mTLS |
| `DISCOURSE_DB_SSL_CA` | CA certificate path | `/opt/sira-ai/ssl/ca/ca.crt` | ⚠️ If using mTLS |

### Advanced SSL Configuration (Passed to PostgreSQL Connection)

Discourse also supports passing additional SSL parameters via `DISCOURSE_DB_VARIABLES_*`:

| Variable | Description | Example |
|----------|-------------|---------|
| `DISCOURSE_DB_VARIABLES_sslmode` | SSL mode for connection | `require` |
| `DISCOURSE_DB_VARIABLES_sslcert` | Client certificate | `/opt/sira-ai/ssl/postgres-community/client/app-client.crt` |
| `DISCOURSE_DB_VARIABLES_sslkey` | Client private key | `/opt/sira-ai/ssl/postgres-community/client/app-client.key` |
| `DISCOURSE_DB_VARIABLES_sslrootcert` | CA certificate | `/opt/sira-ai/ssl/ca/ca.crt` |

## Current SIRA Community Configuration

### Environment Variables (`docker/env.discourse.local`)

```bash
# Database Configuration
COMMUNITY_DB_NAME=sira_community
COMMUNITY_DB_USERNAME=sira_community_user
COMMUNITY_DB_PASSWORD=community_app_password_2025
COMMUNITY_DB_POOL=8

# PostgreSQL SSL/mTLS Configuration
DISCOURSE_DB_SSL_MODE=require
DISCOURSE_DB_SSL_CERT=/opt/sira-ai/ssl/postgres-community/client/app-client.crt
DISCOURSE_DB_SSL_KEY=/opt/sira-ai/ssl/postgres-community/client/app-client.key
DISCOURSE_DB_SSL_CA=/opt/sira-ai/ssl/ca/ca.crt

# PostgreSQL SSL variables (passed through to connection)
DISCOURSE_DB_VARIABLES_sslmode=require
DISCOURSE_DB_VARIABLES_sslcert=/opt/sira-ai/ssl/postgres-community/client/app-client.crt
DISCOURSE_DB_VARIABLES_sslkey=/opt/sira-ai/ssl/postgres-community/client/app-client.key
DISCOURSE_DB_VARIABLES_sslrootcert=/opt/sira-ai/ssl/ca/ca.crt
```

### Docker Compose Configuration (`docker/docker-compose.discourse.yml`)

```yaml
environment:
  # Database Configuration
  - DISCOURSE_DB_HOST=postgres-community
  - DISCOURSE_DB_PORT=5432
  - DISCOURSE_DB_NAME=${COMMUNITY_DB_NAME:-sira_community}
  - DISCOURSE_DB_USERNAME=${COMMUNITY_DB_USERNAME:-sira_community_user}
  - DISCOURSE_DB_PASSWORD=${COMMUNITY_DB_PASSWORD:-community_app_password_2025}
  - DISCOURSE_DB_POOL=${COMMUNITY_DB_POOL:-8}
  
  # PostgreSQL SSL/mTLS Configuration
  - DISCOURSE_DB_SSL_MODE=${DISCOURSE_DB_SSL_MODE:-require}
  - DISCOURSE_DB_SSL_CERT=${DISCOURSE_DB_SSL_CERT:-/opt/sira-ai/ssl/postgres-community/client/app-client.crt}
  - DISCOURSE_DB_SSL_KEY=${DISCOURSE_DB_SSL_KEY:-/opt/sira-ai/ssl/postgres-community/client/app-client.key}
  - DISCOURSE_DB_SSL_CA=${DISCOURSE_DB_SSL_CA:-/opt/sira-ai/ssl/ca/ca.crt}
  
  # PostgreSQL SSL variables (passed through to connection)
  - DISCOURSE_DB_VARIABLES_sslmode=${DISCOURSE_DB_VARIABLES_sslmode:-require}
  - DISCOURSE_DB_VARIABLES_sslcert=${DISCOURSE_DB_VARIABLES_sslcert:-/opt/sira-ai/ssl/postgres-community/client/app-client.crt}
  - DISCOURSE_DB_VARIABLES_sslkey=${DISCOURSE_DB_VARIABLES_sslkey:-/opt/sira-ai/ssl/postgres-community/client/app-client.key}
  - DISCOURSE_DB_VARIABLES_sslrootcert=${DISCOURSE_DB_VARIABLES_sslrootcert:-/opt/sira-ai/ssl/ca/ca.crt}
```

## PostgreSQL Server Requirements

### 1. Database Setup

The database must be created on the PostgreSQL server before Discourse can connect:

```sql
-- Connect to PostgreSQL as superuser
psql -U postgres

-- Create database
CREATE DATABASE sira_community;

-- Create user
CREATE USER sira_community_user WITH PASSWORD 'community_app_password_2025';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE sira_community TO sira_community_user;

-- Grant schema privileges (required for Rails migrations)
\c sira_community
GRANT ALL ON SCHEMA public TO sira_community_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sira_community_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO sira_community_user;
```

### 2. PostgreSQL Configuration (`postgresql.conf`)

Ensure PostgreSQL is configured to accept connections:

```conf
# Listen on all interfaces (or specific IP)
listen_addresses = '*'

# Port
port = 5432

# SSL Configuration (if using SSL)
ssl = on
ssl_cert_file = '/path/to/server.crt'
ssl_key_file = '/path/to/server.key'
ssl_ca_file = '/path/to/ca.crt'  # For client certificate verification
```

### 3. Client Authentication (`pg_hba.conf`)

Configure `pg_hba.conf` to allow connections from the Discourse container:

**For SSL/mTLS connections:**
```
# TYPE  DATABASE        USER                    ADDRESS                 METHOD
hostssl sira_community  sira_community_user     172.18.0.0/16          cert
```

**For non-SSL connections (not recommended for production):**
```
# TYPE  DATABASE        USER                    ADDRESS                 METHOD
host    sira_community  sira_community_user     172.18.0.0/16          md5
```

**For SSL with password authentication (scram-sha-256 - Recommended):**
```
# TYPE  DATABASE        USER                    ADDRESS                 METHOD
hostssl sira_community  sira_community_user     172.18.0.0/16          scram-sha-256
```

**For SSL with password authentication (md5 - Legacy):**
```
# TYPE  DATABASE        USER                    ADDRESS                 METHOD
hostssl sira_community  sira_community_user     172.18.0.0/16          md5
```

**Key Points:**
- `172.18.0.0/16` is the Docker network subnet (adjust if different)
- `cert` method requires client certificates (mTLS)
- `scram-sha-256` method uses secure password authentication (recommended)
- `md5` method uses password authentication (legacy, less secure)
- `hostssl` requires SSL connection
- `host` allows non-SSL connections (not secure)

### 4. Network Configuration

Ensure the PostgreSQL server is accessible from the Discourse container:

1. **Docker Network**: Both containers must be on the same network (`sira_infra_network`)
2. **Firewall**: Allow connections on port 5432
3. **Service Discovery**: Use service name (`postgres-community`) for hostname

## Connection Pool Settings

Discourse uses ActiveRecord connection pooling. Recommended settings:

- **Development**: `DISCOURSE_DB_POOL=5` (default)
- **Production (Small)**: `DISCOURSE_DB_POOL=8-10`
- **Production (Medium)**: `DISCOURSE_DB_POOL=15-20`
- **Production (Large)**: `DISCOURSE_DB_POOL=25-30`

Formula: `pool_size = (num_unicorn_workers * 2) + (num_sidekiq_workers)`

## SSL/TLS Configuration Options

### Option 1: SSL with Password Authentication (Recommended for most cases)

```bash
DISCOURSE_DB_SSL_MODE=require
# No client certificates needed
DISCOURSE_DB_SSL_CA=/opt/sira-ai/ssl/ca/ca.crt
```

PostgreSQL `pg_hba.conf`:
```
hostssl sira_community  sira_community_user     172.18.0.0/16          scram-sha-256
```

**Note:** Discourse fully supports `scram-sha-256` authentication. The PostgreSQL `pg` gem (used by Rails/ActiveRecord) supports SCRAM-SHA-256 authentication methods.

### Option 2: SSL with Client Certificates (mTLS - Most Secure)

```bash
DISCOURSE_DB_SSL_MODE=require
DISCOURSE_DB_SSL_CERT=/opt/sira-ai/ssl/postgres-community/client/app-client.crt
DISCOURSE_DB_SSL_KEY=/opt/sira-ai/ssl/postgres-community/client/app-client.key
DISCOURSE_DB_SSL_CA=/opt/sira-ai/ssl/ca/ca.crt
```

PostgreSQL `pg_hba.conf`:
```
hostssl sira_community  sira_community_user     172.18.0.0/16          cert
```

### Option 3: No SSL (Development Only)

```bash
DISCOURSE_DB_SSL_MODE=disable
# Or omit SSL variables
```

PostgreSQL `pg_hba.conf`:
```
host    sira_community  sira_community_user     172.18.0.0/16          md5
```

## Verification Steps

### 1. Test Database Connection from Discourse Container

```bash
docker exec sira-discourse psql \
  -h postgres-community \
  -U sira_community_user \
  -d sira_community \
  -c "SELECT version();"
```

### 2. Check Environment Variables

```bash
docker exec sira-discourse env | grep DISCOURSE_DB
```

### 3. Verify Database Exists

```bash
# From PostgreSQL server
psql -U postgres -c "\l" | grep sira_community
```

### 4. Check User Permissions

```bash
# From PostgreSQL server
psql -U postgres -d sira_community -c "\du sira_community_user"
```

### 5. Test SSL Connection

```bash
docker exec sira-discourse psql \
  "host=postgres-community port=5432 dbname=sira_community user=sira_community_user sslmode=require" \
  -c "SELECT version();"
```

## Common Issues and Solutions

### Issue 1: `pg_hba.conf rejects connection`

**Error**: `FATAL: pg_hba.conf rejects connection for host "172.18.0.11", user "sira_community_user", database "sira_community"`

**Solution**:
1. Check `pg_hba.conf` has correct entry for Discourse container IP/subnet
2. Ensure entry matches connection type (SSL vs non-SSL)
3. Reload PostgreSQL: `SELECT pg_reload_conf();` or restart PostgreSQL

### Issue 2: `database "sira_community" does not exist`

**Error**: `FATAL: database "sira_community" does not exist`

**Solution**:
1. Create database: `CREATE DATABASE sira_community;`
2. Grant permissions: `GRANT ALL PRIVILEGES ON DATABASE sira_community TO sira_community_user;`

### Issue 3: `password authentication failed`

**Error**: `FATAL: password authentication failed for user "sira_community_user"`

**Solution**:
1. Verify password matches in both Discourse config and PostgreSQL
2. Reset password: `ALTER USER sira_community_user WITH PASSWORD 'new_password';`
3. Update `env.discourse.local` with new password

### Issue 4: `SSL connection required`

**Error**: `FATAL: SSL connection is required`

**Solution**:
1. Set `DISCOURSE_DB_SSL_MODE=require` in environment
2. Ensure PostgreSQL has SSL enabled in `postgresql.conf`
3. Check `pg_hba.conf` uses `hostssl` instead of `host`

### Issue 5: `certificate verify failed`

**Error**: `SSL_connect: certificate verify failed`

**Solution**:
1. Ensure CA certificate is correct: `DISCOURSE_DB_SSL_CA=/opt/sira-ai/ssl/ca/ca.crt`
2. Verify certificate paths are correct in container
3. Check certificate file permissions (readable by Discourse user)

## Current Status

### ✅ Configured
- Environment variables set correctly
- SSL certificates mounted
- Docker network configured

### ⚠️ Pending
- Database `sira_community` needs to be created
- User `sira_community_user` needs permissions
- `pg_hba.conf` needs to allow connections from Discourse container

## Next Steps

1. **Create Database and User** on PostgreSQL server
2. **Configure `pg_hba.conf`** to allow connections
3. **Reload PostgreSQL** configuration
4. **Test Connection** from Discourse container
5. **Start Discourse** and verify database migrations run successfully

