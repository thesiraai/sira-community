# PostgreSQL Connection POC vs Application Code Comparison

## Summary

The POC test **succeeded** for all connection configurations, including mTLS. The current application code has **two critical issues**:

1. **Wrong host name**: `db_host = postgres` should be `db_host = postgres-community`
2. **Missing SSL parameters**: `database_config` method doesn't include SSL certificate paths

---

## 1. POC Working Configuration ✅

**Location:** `/var/www/community/temp/postgres-connection-poc/test_postgres_connection.rb`

All 6 tests **SUCCEEDED**, including:
- Basic connection (no SSL) ✅
- sslmode=require ✅
- sslmode=require + CA cert ✅
- **mTLS with client certificates** ✅ (This is what we need)
- sslmode=verify-full + mTLS ✅
- Connection string with mTLS ✅

**Working mTLS Configuration:**
```ruby
conn = PG.connect(
  host: 'postgres-community',  # ← Service name (NOT 'postgres' or 'localhost')
  port: 5432,                   # ← Internal port (NOT 5433)
  dbname: 'sira_community',
  user: 'sira_community_user',
  password: 'community_app_password_2025',
  sslmode: 'require',
  sslrootcert: '/opt/sira-ai/ssl/ca/ca.crt',
  sslcert: '/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.crt',
  sslkey: '/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.key'
)
```

**Result:** ✅ **SUCCESS** - All connection methods work

---

## 2. Current Application Code Issues ❌

### Issue 1: Wrong Host Name

**Location:** `config/discourse.conf` (line 15)

```ini
db_host = postgres  # ❌ WRONG - Should be 'postgres-community'
```

**Should be:**
```ini
db_host = postgres-community  # ✅ CORRECT - Service name per infrastructure team
```

### Issue 2: Missing SSL Parameters

**Location:** `app/models/global_setting.rb` (lines 129-177)

```ruby
def self.database_config(variables_overrides: {})
  hash = { "adapter" => "postgresql" }
  
  %w[pool connect_timeout socket host backup_host port backup_port username password replica_host replica_port].each do |s|
    if val = self.public_send("db_#{s}")
      hash[s] = val
    end
  end
  
  # ... other config ...
  
  # ❌ NO SSL PARAMETERS!
  # Missing: sslmode, sslrootcert, sslcert, sslkey
  
  { "production" => hash }
end
```

**What's Missing:**
- ❌ No `sslmode` parameter (even though `db_sslmode = require` is set in discourse.conf)
- ❌ No `sslrootcert` (CA certificate path)
- ❌ No `sslcert` (client certificate path)
- ❌ No `sslkey` (client key path)

---

## 3. Configuration Available in discourse.conf

**Location:** `config/discourse.conf` (lines 31-37)

```ini
db_sslmode = require
# Note: SSL certificate paths are configured via environment variables:
# POSTGRES_SSL_CERT=/opt/sira-ai/ssl/postgres/postgres-client.crt
# POSTGRES_SSL_KEY=/opt/sira-ai/ssl/postgres/postgres-client.key
# POSTGRES_SSL_CA=/opt/sira-ai/ssl/ca/ca.crt
```

**Status:** 
- ✅ `db_sslmode` is set in discourse.conf
- ❌ But `database_config` method doesn't read it
- ✅ Certificate paths are in environment variables
- ❌ But `database_config` method doesn't use them

---

## 4. Why the Application Fails

### Root Cause 1: Wrong Host Name
- Application tries to connect to `postgres` (doesn't exist)
- Should connect to `postgres-community` (service name)

### Root Cause 2: Missing SSL Parameters
Even if the host is correct, the connection will fail because:
1. `db_sslmode = require` is set, but `database_config` doesn't include it
2. PostgreSQL server requires mTLS (client certificates)
3. Without `sslcert` and `sslkey`, the connection fails with "no pg_hba.conf entry" or "password authentication failed"

---

## 5. The Fix Required

### Fix 1: Update Host Name
**File:** `config/discourse.conf`
```ini
db_host = postgres-community  # Change from 'postgres' to 'postgres-community'
```

### Fix 2: Add SSL Parameters to database_config
**File:** `app/models/global_setting.rb`

Add SSL configuration to `database_config` method:

```ruby
def self.database_config(variables_overrides: {})
  # ... existing code ...
  
  # Add SSL mode if configured
  if db_sslmode.present?
    hash["sslmode"] = db_sslmode
  end
  
  # Add SSL certificates if SSL is required
  if db_sslmode.present? && (db_sslmode == 'require' || db_sslmode == 'verify-full' || db_sslmode == 'verify-ca')
    # Get certificate paths from environment variables (set by entrypoint)
    ssl_cert = ENV['POSTGRES_SSL_CERT'] || ENV['POSTGRES_CLIENT_CERT']
    ssl_key = ENV['POSTGRES_SSL_KEY'] || ENV['POSTGRES_CLIENT_KEY']
    ssl_ca = ENV['POSTGRES_SSL_CA'] || ENV['POSTGRES_CA_FILE']
    
    # Add SSL parameters if certificates are available
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
  
  { "production" => hash }
end
```

---

## 6. Key Differences Summary

| Aspect | POC (Working) | Application (Failing) |
|--------|---------------|----------------------|
| Host | ✅ `postgres-community` | ❌ `postgres` |
| Port | ✅ `5432` | ✅ `5432` (correct) |
| Database | ✅ `sira_community` | ✅ `sira_community` (correct) |
| Username | ✅ `sira_community_user` | ✅ `sira_community_user` (correct) |
| Password | ✅ `community_app_password_2025` | ✅ `community_app_password_2025` (correct) |
| sslmode | ✅ `require` | ❌ **Missing** |
| sslrootcert | ✅ Set | ❌ **Missing** |
| sslcert | ✅ Set | ❌ **Missing** |
| sslkey | ✅ Set | ❌ **Missing** |
| **Result** | ✅ **SUCCESS** | ❌ **FAILURE** |

---

## 7. Next Steps

1. ✅ Fix `db_host` in `config/discourse.conf` → `postgres-community`
2. ✅ Add SSL parameters to `database_config` method in `app/models/global_setting.rb`
3. ✅ Test the connection in the application
4. ✅ Verify all services are healthy

