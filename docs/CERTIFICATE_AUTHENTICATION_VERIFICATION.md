# Certificate Authentication Verification Guide

**Date:** 2025-12-10  
**Purpose:** Verify certificate-based authentication is working correctly

---

## Current Status

✅ **Application Team Implementation:**
- Migrate-client certificates are being copied correctly
- Certificate CN: `migrate-client` (verified)
- Username: `sira_community_migrate` (correct)
- Password: `community_admin_password_2025` (from docker-compose default)

❌ **Current Error:**
```
FATAL: password authentication failed for user "sira_community_migrate"
```

---

## Certificate Details

### Migration User Certificate
- **File:** `migrate-client.crt` / `migrate-client.key`
- **CN (Common Name):** `migrate-client`
- **Location:** `C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca\server\postgres-community\client\migrate-client.crt`
- **Expected pg_ident.conf mapping:**
  ```
  migrate_map     migrate-client    sira_community_migrate
  ```

### Application User Certificate
- **File:** `app-client.crt` / `app-client.key`
- **CN (Common Name):** `app-client`
- **Location:** `C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca\server\postgres-community\client\app-client.crt`
- **Expected pg_ident.conf mapping:**
  ```
  app_map         app-client       sira_community_app
  ```

---

## Verification Checklist for Infrastructure Team

### 1. Verify pg_ident.conf Configuration

```sql
-- Connect to PostgreSQL as superuser
-- Check if pg_ident.conf has the correct mappings:

-- Expected content:
migrate_map     migrate-client    sira_community_migrate
app_map         app-client       sira_community_app
```

**Verification Command:**
```bash
# On PostgreSQL server
cat $PGDATA/pg_ident.conf | grep -E "migrate|app"
```

---

### 2. Verify pg_hba.conf Configuration

```bash
# Expected pg_hba.conf rules:
hostssl sira_community sira_community_migrate 0.0.0.0/0 cert map=migrate_map
hostssl sira_community sira_community_app 0.0.0.0/0 cert map=app_map
```

**Verification Command:**
```bash
# On PostgreSQL server
cat $PGDATA/pg_hba.conf | grep sira_community
```

**Important:** The authentication method should be `cert`, NOT `md5` or `password`.

---

### 3. Verify Database Users Exist

```sql
-- Connect as PostgreSQL superuser
SELECT usename, usesuper, usecreatedb 
FROM pg_user 
WHERE usename IN ('sira_community_migrate', 'sira_community_app');
```

**Expected:**
- `sira_community_migrate`: Should exist with CREATE privileges
- `sira_community_app`: Should exist with DML-only privileges

---

### 4. Verify Certificate CN Matches pg_ident.conf

**Test Certificate CN:**
```bash
# From application container or certificate location
openssl x509 -in migrate-client.crt -noout -subject
# Should show: CN=migrate-client

openssl x509 -in app-client.crt -noout -subject
# Should show: CN=app-client
```

**Verify pg_ident.conf matches:**
```bash
# The CN value must exactly match the second column in pg_ident.conf
# migrate-client → migrate-client (in pg_ident.conf)
# app-client → app-client (in pg_ident.conf)
```

---

### 5. Test Certificate Authentication Manually

**Test Migration User Connection:**
```bash
# Using migrate-client certificate
psql "postgresql://sira_community_migrate@sira_infra_postgres:5432/sira_community?sslmode=require" \
  -c "SELECT current_user, current_database();" \
  --set=sslcert=/path/to/migrate-client.crt \
  --set=sslkey=/path/to/migrate-client.key \
  --set=sslrootcert=/path/to/ca.crt
```

**Expected Result:**
- Should connect successfully
- Should show: `current_user = sira_community_migrate`
- Should NOT prompt for password

**If password is requested:**
- Certificate authentication is NOT working
- Check pg_hba.conf authentication method
- Check pg_ident.conf mapping

---

### 6. Check PostgreSQL Logs

**On PostgreSQL server, check logs for connection attempts:**
```bash
tail -f /var/log/postgresql/postgresql-*-main.log | grep sira_community
```

**Look for:**
- Certificate authentication success/failure messages
- Connection attempts with certificate CN
- Any errors related to certificate validation

---

## Common Issues and Solutions

### Issue 1: Password Authentication Error
**Symptom:** `FATAL: password authentication failed`

**Possible Causes:**
1. `pg_hba.conf` is using `md5` or `password` instead of `cert`
2. Certificate authentication is failing, falling back to password
3. Password doesn't match what's configured

**Solution:**
- Verify `pg_hba.conf` uses `cert` authentication method
- Verify certificate CN matches `pg_ident.conf` mapping
- Check PostgreSQL logs for certificate validation errors

---

### Issue 2: Certificate CN Mismatch
**Symptom:** Certificate authentication fails

**Solution:**
- Verify certificate CN exactly matches second column in `pg_ident.conf`
- Case-sensitive: `migrate-client` ≠ `Migrate-Client`
- No extra spaces or characters

---

### Issue 3: pg_ident.conf Not Loaded
**Symptom:** Certificate authentication doesn't work

**Solution:**
```sql
-- Reload PostgreSQL configuration
SELECT pg_reload_conf();

-- Or restart PostgreSQL service
```

---

## Current Connection Parameters

**Migration Service:**
- Host: `sira_infra_postgres`
- Port: `5432`
- Database: `sira_community`
- Username: `sira_community_migrate`
- Password: `community_admin_password_2025` (default, may need to be updated)
- SSL Mode: `require`
- Certificate: `/var/www/community/tmp/ssl/postgres-client.crt` (migrate-client.crt)
- Key: `/var/www/community/tmp/ssl/postgres-client.key` (migrate-client.key)
- CA: `/var/www/community/tmp/ssl/ca.crt`

**Certificate CN:** `migrate-client` (verified)

---

## Next Steps

1. **Infrastructure Team:** Verify `pg_hba.conf` uses `cert` authentication
2. **Infrastructure Team:** Verify `pg_ident.conf` has correct mapping for `migrate-client` → `sira_community_migrate`
3. **Infrastructure Team:** Verify password `community_admin_password_2025` matches what's configured
4. **Infrastructure Team:** Test certificate authentication manually using the commands above
5. **Application Team:** Retry migration after infrastructure team confirms fixes

---

## Support

If certificate authentication is confirmed working but password error persists:
- Check if PostgreSQL requires both certificate AND password
- Verify the password matches what infrastructure team configured
- Check PostgreSQL logs for detailed error messages



