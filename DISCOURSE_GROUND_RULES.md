# SIRA Community - Discourse Ground Rules

## 🏗️ Architecture Rules
- **Use official Discourse Docker image** - `discourse/discourse:latest` (no local builds)
- **Nginx reverse proxy for HTTPS termination** - All external traffic through nginx, Discourse internal only
- **Custom plugins mounted as volumes** - Plugins in `plugins/` directory mounted into container
- **Infrastructure integration** - Connects to existing SIRA infrastructure (postgres-community, redis-community)
- **Network isolation** - Services on `sira_infra_network`, no direct host port exposure for Discourse
- **Single entry point** - All external access via nginx on port 8443 (HTTPS)

## 🔒 Security Rules
- **Environment variables for all secrets** - No hardcoded credentials
- **SSL/TLS termination at nginx** - HTTPS on port 8443, Discourse receives HTTP internally
- **PostgreSQL SSL required** - `DISCOURSE_DB_SSL_MODE=require` for encrypted database connections
- **Redis password authentication** - Password-protected Redis connections
- **Self-signed certificates for local** - CA-signed certificates in `docker/nginx/ssl/`
- **Certificate validation** - Import CA certificate into Windows Certificate Store for browser trust
- **Security headers** - HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection via nginx
- **No shortcuts in production** - All configuration must be config-driven, no manual database changes

## 💻 Configuration Rules

### Hostname and Port Configuration
- **CRITICAL: `DISCOURSE_HOSTNAME` must NOT include port** - Discourse does not accept ports in hostname (e.g., use `local.community.sira.ai`, NOT `local.community.sira.ai:8443`)
- **Port handled separately** - Use `DISCOURSE_PORT=8443` to tell Discourse the external port
- **Nginx headers must include port** - `Host`, `X-Forwarded-Host`, and `X-Forwarded-Port` headers must include `:8443` so Discourse generates correct URLs
- **Hostname enforcement** - `DISCOURSE_FORCE_HTTPS=1` enforces HTTPS at application level
- **Nginx proxy headers** - Must set `Host: local.community.sira.ai:8443`, `X-Forwarded-Host: local.community.sira.ai:8443`, `X-Forwarded-Port: 8443`

### Environment Variable Management
- **CRITICAL: `env_file` takes precedence over `environment` section** - Variables in `env_file` are loaded AFTER `environment` section, so empty fallbacks in `environment` will override `env_file` values
- **Don't override SMTP variables** - SMTP configuration should only be in `env_file`, not in `environment` section with empty fallbacks
- **Use fallbacks for required variables** - Only use fallbacks in `docker-compose.yml` for variables that must have defaults
- **All configuration in env files** - Keep all secrets and configuration in `env.discourse.local` (local) or `env.discourse.prod` (production)

### SMTP Configuration
- **SMTP not auto-enabled from env vars** - Discourse does NOT automatically enable `SiteSetting.enable_smtp` from environment variables
- **Config-driven SMTP initialization** - Use `init-smtp.sh` script to automatically enable SMTP if environment variables are present
- **Notification email must match SMTP sender** - `DISCOURSE_NOTIFICATION_EMAIL` must match `DISCOURSE_SMTP_USER_NAME` (Hostinger requirement)
- **SMTP port selection** - Port 587 with STARTTLS is more compatible than port 465 with SSL for most providers
- **SMTP initialization script** - Mount `init-smtp.sh` at `/etc/runit/1.d/99-init-smtp.sh` to run during container startup
- **Wait for Discourse to be ready** - SMTP initialization script must wait for Rails to be available before setting site settings

### Database Configuration
- **PostgreSQL SSL with password auth** - Use `DISCOURSE_DB_SSL_MODE=require` with password authentication (scram-sha-256)
- **Client certificates not required** - For password authentication, client certificates are not needed
- **Database hostname** - Use service name `postgres-community` (not container name)
- **Connection pool** - Set `DISCOURSE_DB_POOL=8` for optimal performance

### Redis Configuration
- **Non-TLS Redis required** - Official Discourse Docker image does NOT support Redis TLS
- **Redis hostname** - Use service name `redis-community` (not container name)
- **Password authentication** - Set `DISCOURSE_REDIS_PASSWORD` for secure connections

## 🐳 Docker Rules

