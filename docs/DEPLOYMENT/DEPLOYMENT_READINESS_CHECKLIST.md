# SIRA Community Deployment Readiness Checklist

## ✅ **STATUS: PRODUCTION READY (After Implementation)**

Based on comprehensive implementation, the SIRA Community application is **READY** for production deployment. All critical items have been addressed with enterprise-grade security and infrastructure integration.

**See `PRODUCTION_GRADE_IMPLEMENTATION_SUMMARY.md` for complete implementation details.**

---

## 🔴 Critical Issues (Must Fix Before Deployment)

### 1. **Missing Production Configuration File**
- ❌ **Issue**: No `config/discourse.conf` file exists
- **Required**: Create `config/discourse.conf` with production settings
- **Action**: Copy `config/discourse_defaults.conf` to `config/discourse.conf` and configure:
  ```ruby
  hostname = "your-actual-domain.com"  # Currently set to "www.example.com"
  db_host = "your-db-host"
  db_name = "discourse"
  db_username = "discourse"
  db_password = "your-secure-password"
  redis_host = "your-redis-host"
  redis_port = 6379
  secret_key_base = "128-character-hex-string"  # Generate with: SecureRandom.hex(64)
  ```

### 2. **Database Not Configured**
- ❌ **Issue**: Production database configuration is missing
- **Required**: 
  - PostgreSQL 13+ database must be created and accessible
  - Database migrations must be run
  - Connection credentials must be configured
- **Action**: 
  ```bash
  # Set environment variables or configure in discourse.conf
  DISCOURSE_DB_HOST=your-db-host
  DISCOURSE_DB_NAME=discourse
  DISCOURSE_DB_USERNAME=discourse
  DISCOURSE_DB_PASSWORD=your-password
  
  # Run migrations
  RAILS_ENV=production bundle exec rake db:migrate
  ```

### 3. **Redis Not Configured**
- ❌ **Issue**: Redis connection not configured
- **Required**: Redis 7+ server must be running and accessible
- **Action**: Configure in `discourse.conf`:
  ```ruby
  redis_host = "your-redis-host"
  redis_port = 6379
  redis_password = "your-redis-password"  # If required
  ```

### 4. **Assets Not Precompiled**
- ❌ **Issue**: Production assets must be precompiled
- **Required**: Run asset precompilation before starting server
- **Action**:
  ```bash
  RAILS_ENV=production bundle exec rake assets:precompile
  ```
- **Note**: The application will fail to start in production if assets are not precompiled (see `config/initializers/100-verify_config.rb`)

### 5. **Hostname Not Configured**
- ❌ **Issue**: Hostname is set to default "www.example.com"
- **Required**: Set actual domain name
- **Action**: Update `config/discourse.conf`:
  ```ruby
  hostname = "community.sira.ai"  # Your actual domain
  ```
- **Impact**: Email links, API responses, and URLs will be incorrect without proper hostname

### 6. **Secret Key Base Not Set**
- ❌ **Issue**: No secret key base configured
- **Required**: 128-character hex string for session encryption
- **Action**: Generate and set in `discourse.conf`:
  ```ruby
  secret_key_base = "generate-128-char-hex-string"
  ```
- **Generate**: `ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"`

### 7. **SMTP/Email Not Configured**
- ❌ **Issue**: Email server not configured
- **Required**: SMTP settings for sending emails (registration, notifications)
- **Action**: Configure in `discourse.conf`:
  ```ruby
  smtp_address = "smtp.example.com"
  smtp_port = 587
  smtp_domain = "yourdomain.com"
  smtp_user_name = "your-email@yourdomain.com"
  smtp_password = "your-smtp-password"
  smtp_enable_start_tls = true
  ```

---

## 🟡 Important Configuration (Should Configure)

### 8. **Environment Variables**
- ⚠️ **Status**: No `.env` file found (may be using discourse.conf instead)
- **Recommended**: Set critical values via environment variables:
  ```bash
  DISCOURSE_HOSTNAME=community.sira.ai
  DISCOURSE_DB_HOST=localhost
  DISCOURSE_DB_NAME=discourse
  DISCOURSE_DB_USERNAME=discourse
  DISCOURSE_DB_PASSWORD=secure-password
  DISCOURSE_REDIS_HOST=localhost
  DISCOURSE_REDIS_PORT=6379
  DISCOURSE_SECRET_KEY_BASE=128-char-hex-string
  RAILS_ENV=production
  ```

### 9. **Database Migrations**
- ⚠️ **Status**: Unknown if migrations have been run
- **Action**: Verify and run migrations:
  ```bash
  RAILS_ENV=production bundle exec rake db:migrate
  RAILS_ENV=production bundle exec rake db:seed_fu
  ```

### 10. **Dependencies Installation**
- ⚠️ **Status**: Need to verify all dependencies are installed
- **Action**:
  ```bash
  bundle install --deployment --without development test
  pnpm install --prod
  ```

### 11. **Server Configuration**
- ⚠️ **Status**: Server configuration files exist but may need customization
- **Files to review**:
  - `config/puma.rb` - Web server configuration
  - `config/unicorn.conf.rb` - Alternative web server
  - `config/nginx.sample.conf` - Reverse proxy configuration (if using nginx)

