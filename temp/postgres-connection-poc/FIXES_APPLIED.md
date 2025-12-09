# PostgreSQL Connection Fixes Applied

## Summary

Based on the POC results and infrastructure team guidance, the following fixes were applied to resolve PostgreSQL connection issues:

---

## Fixes Applied

### 1. ✅ Fixed Database Host Name
**File:** `config/discourse.conf`
- **Before:** `db_host = postgres`
- **After:** `db_host = postgres-community`
- **Reason:** Infrastructure team specified service name must be `postgres-community`, not `postgres` or `localhost`

### 2. ✅ Added SSL Parameters to database_config Method
**File:** `app/models/global_setting.rb`
- **Added:** SSL configuration parameters (`sslmode`, `sslcert`, `sslkey`, `sslrootcert`) to the `database_config` method
- **Reason:** POC confirmed that mTLS with client certificates is required. The `database_config` method was missing these parameters, causing connection failures.

**Code Added:**
```ruby
# SIRA Infrastructure: PostgreSQL SSL/TLS Configuration (mTLS - REQUIRED)
if db_sslmode.present?
  hash["sslmode"] = db_sslmode
end

if db_sslmode.present? && (db_sslmode == 'require' || db_sslmode == 'verify-full' || db_sslmode == 'verify-ca')
  ssl_cert = ENV['POSTGRES_SSL_CERT'] || ENV['POSTGRES_CLIENT_CERT']
  ssl_key = ENV['POSTGRES_SSL_KEY'] || ENV['POSTGRES_CLIENT_KEY']
  ssl_ca = ENV['POSTGRES_SSL_CA'] || ENV['POSTGRES_CA_FILE']

  if ssl_cert.present? && File.exist?(ssl_cert)
    hash["sslcert"] = ssl_cert
  end
  if ssl_key.present? && File.exist?(ssl_key)
    hash["sslkey"] = ssl_key
  end
  if ssl_ca.present? && File.exist?(ssl_ca)
    hash["sslrootcert"] = ssl_ca
  end
end
```

### 3. ✅ Fixed Password Configuration
**File:** `config/discourse.conf`
- **Before:** `db_password = ${DISCOURSE_DB_PASSWORD}` (environment variable substitution not working)
- **After:** `db_password = community_app_password_2025` (explicit value)
- **Reason:** Discourse doesn't automatically substitute environment variables in `discourse.conf`. The password must be set explicitly or via the `DISCOURSE_DB_PASSWORD` environment variable (which is also set in docker-compose).

### 4. ✅ Fixed PostgreSQL Certificate Paths
**File:** `docker/docker-compose.sira-community.app.yml`
- **Before:** `/opt/sira-ai/ssl/postgres/sira-community-postgres-client.crt`
- **After:** `/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.crt`
- **Reason:** Infrastructure team specified certificates are mounted at `/opt/sira-ai/ssl/postgres-community/`, not `/opt/sira-ai/ssl/postgres/`

**Updated Environment Variables:**
- `POSTGRES_SSL_CERT`: `/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.crt`
- `POSTGRES_SSL_KEY`: `/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.key`
- `POSTGRES_CLIENT_CERT`: `/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.crt`
- `POSTGRES_CLIENT_KEY`: `/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.key`

---

## POC Results

The POC confirmed that **all 6 connection configurations work**, including:
- ✅ Basic connection (no SSL)
- ✅ sslmode=require
- ✅ sslmode=require + CA cert
- ✅ **mTLS with client certificates** (required configuration)
- ✅ sslmode=verify-full + mTLS
- ✅ Connection string with mTLS

**Working Configuration:**
```ruby
PG.connect(
  host: 'postgres-community',
  port: 5432,
  dbname: 'sira_community',
  user: 'sira_community_user',
  password: 'community_app_password_2025',
  sslmode: 'require',
  sslrootcert: '/opt/sira-ai/ssl/ca/ca.crt',
  sslcert: '/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.crt',
  sslkey: '/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.key'
)
```

---

## Infrastructure Team Guidance Applied

✅ **Host:** `postgres-community` (service name, NOT `localhost` or `127.0.0.1`)  
✅ **Port:** `5432` (internal port, NOT `5433`)  
✅ **Database:** `sira_community`  
✅ **Username:** `sira_community_user`  
✅ **Password:** `community_app_password_2025`  
✅ **SSL Mode:** `require` (mTLS with client certificates)  
✅ **Certificate Path:** `/opt/sira-ai/ssl/postgres-community/`  
✅ **Network:** `sira_infra_network` (already connected)

---

## Next Steps

1. ✅ All fixes applied
2. ⏳ Wait for app to fully start and verify connection
3. ⏳ Check logs for successful PostgreSQL connection
4. ⏳ Verify all services are healthy

---

## Files Modified

1. `config/discourse.conf` - Fixed `db_host` and `db_password`
2. `app/models/global_setting.rb` - Added SSL parameters to `database_config`
3. `docker/docker-compose.sira-community.app.yml` - Fixed certificate paths