### Docker Compose Configuration
- **No `version` field** - Remove `version: '3.8'` to avoid deprecation warnings
- **Pull policy** - Use `pull_policy: missing` to only pull images if they don't exist locally
- **Image updates** - Run `docker compose pull` before `docker compose up -d` to update images when needed
- **Container naming** - Use descriptive container names: `sira-discourse`, `sira-discourse-nginx`
- **Network configuration** - Use external network `sira_infra_network` for infrastructure integration
- **Volume mounts** - Mount plugins as read-only (`:ro`) for security
- **Health checks** - Configure health checks with appropriate `start_period` (600s for Discourse migrations)

### Port Configuration
- **No host port for Discourse** - Discourse runs on internal port 3000 only, no host port mapping
- **Nginx external port** - Map nginx internal port 443 to host port 8443 to avoid conflicts
- **Unicorn binding** - Set `UNICORN_BIND_ALL=1` to bind to all interfaces (0.0.0.0) inside container

### Resource Limits
- **CPU limits** - Set `deploy.resources.limits.cpus: "2.0"` for Discourse
- **Memory limits** - Set `deploy.resources.limits.memory: 2g` for Discourse
- **Resource reservations** - Set minimum reservations (CPU: 0.5, Memory: 512m) to ensure availability

### Volume Management
- **Discourse data persistence** - Use named volume `discourse_data` for `/var/www/discourse`
- **Plugin mounting** - Mount custom plugins from `../plugins/` directory
- **SSL certificates** - Mount SSL certificates as read-only (`:ro`)
- **Nginx logs** - Mount nginx logs directory for debugging

## 📚 Plugin Rules
- **Plugin structure** - Plugins must have `plugin.rb`, `plugin.yml`, and `config/settings.yml` (if using site settings)
- **Site settings definition** - Custom site settings must be defined in `config/settings.yml`
- **Plugin mounting** - Mount plugins as volumes, not copied into image
- **Plugin permissions** - Ensure plugin files have correct permissions (readable by discourse user)

## 🚀 Deployment Rules

### Initial Deployment
- **Database migrations run automatically** - Discourse runs migrations on first start
- **Wait for migrations** - Allow 3-5 minutes for initial database setup
- **Health check start period** - Use `start_period: 600s` to allow time for migrations
- **Fresh database wipe** - To start completely fresh, drop PostgreSQL schema and flush Redis database
- **No shortcuts** - All configuration must be done through UI or config files, not manual database changes

### Database Wipe Procedure
- **Stop all containers** - `docker compose -f docker-compose.discourse.yml down`
- **Remove volumes** - `docker volume rm discourse_data` (if needed)
- **Drop PostgreSQL schema** - Connect to postgres and drop `sira_community` schema
- **Flush Redis** - Connect to redis and run `FLUSHDB` or `FLUSHALL`
- **Recreate containers** - `docker compose -f docker-compose.discourse.yml up -d`

### Environment Setup
- **Generate secret keys** - Use `ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"` for `COMMUNITY_SECRET_KEY_BASE`
- **Update CHANGE_ME values** - Check for `CHANGE_ME` placeholders in env files before deployment
- **SSL certificates** - Place `fullchain.pem` and `privkey.pem` in `docker/nginx/ssl/`
- **Hosts file** - Add `127.0.0.1 local.community.sira.ai` to Windows hosts file

## 🔄 Operational Rules

### Startup Sequence
1. **Infrastructure services first** - Ensure postgres-community and redis-community are running
2. **Network verification** - Verify `sira_infra_network` exists
3. **Start Discourse** - `docker compose -f docker-compose.discourse.yml up -d`
4. **Wait for health** - Monitor health checks until container is healthy
5. **Check logs** - Verify no errors in `production.log` and `unicorn.stderr.log`

### Logging and Monitoring
- **Application logs** - Check `/var/www/discourse/log/production.log` for errors
- **Unicorn logs** - Check `/var/www/discourse/log/unicorn.stderr.log` for server errors
- **Nginx logs** - Check `docker/nginx/logs/access.log` and `error.log` for proxy issues
- **Container logs** - Use `docker compose -f docker-compose.discourse.yml logs -f discourse` for real-time logs

### Troubleshooting
- **500 errors during startup** - Usually means migrations are still running, wait 3-5 minutes
- **404 errors on URLs** - Check that `DISCOURSE_PORT` is set and nginx headers include port
- **SMTP not working** - Verify `SiteSetting.enable_smtp` is `true` (not auto-enabled from env vars)
- **Email not received** - Check `notification_email` matches SMTP sender, verify SMTP credentials
- **Database connection errors** - Verify postgres-community is running and credentials are correct
- **Redis connection errors** - Verify redis-community is running and password is correct

