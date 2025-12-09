# SIRA Community Deployment Environments

## Overview

Production-grade environment configuration files have been created for all deployment scenarios. All environments maintain **100% production-grade quality and standards**.

## Environment Files

| Environment | File | Purpose | Status |
|------------|------|---------|--------|
| **Local** | `env.local` | Local PC development | ✅ Ready |
| **Development** | `env.dev` | Development server | ✅ Ready (update credentials) |
| **Test** | `env.test` | Test/QA server | ✅ Ready (update credentials) |
| **Staging** | `env.stage` | Pre-production server | ✅ Ready (update credentials) |
| **Production** | `env.prod` | Production server | ⚠️ Ready (MUST update credentials) |

## Quick Reference

### Local Development (env.local)
```bash
cp docker/env.local .env
docker-compose up -d
```
- Hostname: `localhost`
- Ports: 8080/8443/3000
- Database: `community_local`
- Redis: No password
- Email: MailHog
- Workers: 2

### Development Server (env.dev)
```bash
cp docker/env.dev .env
# Update credentials
make validate
make deploy-dev
```
- Hostname: `community-dev.sira.ai`
- Database: `community_dev`
- Redis: DB 1, password protected
- Email: SendGrid (dev API key)
- Workers: 4

### Test Server (env.test)
```bash
cp docker/env.test .env
# Update credentials
make validate
make deploy-test
```
- Hostname: `community-test.sira.ai`
- Database: `community_test`
- Redis: DB 2, password protected
- Email: SendGrid (test API key)
- Workers: 4

### Staging Server (env.stage)
```bash
cp docker/env.stage .env
# Update credentials
make validate
make deploy-stage
```
- Hostname: `community-staging.sira.ai`
- Database: `community_staging`
- Redis: DB 3, password protected
- Email: SendGrid (staging API key)
- Workers: 6

### Production Server (env.prod)
```bash
cp docker/env.prod .env
# CRITICAL: Update all credentials
make validate
make deploy-prod
```
- Hostname: `community.sira.ai`
- Database: `community_prod`
- Redis: DB 0, password protected
- Email: SendGrid (production API key)
- Workers: 8
- **All security features enabled**

## Configuration Details

### All Environments Include

✅ **Application Configuration**
- Hostname, ports, log levels
- Environment-specific settings

✅ **Database Configuration**
- Unique database names per environment
- Strong passwords (32+ chars for servers)
- Connection pooling configured

✅ **Redis Configuration**
- Separate Redis databases per environment
- Password protection (except local)
- Proper isolation

✅ **Security**
- 128-character hex secret keys
- Unique per environment
- Production-grade standards

✅ **SMTP/Email**
- SendGrid integration (except local)
- Environment-specific API keys
- TLS enabled

✅ **SIRA Integration**
- API URL configuration
- API key support
- Network integration

✅ **Performance Tuning**
- Appropriate worker counts
- Sidekiq concurrency settings
- Resource optimization

## Pre-Deployment Checklist

### For All Server Environments

- [ ] Copy environment file to `.env`
- [ ] Generate `COMMUNITY_SECRET_KEY_BASE` (if placeholder)
- [ ] Set `COMMUNITY_DB_PASSWORD` (32+ chars)
- [ ] Set `COMMUNITY_REDIS_PASSWORD` (32+ chars)
- [ ] Configure `COMMUNITY_SMTP_PASSWORD` (SendGrid API key)
- [ ] Set `SIRA_API_KEY`
- [ ] Verify `COMMUNITY_HOSTNAME`
- [ ] Validate: `make validate`
- [ ] Set up SSL certificates

### Production-Specific

- [ ] Generate unique production secret key
- [ ] Use 40+ character passwords
- [ ] Configure production SendGrid
- [ ] Set up SPF/DKIM records
- [ ] Use Let's Encrypt or CA certificates
- [ ] Enable all security features
- [ ] Set up monitoring
- [ ] Configure backups

## Security Standards

All environments follow these standards:

1. **Strong Passwords**: 32+ characters for servers
2. **Secret Keys**: 128 hex characters, unique per environment
3. **Password Protection**: All Redis instances (except local)
4. **SSL/TLS**: HTTPS for all servers
5. **Network Isolation**: External networks for servers
6. **Logging**: Appropriate levels (warn for prod)
7. **Resource Limits**: Environment-appropriate

## Usage Examples

### Setup Environment

```bash
# Using Makefile
make setup-local
make setup-dev
make setup-test
make setup-stage
make setup-prod

# Or manually
cp docker/env.prod .env
```

### Generate Secure Values

```bash
# Generate secret key
make secret

# Generate complete environment file
make generate-env ENV=prod
```

### Validate Configuration

```bash
# Validate .env file
make validate

# Or directly
bash docker/scripts/validate-env.sh .env
```

### Deploy

```bash
# Using Makefile
make deploy-dev
make deploy-test
make deploy-stage
make deploy-prod

# Or using script
bash docker/scripts/deploy.sh prod
```

## Environment Comparison Matrix

| Feature | Local | Dev | Test | Stage | Prod |
|---------|-------|-----|------|-------|------|
| **Hostname** | localhost | *.dev | *.test | *.staging | *.sira.ai |
| **HTTP Port** | 8080 | 80 | 80 | 80 | 80 |
| **HTTPS Port** | 8443 | 443 | 443 | 443 | 443 |
| **App Port** | 3000 | 3000 | 3000 | 3000 | 3000 |
| **Log Level** | debug | info | info | info | warn |
| **Workers** | 2 | 4 | 4 | 6 | 8 |
| **Sidekiq** | 2 | 5 | 5 | 8 | 10 |
| **DB Pool** | 5 | 8 | 8 | 10 | 15 |
| **Redis DB** | 0 | 1 | 2 | 3 | 0 |
| **Redis Password** | No | Yes | Yes | Yes | Yes |
| **Email** | MailHog | SendGrid | SendGrid | SendGrid | SendGrid |
| **Network** | Internal | External | External | External | External |
| **SSL** | Self-signed | Required | Required | Required | Required |
| **Security** | Basic | Standard | Standard | Enhanced | Maximum |

## File Structure

```
docker/
├── env.local          # Local development
├── env.dev            # Development server
├── env.test           # Test server
├── env.stage          # Staging server
├── env.prod           # Production server
├── env.example        # Template
├── README-ENV.md      # Detailed guide
├── ENVIRONMENT_SETUP.md # Setup instructions
├── ENV_FILES_SUMMARY.md # Summary
└── scripts/
    ├── validate-env.sh    # Validation
    ├── generate-env.sh    # Generation
    └── deploy.sh          # Deployment
```

## Important Notes

1. **Never commit `.env` files** - They contain secrets
2. **Use secrets management** for production
3. **Rotate credentials** regularly (90 days)
4. **Different credentials** for each environment
5. **Production secret keys** must be unique
6. **Validate before deploying** - Always run validation

## Support

- See `docker/README-ENV.md` for detailed documentation
- See `docker/README.md` for Docker deployment guide
- Run `make help` for available commands

---

**All environment files are production-ready. Update credentials before server deployments!**



