# POC vs Application Code Comparison

## Summary

The POC test **succeeded** and identified the exact Redis TLS configuration that works. The current application code is **missing critical TLS parameters**.

---

## 1. POC Working Configuration ✅

**Location:** `/tmp/redis_poc_test.rb` (tested and verified)

```ruby
config = {
  host: "redis",
  port: 6380,
  password: "redis_password",
  db: 0,
  ssl: true,                                    # ← Enables TLS
  ssl_params: {                                 # ← CRITICAL: This is missing in app!
    cert: OpenSSL::X509::Certificate.new(       # ← Client certificate (OpenSSL object)
      File.read(cert_path)
    ),
    key: OpenSSL::PKey::RSA.new(                # ← Client key (OpenSSL object)
      File.read(key_path)
    ),
    ca_file: ca_path,                           # ← CA cert file path (String)
    verify_mode: OpenSSL::SSL::VERIFY_PEER      # ← Verify server certificate
  }
}
```

**Result:** ✅ **SUCCESS** - Connection established, received `PONG` response

---

## 2. Current Application Code ❌

**Location:** `app/models/global_setting.rb` (lines 210-234)

```ruby
def self.redis_config
  @config ||=
    begin
      c = {}
      c[:host] = redis_host if redis_host
      c[:port] = redis_port if redis_port
      # ... other config ...
      c[:ssl] = true if redis_use_ssl           # ← Only sets ssl: true
      # ❌ NO ssl_params at all!
      c.freeze
    end
end
```

**What's Missing:**
- ❌ No `ssl_params` hash
- ❌ No client certificate (`cert`)
- ❌ No client key (`key`)
- ❌ No CA file (`ca_file`)
- ❌ No verify mode (`verify_mode`)

**Result:** ❌ **FAILURE** - Error: `certificate verify failed (self-signed certificate in certificate chain)`

---

## 3. Configuration Available in discourse.conf

**Location:** `config/discourse.conf` (lines 65-71)

```ini
redis_ssl = true
redis_use_ssl = true
redis_ssl_cert = /opt/sira-ai/ssl/redis/sira-community-redis-client.crt
redis_ssl_key = /opt/sira-ai/ssl/redis/sira-community-redis-client.key
redis_ssl_ca = /opt/sira-ai/ssl/ca/ca.crt
```

**Status:** ✅ Certificate paths are configured, but **not used** by `GlobalSetting.redis_config`

---

## 4. Why the Application Fails

### Root Cause
The infrastructure Redis server (port 6380) requires:
1. **TLS enabled** (`ssl: true`) ✅ - Application has this
2. **Client certificates** (mTLS) ❌ - Application missing this
3. **CA certificate** for server verification ❌ - Application missing this

### What Happens
1. Application sets `ssl: true` → TLS handshake starts
2. Server requests client certificate → Application has none to send
3. Server sends its certificate → Application can't verify it (no CA)
4. **Result:** `certificate verify failed` error

### What the POC Does Differently
1. Sets `ssl: true` → TLS handshake starts
2. Provides `ssl_params` with client cert/key → Server accepts connection
3. Provides `ca_file` → Application verifies server certificate
4. **Result:** Connection successful ✅

---

## 5. Key Differences Summary

| Aspect | POC (Working) | Application (Failing) |
|--------|---------------|----------------------|
| `ssl: true` | ✅ Yes | ✅ Yes |
| `ssl_params` | ✅ **Present** | ❌ **Missing** |
| Client cert | ✅ OpenSSL object | ❌ None |
| Client key | ✅ OpenSSL object | ❌ None |
| CA file | ✅ String path | ❌ None |
| Verify mode | ✅ VERIFY_PEER | ❌ None |
| **Result** | ✅ **SUCCESS** | ❌ **FAILURE** |

---

## 6. The Fix Required

To fix the application, `GlobalSetting.redis_config` must be modified to:

1. **Check if TLS is enabled** (`redis_use_ssl` or `redis_ssl`)
2. **Read certificate paths** from `discourse.conf` or environment variables
3. **Add `ssl_params` hash** with:
   - `cert`: OpenSSL::X509::Certificate object
   - `key`: OpenSSL::PKey::RSA object
   - `ca_file`: String path to CA certificate
   - `verify_mode`: OpenSSL::SSL::VERIFY_PEER
4. **Add ssl_params BEFORE** the config is frozen

**Important:** The config is memoized (`@config ||=`), so the fix must:
- Either modify the method to include ssl_params in the initial creation
- Or patch the method and reset the memoized value

---

## 7. Why This Matters

The infrastructure Redis server **requires mutual TLS (mTLS)**:
- Server verifies client identity using client certificate
- Client verifies server identity using CA certificate
- Without both, the connection fails

The current application code only enables TLS but doesn't provide the certificates needed for mTLS, which is why it fails.