## 🧹 Cleanup Rules
- **Remove temporary scripts** - Delete any `.rb` scripts used for troubleshooting after use
- **Clean up logs** - Regularly rotate nginx and application logs
- **Remove unused volumes** - Clean up orphaned volumes after container removal
- **Keep only essential files** - Remove any Discourse source code, build artifacts, or development tooling
- **Plugin files only** - Keep only `plugins/discourse-sira-ai/` directory, not full Discourse source

## 🎯 Production Readiness Rules

### Configuration Validation
- **All env vars set** - No `CHANGE_ME` placeholders in production
- **SSL certificates valid** - Certificates must be valid and trusted
- **SMTP configured** - SMTP must be configured and tested before production use
- **Database SSL enabled** - `DISCOURSE_DB_SSL_MODE=require` for production
- **Health checks passing** - All containers must be healthy before considering deployment ready

### URL Generation
- **Correct port in URLs** - All Discourse-generated URLs must include `:8443` port
- **HTTPS enforcement** - All URLs must use HTTPS protocol
- **Hostname consistency** - All URLs must use `local.community.sira.ai` (not localhost or IP)

### Email Configuration
- **SMTP enabled** - `SiteSetting.enable_smtp` must be `true`
- **Notification email set** - `SiteSetting.notification_email` must match SMTP sender
- **Test email works** - Verify test email sending works before production use
- **Email templates** - Verify email templates include correct URLs with port

## 📋 Common Pitfalls and Solutions

### Pitfall 1: Port Duplication in URLs
- **Problem**: Setting `DISCOURSE_HOSTNAME=local.community.sira.ai:8443` causes port duplication (`https://local.community.sira.ai:8443:8443`)
- **Solution**: Use `DISCOURSE_HOSTNAME=local.community.sira.ai` (no port) and `DISCOURSE_PORT=8443` separately

### Pitfall 2: SMTP Not Enabled Despite Env Vars
- **Problem**: SMTP environment variables are set but `SiteSetting.enable_smtp` is still `false`
- **Solution**: Use `init-smtp.sh` script to automatically enable SMTP from environment variables

### Pitfall 3: Empty Fallbacks Override Env File
- **Problem**: Variables in `environment` section with empty fallbacks override `env_file` values
- **Solution**: Remove SMTP variables from `environment` section, keep them only in `env_file`

### Pitfall 4: Missing Port in Redirect URLs
- **Problem**: Discourse redirects to URLs without `:8443` port
- **Solution**: Ensure nginx sets `Host`, `X-Forwarded-Host`, and `X-Forwarded-Port` headers correctly

### Pitfall 5: Database Migrations Not Complete
- **Problem**: 500 errors immediately after container start
- **Solution**: Wait 3-5 minutes for migrations to complete, check health check `start_period`

### Pitfall 6: Notification Email Mismatch
- **Problem**: Emails rejected because `notification_email` doesn't match SMTP sender
- **Solution**: Set `DISCOURSE_NOTIFICATION_EMAIL` to match `DISCOURSE_SMTP_USER_NAME`

### Pitfall 7: Redis TLS Not Supported
- **Problem**: Trying to use Redis TLS with official Discourse image
- **Solution**: Use non-TLS Redis (`REDIS_TLS=false`) as Discourse image doesn't support TLS

### Pitfall 8: Plugin Site Setting Missing
- **Problem**: `Discourse::SiteSettingMissing` error for custom plugin
- **Solution**: Create `config/settings.yml` in plugin directory to define site settings

## 🔧 Nginx Configuration Rules

### Proxy Headers
- **Host header with port** - `proxy_set_header Host local.community.sira.ai:8443;`
- **X-Forwarded-Host with port** - `proxy_set_header X-Forwarded-Host local.community.sira.ai:8443;`
- **X-Forwarded-Port** - `proxy_set_header X-Forwarded-Port 8443;`
- **X-Forwarded-Proto** - `proxy_set_header X-Forwarded-Proto $scheme;` (should be `https`)

### SSL Configuration
- **Certificate paths** - Use `/etc/nginx/ssl-certs/fullchain.pem` and `privkey.pem`
- **SSL protocols** - Use `TLSv1.2 TLSv1.3` only
- **HTTP/2** - Use `http2 on;` directive (not deprecated `listen ... http2`)

### Redirects
- **HTTP to HTTPS** - Redirect HTTP (port 80) to HTTPS with port: `return 301 https://$server_name:8443$request_uri;`

### Rate Limiting
- **Disable for local** - Comment out rate limiting for local development
- **Enable for production** - Uncomment and configure rate limiting for production