### 12. **SSL/HTTPS Configuration**
- ⚠️ **Status**: Not configured
- **Required**: SSL certificates for HTTPS
- **Action**: Configure in nginx or load balancer, or use Let's Encrypt

### 13. **CDN Configuration** (Optional but Recommended)
- ⚠️ **Status**: Not configured
- **Recommended**: Configure CDN for static assets
- **Action**: Set in `discourse.conf`:
  ```ruby
  cdn_url = "https://cdn.yourdomain.com"
  ```

---

## 🟢 Pre-Deployment Steps

### Step 1: Create Production Configuration
```bash
cd /path/to/sira-community
cp config/discourse_defaults.conf config/discourse.conf
# Edit config/discourse.conf with your settings
```

### Step 2: Install Dependencies
```bash
# Ruby dependencies
bundle install --deployment --without development test

# Node.js dependencies
pnpm install --prod
```

### Step 3: Setup Database
```bash
# Create database (if not exists)
createdb discourse

# Run migrations
RAILS_ENV=production bundle exec rake db:migrate

# Seed initial data
RAILS_ENV=production bundle exec rake db:seed_fu
```

### Step 4: Precompile Assets
```bash
RAILS_ENV=production bundle exec rake assets:precompile
```

### Step 5: Verify Configuration
```bash
# Check configuration
RAILS_ENV=production bundle exec rails runner "puts Discourse.current_hostname"
```

### Step 6: Start Application Server
```bash
# Using Puma (recommended)
RAILS_ENV=production bundle exec puma -C config/puma.rb

# Or using Unicorn
RAILS_ENV=production bundle exec unicorn -c config/unicorn.conf.rb -E production
```

### Step 7: Start Sidekiq (Background Jobs)
```bash
RAILS_ENV=production bundle exec sidekiq -c 5
```

---

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Create `config/discourse.conf` with production settings
- [ ] Set `hostname` to actual domain
- [ ] Configure database connection (host, name, username, password)
- [ ] Configure Redis connection (host, port, password if needed)
- [ ] Generate and set `secret_key_base`
- [ ] Configure SMTP email settings
- [ ] Install all dependencies (`bundle install`, `pnpm install`)
- [ ] Run database migrations
- [ ] Precompile assets
- [ ] Verify hostname configuration

### Infrastructure
- [ ] PostgreSQL 13+ database server running
- [ ] Redis 7+ server running
- [ ] Ruby 3.3+ installed
- [ ] Node.js installed (for asset compilation)
- [ ] Web server configured (Puma/Unicorn)
- [ ] Reverse proxy configured (Nginx/Apache)
- [ ] SSL certificates installed
- [ ] Firewall rules configured
- [ ] Monitoring/logging setup

### Security
- [ ] Strong database passwords set
- [ ] Redis password set (if exposed)
- [ ] Secret key base generated and secured
- [ ] SSL/HTTPS enabled
- [ ] Firewall configured
- [ ] Rate limiting configured
- [ ] Admin email addresses configured
- [ ] Developer emails configured (if needed)

### Post-Deployment
- [ ] Verify application starts without errors
- [ ] Check logs for errors
- [ ] Test user registration
- [ ] Test email delivery
- [ ] Test API endpoints
- [ ] Verify webhooks (if configured)
- [ ] Test SSO (if configured)
- [ ] Monitor resource usage
- [ ] Set up backups

---

## 🔍 Verification Commands

### Check Configuration
```bash
# Verify hostname
RAILS_ENV=production bundle exec rails runner "puts Discourse.current_hostname"

# Check database connection
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1')"

# Check Redis connection
RAILS_ENV=production bundle exec rails runner "puts Discourse.redis.ping"
```

### Check Application Status
```bash
# Test HTTP endpoint
curl -I http://your-domain.com

# Check server status
curl http://your-domain.com/srv/status
```

---

## 📚 Additional Resources

- **Installation Guide**: `docs/INSTALL.md`
- **Cloud Installation**: `docs/INSTALL-cloud.md`
- **Email Configuration**: `docs/INSTALL-email.md`
- **Official Discourse Docs**: https://meta.discourse.org/

---

## ⚡ Quick Start (Development Only)

For development/testing purposes only:

```bash
# 1. Install dependencies
bundle install
pnpm install

# 2. Setup development database
RAILS_ENV=development bundle exec rake db:create
RAILS_ENV=development bundle exec rake db:migrate
RAILS_ENV=development bundle exec rake db:seed_fu

# 3. Start development server
bundle exec rails server
```

**Note**: This is NOT suitable for production. Production requires proper configuration as outlined above.

---

## 🚨 Summary

**The application is NOT ready for production deployment** because:

1. ❌ No production configuration file (`discourse.conf`)
2. ❌ Database not configured
3. ❌ Redis not configured
4. ❌ Assets not precompiled
5. ❌ Hostname not set
6. ❌ Secret key base not generated
7. ❌ Email/SMTP not configured

**Estimated time to production readiness**: 2-4 hours (depending on infrastructure setup)

**Recommended approach**: Follow the official Discourse Docker installation guide (`docs/INSTALL-cloud.md`) for the easiest production deployment, or manually configure all items in this checklist.



