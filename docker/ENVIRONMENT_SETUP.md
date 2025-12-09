# Environment Files Setup Guide

## Overview

SIRA Community includes production-grade environment configuration files for all deployment scenarios:

- **env.community.app.local** - Local PC development
- **env.community.app.dev** - Development server
- **env.community.app.test** - Test/QA server  
- **env.community.app.stage** - Staging/pre-production server
- **env.community.app.prod** - Production server

All environments maintain **100% production-grade quality and standards**.

## Quick Start

### Local Development

```bash
# Copy local environment
cp docker/env.community.app.local .env

# Or use Makefile
make setup-local

# Build and start
docker-compose build
docker-compose up -d
```

### Server Deployment

```bash
# Development server
make setup-dev
# Edit .env with actual credentials
make deploy-dev

# Test server
make setup-test
# Edit .env with actual credentials
make deploy-test

# Staging server
make setup-stage
# Edit .env with actual credentials
make deploy-stage

# Production server
make setup-prod
# Edit .env with actual credentials
make deploy-prod
```

## Environment Files Summary

### env.community.app.local (Local PC)
- **Hostname**: localhost
- **Ports**: 8080/8443/3000
- **Database**: community_local
- **Redis**: No password (local only)
- **Email**: MailHog
- **Logging**: Debug
- **Resources**: Minimal (2 workers)

### env.community.app.dev (Development Server)
- **Hostname**: community-dev.sira.ai
- **Ports**: 80/443/3000
- **Database**: community_dev
- **Redis**: DB 1, password protected
- **Email**: SendGrid (dev API key)
- **Logging**: Info
- **Resources**: Standard (4 workers)

### env.community.app.test (Test Server)
- **Hostname**: community-test.sira.ai
- **Ports**: 80/443/3000
- **Database**: community_test
- **Redis**: DB 2, password protected
- **Email**: SendGrid (test API key)
- **Logging**: Info
- **Resources**: Standard (4 workers)

### env.community.app.stage (Staging Server)
- **Hostname**: community-staging.sira.ai
- **Ports**: 80/443/3000
- **Database**: community_staging
- **Redis**: DB 3, password protected
- **Email**: SendGrid (staging API key)
- **Logging**: Info
- **Resources**: Enhanced (6 workers)

### env.community.app.prod (Production Server)
- **Hostname**: community.sira.ai
- **Ports**: 80/443/3000
- **Database**: community_prod
- **Redis**: DB 0, password protected
- **Email**: SendGrid (production API key)
- **Logging**: Warn (minimal)
- **Resources**: Maximum (8 workers, 10 sidekiq)

## Pre-Deployment Checklist

### For All Server Environments

- [ ] Copy appropriate environment file to `.env`
- [ ] Generate unique `COMMUNITY_SECRET_KEY_BASE` (128 hex chars)
- [ ] Set strong `COMMUNITY_DB_PASSWORD` (32+ chars)
- [ ] Set strong `COMMUNITY_REDIS_PASSWORD` (32+ chars)
- [ ] Configure `COMMUNITY_SMTP_PASSWORD` (SendGrid API key)
- [ ] Set `SIRA_API_KEY` (SIRA API key)
- [ ] Verify `COMMUNITY_HOSTNAME` matches your domain
- [ ] Validate configuration: `make validate`
- [ ] Set up SSL certificates in `docker/nginx/ssl/`

### Production-Specific

- [ ] Use cryptographically random passwords (40+ chars)
- [ ] Generate production secret key (never reuse)
- [ ] Configure production SendGrid account
- [ ] Set up SPF/DKIM DNS records
- [ ] Use Let's Encrypt or CA SSL certificates
- [ ] Enable all security features
- [ ] Set up monitoring and alerts
- [ ] Configure backups

## Security Standards

All environments follow these security standards:

1. **Strong Passwords**: Minimum 32 characters for servers
2. **Unique Secret Keys**: 128-character hex strings, unique per environment
3. **Password Protection**: All Redis instances password-protected (except local)
4. **SSL/TLS**: HTTPS enabled for all server environments
5. **Network Isolation**: External network for server environments
6. **Logging**: Appropriate log levels (warn for prod, info for others)
7. **Resource Limits**: Appropriate worker counts per environment

## Validation

Validate your environment file before deploying:

```bash
# Validate .env file
make validate

# Or directly
bash docker/scripts/validate-env.sh .env
```

## Generation

Generate environment file with secure random values:

```bash
# Generate for specific environment
make generate-env ENV=prod

# Or directly
bash docker/scripts/generate-env.sh prod
```

## Deployment

Deploy using the deployment script:

```bash
# Deploy to specific environment
make deploy-dev
make deploy-test
make deploy-stage
make deploy-prod

# Or directly
bash docker/scripts/deploy.sh prod
```

## Maintenance

### Update Environment

```bash
# Pull latest code
git pull origin main

# Rebuild
docker-compose build

# Restart
docker-compose restart
```

### Rotate Credentials

```bash
# Generate new secret key
make secret

# Update in .env file
# Restart services
docker-compose restart
```

## Troubleshooting

See `docker/README.md` and `docker/README-ENV.md` for detailed troubleshooting guides.