## 📊 Performance Rules
- **Static asset serving** - Enable `DISCOURSE_SERVE_STATIC_ASSETS=1` even behind nginx
- **Unicorn workers** - Set `NUM_WEBS=2` for optimal performance
- **Connection pooling** - Use `DISCOURSE_DB_POOL=8` for database connections
- **Asset caching** - Nginx caches static assets with appropriate `Cache-Control` headers

## 🧪 Testing Rules
- **Health check verification** - Always verify containers are healthy before testing
- **Email testing** - Test email sending via admin panel before production use
- **URL verification** - Verify all generated URLs include correct port and protocol
- **Database connectivity** - Verify database connections work before deployment
- **Redis connectivity** - Verify Redis connections work before deployment

## 👤 User Experience Rules
- **No shortcuts** - All user-facing features must work through UI, no manual database changes
- **Email delivery** - Users must receive verification emails for account creation
- **URL correctness** - All links and redirects must work correctly with proper ports
- **Setup wizard** - Complete setup wizard through UI, not backend changes

## 📝 Documentation Rules
- **Environment variables documented** - All env vars must be documented with examples
- **Deployment procedures** - Document all deployment steps and requirements
- **Troubleshooting guide** - Document common issues and solutions
- **Configuration examples** - Provide example configurations for different environments

## 🔄 Update and Maintenance Rules
- **Image updates** - Use `docker compose pull` to update images when needed
- **Configuration changes** - Update env files, then recreate containers
- **Plugin updates** - Update plugin files, then restart Discourse container
- **Database migrations** - Migrations run automatically on container start
- **Backup before changes** - Always backup database before major changes

## 🎓 Key Learnings

### Discourse-Specific Behaviors
1. **Discourse does NOT accept port in hostname** - Must use `DISCOURSE_HOSTNAME` without port and `DISCOURSE_PORT` separately
2. **SMTP not auto-enabled** - `SiteSetting.enable_smtp` must be set manually or via initialization script
3. **Notification email must match SMTP sender** - Some email providers (like Hostinger) require exact match
4. **Migrations run on first start** - Allow 3-5 minutes for initial database setup
5. **Official image doesn't support Redis TLS** - Must use non-TLS Redis connections

### Configuration Patterns
1. **env_file precedence** - Variables in `env_file` are loaded AFTER `environment` section
2. **Empty fallbacks override** - Empty fallbacks in `environment` section will override `env_file` values
3. **Nginx headers critical** - Headers must include port for correct URL generation
4. **Config-driven initialization** - Use initialization scripts for settings that aren't auto-configured from env vars

### Deployment Best Practices
1. **Full wipe for fresh start** - Drop database schema and flush Redis for completely clean deployment
2. **Wait for migrations** - Always wait for migrations to complete before testing
3. **Health check monitoring** - Use health checks with appropriate `start_period` for long-running initialization
4. **Log verification** - Always check logs after deployment to verify no errors

---
**Status**: ✅ Production-grade Discourse deployment with config-driven initialization
**Last Updated**: December 16, 2025
**Total Rules**: 100+ comprehensive ground rules covering Discourse deployment, configuration, troubleshooting, and best practices

## 📝 Recent Updates (December 16, 2025)

### SMTP Configuration Automation
- Created `init-smtp.sh` script to automatically enable SMTP from environment variables
- Script sets `SiteSetting.enable_smtp` and `SiteSetting.notification_email` based on env vars
- Mounted at `/etc/runit/1.d/99-init-smtp.sh` to run during container initialization
- Fully config-driven: no manual database changes required

### Hostname and Port Configuration
- Fixed port duplication issue by separating `DISCOURSE_HOSTNAME` (no port) and `DISCOURSE_PORT`
- Updated nginx headers to include port in `Host`, `X-Forwarded-Host`, and `X-Forwarded-Port`
- Ensured all Discourse-generated URLs include correct port (`:8443`)

### Environment Variable Management
- Removed SMTP variables from `environment` section to prevent overriding `env_file` values
- Documented `env_file` precedence over `environment` section
- Added `DISCOURSE_NOTIFICATION_EMAIL` to ensure email sender matches SMTP user

### Database and Redis Configuration
- Documented PostgreSQL SSL with password authentication (not client certificates)
- Documented Redis non-TLS requirement (official image limitation)
- Added connection pool and performance configuration

### Deployment Procedures
- Documented full database wipe procedure
- Added migration wait time guidance
- Documented health check configuration with appropriate `start_period`

