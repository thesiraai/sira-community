# Redis TLS Connection POC

This POC tests Redis TLS connections using the same certificates and configuration as the SIRA Community application.

## Purpose

Isolate and identify the root cause of the "certificate verify failed" error when connecting to Redis with TLS and client certificates.

## Setup

1. Run inside the application container where certificates are mounted:
   ```bash
   docker exec -it sira-community-app bash
   ```

2. Navigate to the POC directory:
   ```bash
   cd /var/www/community/temp/redis-tls-poc
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Run the test:
   ```bash
   ruby test_redis_tls.rb
   ```

## Tests

The POC runs 5 different connection configurations:

1. **Basic ssl: true** - Just enables SSL without certificates
2. **ssl_params with OpenSSL objects** - Client cert and key as OpenSSL objects
3. **ssl_params + ca_file** - Adds CA file path for server verification
4. **ssl_params + ca_cert** - Adds CA as OpenSSL object
5. **rediss:// URL** - Uses Redis URL format with ssl_params

## Expected Outcome

One of these tests should succeed, identifying the correct configuration format for the redis-rb gem with TLS and client certificates.

