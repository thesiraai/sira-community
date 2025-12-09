# Environment Configuration Guide

SIRA Community includes environment-specific configuration files for different deployment scenarios. All environments maintain production-grade quality and standards.

## Available Environment Files

- `env.community.app.local` - Local PC development
- `env.community.app.dev` - Development server
- `env.community.app.test` - Test/QA server
- `env.community.app.stage` - Staging/pre-production server
- `env.community.app.prod` - Production server

## Usage

### Local Development

```bash
# Copy local environment file
cp docker/env.community.app.local .env

# Build and start
docker-compose build
docker-compose up -d
```

### Server Deployments

For server deployments, copy the appropriate environment file:

```bash
# Development server
cp docker/env.community.app.dev .env

# Test server
cp docker/env.community.app.test .env

# Staging server
cp docker/env.community.app.stage .env

# Production server
cp docker/env.community.app.prod .env
```

## Environment-Specific Configurations

### Local (env.community.app.local)
- **Purpose**: Local PC development
- **Hostname**: localhost
- **Ports**: 8080 (HTTP), 8443 (HTTPS), 3000 (App)
- **Database**: community_local
- **Redis**: No password (local only)
- **Email**: MailHog (local testing)
- **Logging**: Debug level
- **Workers**: 2 (minimal resources)

### Development (env.community.app.dev)
- **Purpose**: Development server deployment
- **Hostname**: community-dev.sira.ai
- **Ports**: 80 (HTTP), 443 (HTTPS), 3000 (App)
- **Database**: community_dev
- **Redis**: DB 1, password protected
- **Email**: SendGrid (development API key)
- **Logging**: Info level
- **Workers**: 4
- **Network**: External (connects to sira-network)

### Test (env.community.app.test)
- **Purpose**: Testing/QA server deployment
- **Hostname**: community-test.sira.ai
- **Ports**: 80 (HTTP), 443 (HTTPS), 3000 (App)
- **Database**: community_test
- **Redis**: DB 2, password protected
- **Email**: SendGrid (test API key)
- **Logging**: Info level
- **Workers**: 4
- **Network**: External (connects to sira-network)

### Staging (env.community.app.stage)
- **Purpose**: Pre-production/staging server
- **Hostname**: community-staging.sira.ai
- **Ports**: 80 (HTTP), 443 (HTTPS), 3000 (App)
- **Database**: community_staging
- **Redis**: DB 3, password protected
- **Email**: SendGrid (staging API key)
- **Logging**: Info level
- **Workers**: 6 (production-like)
- **Network**: External (connects to sira-network)

### Production (env.community.app.prod)
- **Purpose**: Production server
- **Hostname**: community.sira.ai
- **Ports**: 80 (HTTP), 443 (HTTPS), 3000 (App)
- **Database**: community_prod
- **Redis**: DB 0, password protected
- **Email**: SendGrid (production API key)
- **Logging**: Warn level (minimal logging)
- **Workers**: 8 (high performance)
- **Network**: External (connects to sira-network)
- **Security**: All security features enabled

## Security Considerations

### Password Requirements

All server environments require strong passwords:

- **Minimum 32 characters**
- **Mix of uppercase, lowercase, numbers, special characters**
- **Unique for each environment**
- **Stored securely (use secrets management)**

### Secret Key Base

The `COMMUNITY_SECRET_KEY_BASE` must be:

- **128-character hex string** (64 bytes in hex)
- **Unique for each environment**
- **Never shared or committed to version control**
- **Generated using**: `ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"`

### API Keys

- **SIRA_API_KEY**: Unique per environment
- **SMTP Password**: Use actual SendGrid API keys
- **Never use production keys in non-production environments**

## Required Actions Before Deployment

### For All Server Environments (dev, test, stage, prod)

1. **Generate Secret Key Base**
   ```bash
   ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
   ```
   Replace `COMMUNITY_SECRET_KEY_BASE` in the environment file.

2. **Set Strong Database Password**
   - Minimum 32 characters
   - Use password manager or secrets management
   - Replace `COMMUNITY_DB_PASSWORD`

3. **Set Strong Redis Password**
   - Minimum 32 characters
   - Replace `COMMUNITY_REDIS_PASSWORD`

4. **Configure SMTP**
   - Get SendGrid API key
   - Replace `COMMUNITY_SMTP_PASSWORD`
   - Verify `COMMUNITY_SMTP_DOMAIN` matches your domain

5. **Set SIRA API Key**
   - Get API key from SIRA API service
   - Replace `SIRA_API_KEY`
   - Verify `SIRA_API_URL` is correct

6. **Configure Hostname**
   - Update `COMMUNITY_HOSTNAME` to match your domain
   - Ensure DNS is configured
   - Set up SSL certificates

### Production-Specific Requirements

1. **Generate Production Secret Key**
   - Must be unique and never used elsewhere
   - Store in secure secrets management system

2. **Use Production-Grade Passwords**
   - Database: 40+ character password
   - Redis: 40+ character password
   - All passwords must be cryptographically random

3. **Configure Production SMTP**
   - Use production SendGrid account
   - Verify SPF/DKIM records
   - Test email delivery

4. **Set Up SSL Certificates**
   - Use Let's Encrypt or CA certificates
   - Place in `docker/nginx/ssl/`
   - Ensure certificates are valid and not expired

5. **Enable All Security Features**
   - Rate limiting enabled
   - CSRF protection enabled
   - Security headers enabled
   - HTTPS enforced

## Environment File Management

### Best Practices

1. **Never commit `.env` files** to version control
2. **Use secrets management** for production (AWS Secrets Manager, HashiCorp Vault, etc.)
3. **Rotate credentials regularly** (every 90 days recommended)
4. **Use different credentials** for each environment
5. **Document credential locations** in secure documentation

### Secrets Management Integration

For production, consider using:

```bash
# Example: AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id sira-community-prod | jq -r .SecretString > .env

# Example: HashiCorp Vault
vault kv get -format=json secret/sira-community/prod | jq -r .data.data > .env
```

## Validation

Before deploying, validate your environment file:

```bash
# Check required variables are set
docker-compose config

# Verify no placeholder values remain
grep -i "replace\|placeholder\|change_me" .env
```

## Troubleshooting

### Missing Environment Variables

If you see errors about missing variables:
1. Check `.env` file exists
2. Verify all required variables are set
3. Check for typos in variable names

### Invalid Configuration

If services fail to start:
1. Check logs: `docker-compose logs`
2. Verify database connection
3. Verify Redis connection
4. Check secret key format (must be 128 hex chars)

### Security Warnings

If you see security warnings:
1. Ensure all passwords are strong
2. Verify secret key is properly generated
3. Check SSL certificates are valid
4. Review security settings

## Environment Comparison

| Feature | Local | Dev | Test | Stage | Prod |
|--------|-------|-----|------|-------|------|
| Hostname | localhost | *.dev | *.test | *.staging | *.sira.ai |
| Log Level | debug | info | info | info | warn |
| Workers | 2 | 4 | 4 | 6 | 8 |
| Sidekiq | 2 | 5 | 5 | 8 | 10 |
| DB Pool | 5 | 8 | 8 | 10 | 15 |
| Redis DB | 0 | 1 | 2 | 3 | 0 |
| Email | MailHog | SendGrid | SendGrid | SendGrid | SendGrid |
| Network | Internal | External | External | External | External |
| Security | Basic | Standard | Standard | Enhanced | Maximum |

## Support

For issues with environment configuration:
1. Check this guide
2. Review `docker/README.md`
3. Check service logs
4. Verify all required variables are set



