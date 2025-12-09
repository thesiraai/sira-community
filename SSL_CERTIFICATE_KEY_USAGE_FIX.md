# SSL Certificate Key Usage Fix

**Issue**: `ERR_SSL_KEY_USAGE_INCOMPATIBLE`  
**Date**: December 9, 2025

## Root Cause

The nginx server certificate (`nginx-server.crt`) is missing **"Digital Signature"** in the Key Usage extension.

### Current Certificate Key Usage:
- ✅ Key Encipherment
- ✅ Data Encipherment
- ❌ **Digital Signature** (MISSING - Required by modern browsers)

### Required Key Usage for TLS Server Certificates:
- ✅ Digital Signature (REQUIRED)
- ✅ Key Encipherment
- ✅ Data Encipherment (optional for RSA)

## Why This Happens

Modern browsers (Chrome, Edge, Firefox) strictly validate certificate Key Usage extensions. The `ERR_SSL_KEY_USAGE_INCOMPATIBLE` error occurs when:
1. The certificate is used for a purpose not allowed by its Key Usage extension
2. The certificate is missing "Digital Signature" which is required for TLS server authentication

## Certificate Details

**Current Certificate:**
- Subject: `CN=local.community.sira.ai`
- Extended Key Usage: ✅ `TLS Web Server Authentication` (correct)
- Key Usage: ❌ Missing `Digital Signature` (incorrect)
- Subject Alternative Name: `DNS:local.community.sira.ai, DNS:localhost, DNS:community-nginx`

## Solutions

### Option 1: Regenerate Certificate (Recommended)

The certificate needs to be regenerated with proper Key Usage including "Digital Signature".

**Certificate Generation Requirements:**
```bash
# Key Usage must include:
- Digital Signature
- Key Encipherment
- Data Encipherment (optional)

# Extended Key Usage must include:
- TLS Web Server Authentication (1.3.6.1.5.5.7.3.1)
```

**Certificate Generation Command (example):**
```bash
openssl x509 -req -in nginx-server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out nginx-server.crt -days 365 \
  -extensions v3_server \
  -extfile <(echo "[v3_server]
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = local.community.sira.ai
DNS.2 = localhost
DNS.3 = community-nginx
DNS.4 = community.sira.ai")
```

### Option 2: Accept Browser Warning (Temporary - Local Testing Only)

For local testing, you can:
1. Click "Advanced" in the browser error page
2. Click "Proceed to localhost (unsafe)"
3. The connection will work, but you'll see a warning each time

**⚠️ WARNING**: This is NOT secure for production. The certificate must be fixed.

### Option 3: Use Different Certificate

If you have another certificate with proper Key Usage, you can:
1. Replace `nginx-server.crt` and `nginx-server.key` in the `server/nginx-community/` directory
2. Ensure the new certificate has "Digital Signature" in Key Usage
3. Restart nginx

## Current Workaround Applied

I've disabled SSL stapling in nginx configuration, which may help with some compatibility issues, but **the certificate still needs to be regenerated** with proper Key Usage.

## Verification

After regenerating the certificate, verify it has proper Key Usage:

```bash
# Using Docker with openssl
docker run --rm -v "C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca\server\nginx-community:/certs" alpine/openssl x509 -in /certs/nginx-server.crt -text -noout | grep -A 2 "Key Usage"

# Should show:
# X509v3 Key Usage:
#     Digital Signature, Key Encipherment, Data Encipherment
```

## Next Steps

1. **Contact Infrastructure Team** or use certificate generation scripts to regenerate `nginx-server.crt` with proper Key Usage
2. **Replace the certificate** in `C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca\server\nginx-community\`
3. **Restart nginx**: `docker-compose -f docker/docker-compose.sira-community.app.yml up -d --force-recreate nginx`
4. **Test**: Access `https://localhost:8443` - the error should be gone

## Files Modified

- `docker/nginx/nginx.conf` - Disabled SSL stapling (temporary workaround)

## References

- [RFC 5280 - Key Usage Extension](https://tools.ietf.org/html/rfc5280#section-4.2.1.3)
- [Chrome Certificate Requirements](https://chromium.googlesource.com/chromium/src/+/master/net/cert/x509_certificate.cc)
- [OpenSSL Certificate Generation](https://www.openssl.org/docs/man1.1.1/man1/x509.html)

