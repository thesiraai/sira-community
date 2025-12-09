# PostgreSQL Connection POC

This POC tests different PostgreSQL connection configurations to identify the exact setup required for the SIRA Community application to connect to the `postgres-community` service.

## Purpose

Similar to the Redis TLS POC, this isolates the PostgreSQL connection issue before applying fixes to the main application code.

## Configuration

Based on infrastructure team guidance:
- **Host**: `postgres-community` (service name, NOT `sira_community_postgres` or `localhost`)
- **Port**: `5432` (internal port, NOT `5433`)
- **Database**: `sira_community`
- **Username**: `sira_community_user`
- **Password**: `community_app_password_2025`
- **SSL Mode**: `require` (mTLS with client certificates)
- **Certificates**: `/opt/sira-ai/ssl/postgres-community/`

## Running the POC

```bash
# Copy POC to container
docker cp temp/postgres-connection-poc sira-community-app:/var/www/community/temp/

# Run the POC
docker exec -it sira-community-app bash -c "cd /var/www/community/temp/postgres-connection-poc && bundle exec ruby test_postgres_connection.rb"
```

## Tests Performed

1. **Basic connection (no SSL)** - Baseline test
2. **sslmode=require (no client certs)** - Server-side SSL only
3. **sslmode=require + CA cert** - Server verification
4. **mTLS with client certificates** - Full mutual TLS (expected working config)
5. **sslmode=verify-full + mTLS** - Strictest verification
6. **Connection string with mTLS** - Alternative format

## Expected Result

Test 4 or 5 should succeed, confirming that:
- The service name `postgres-community` resolves correctly
- Client certificates are properly mounted and readable
- The `pg` gem correctly handles mTLS with client certificates

## Next Steps

Once the working configuration is identified:
1. Update `config/discourse.conf` if needed
2. Update `app/models/global_setting.rb` or database connection code
3. Verify the fix works in the application

