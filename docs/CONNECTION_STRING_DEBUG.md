# Full Connection String and Configuration

**Date:** 2025-12-10  
**Purpose:** Share full connection details with infrastructure team for debugging

---

## Connection Parameters

Based on the application configuration, here is the full connection string being used:

### Connection String (without password):
```
postgresql://sira_community_migrate@sira_infra_postgres:5432/sira_community?sslmode=require&sslcert=/var/www/community/tmp/ssl/postgres-client.crt&sslkey=/var/www/community/tmp/ssl/postgres-client.key&sslrootcert=/var/www/community/tmp/ssl/ca.crt
```

### Full Connection String (with password - for infrastructure team reference):
```
postgresql://sira_community_migrate:community_admin_password_2025@sira_infra_postgres:5432/sira_community?sslmode=require&sslcert=/var/www/community/tmp/ssl/postgres-client.crt&sslkey=/var/www/community/tmp/ssl/postgres-client.key&sslrootcert=/var/www/community/tmp/ssl/ca.crt
```

### Full Connection String (with password - for infrastructure team reference):
```
postgresql://sira_community_migrate:community_admin_password_2025@sira_infra_postgres:5432/sira_community?sslmode=require&sslcert=/var/www/community/tmp/ssl/postgres-client.crt&sslkey=/var/www/community/tmp/ssl/postgres-client.key&sslrootcert=/var/www/community/tmp/ssl/ca.crt
```

### Full Configuration Hash:
- **adapter:** `postgresql`
- **host:** `sira_infra_postgres`
- **port:** `5432`
- **database:** `sira_community`
- **username:** `sira_community_migrate`
- **password:** `community_admin_password_2025` (29 characters)
- **sslmode:** `require`
- **sslcert:** `/var/www/community/tmp/ssl/postgres-client.crt`
- **sslkey:** `/var/www/community/tmp/ssl/postgres-client.key`
- **sslrootcert:** `/var/www/community/tmp/ssl/ca.crt`

---

## Certificate Details

### Certificate Files (inside container):
- **Certificate:** `/var/www/community/tmp/ssl/postgres-client.crt` (copied from `migrate-client.crt`)
- **Key:** `/var/www/community/tmp/ssl/postgres-client.key` (copied from `migrate-client.key`)
- **CA:** `/var/www/community/tmp/ssl/ca.crt`

### Certificate Source (mounted from host):
- **Certificate:** `C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca\server\postgres-community\client\migrate-client.crt`
- **Key:** `C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca\server\postgres-community\client\migrate-client.key`
- **CA:** `C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca\server\ca\ca.crt`

### Certificate CN:
- **CN:** `migrate-client` (verified)

---

## PostgreSQL Connection Parameters (as passed to pg gem)

The Ruby `pg` gem receives these parameters:
```ruby
{
  host: "sira_infra_postgres",
  port: 5432,
  dbname: "sira_community",
  user: "sira_community_migrate",
  password: "community_admin_password_2025",
  sslmode: "require",
  sslcert: "/var/www/community/tmp/ssl/postgres-client.crt",
  sslkey: "/var/www/community/tmp/ssl/postgres-client.key",
  sslrootcert: "/var/www/community/tmp/ssl/ca.crt"
}
```

---

## Current Error

```
FATAL: password authentication failed for user "sira_community_migrate"
```

This error suggests that:
1. Certificate authentication is not being used (PostgreSQL is falling back to password)
2. OR certificate authentication is working but password is still required/checked
3. OR the password doesn't match what's configured in PostgreSQL

---

## Verification Steps for Infrastructure Team

1. **Verify pg_hba.conf:**
   ```bash
   # Should have:
   hostssl sira_community sira_community_migrate 0.0.0.0/0 cert map=migrate_map
   ```

2. **Verify pg_ident.conf:**
   ```bash
   # Should have:
   migrate_map     migrate-client    sira_community_migrate
   ```

3. **Test connection manually:**
   ```bash
   psql "postgresql://sira_community_migrate@sira_infra_postgres:5432/sira_community?sslmode=require" \
     --set=sslcert=/path/to/migrate-client.crt \
     --set=sslkey=/path/to/migrate-client.key \
     --set=sslrootcert=/path/to/ca.crt \
     -c "SELECT current_user, current_database();"
   ```

4. **Check PostgreSQL logs:**
   ```bash
   tail -f /var/log/postgresql/postgresql-*-main.log | grep sira_community_migrate
   ```

---

## Notes

- The application is correctly using the `migrate-client` certificate (CN: `migrate-client`)
- SSL mode is set to `require`
- All certificate files exist and are readable
- The error occurs during Rails initialization, before migrations run

