# SIRA Community Production Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying SIRA Community in a production-grade, secure, and automated manner.

## Prerequisites

- Docker 20.10+ and Docker Compose 2.0+
- Minimum 4GB RAM, 2 CPU cores
- 20GB+ free disk space
- Network access to PostgreSQL and Redis (with mTLS)
- SSL certificates for Nginx

## Quick Start

### Automated Deployment

```bash
cd docker
chmod +x build-and-deploy.sh
./build-and-deploy.sh
```

### Manual Deployment

```bash
cd docker
docker compose -f docker-compose.sira-community.app.yml build
docker compose -f docker-compose.sira-community.app.yml up -d
```

## Architecture

### Services

1. **app**: Main Rails application (Puma server)
2. **sidekiq**: Background job processor
3. **nginx**: Reverse proxy and SSL termination
4. **migrate**: Database migration service (one-time)

### Ports

- **8080**: HTTP (redirects to HTTPS)
- **8443**: HTTPS (production endpoint)

## Configuration

### Environment Variables

Edit `env.community.app.local` or set environment variables:

```bash
# Database
COMMUNITY_DB_HOST=your-db-host
COMMUNITY_DB_PORT=5432
COMMUNITY_DB_NAME=sira_community
COMMUNITY_DB_USER=sira_community_app
COMMUNITY_DB_PASSWORD=your-password

# Redis
COMMUNITY_REDIS_HOST=your-redis-host
COMMUNITY_REDIS_PORT=6380

# Application
COMMUNITY_SECRET_KEY_BASE=your-secret-key
COMMUNITY_HOSTNAME=community.sira.ai

# Ports
COMMUNITY_HTTP_PORT=8080
COMMUNITY_HTTPS_PORT=8443

# Admin Account Auto-Creation (Optional - Idempotent)
# Enable automatic admin account creation/update on startup
ENABLE_AUTO_ADMIN=true
ADMIN_EMAIL=admin@sira.ai
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password-here
# Or use COMMUNITY_ prefixed versions:
# COMMUNITY_ADMIN_EMAIL=admin@sira.ai
# COMMUNITY_ADMIN_USERNAME=admin
# COMMUNITY_ADMIN_PASSWORD=your-secure-password-here
```

### SSL Certificates

Place SSL certificates in:
- `/opt/sira-ai/ssl/nginx/nginx-server.crt`
- `/opt/sira-ai/ssl/nginx/nginx-server.key`

Or mount them via docker-compose volumes.

## Build Process

### Dockerfile Optimizations

1. **Layer Caching**: Dependencies installed before application code
2. **Multi-stage Build**: Separate build and runtime stages
3. **Asset Precompilation**: Assets compiled during build
4. **Security**: Non-root user, minimal image, build tools removed

### Asset Processor Build

The asset processor (`tmp/asset-processor.js`) is built during Docker build:

1. Dependencies installed: `pnpm install` in `frontend/asset-processor/`
2. Asset processor built: `rake assets:precompile:asset_processor`
3. Verification: Build fails if asset processor not created
4. Fallback: Entrypoint script attempts runtime build if missing

## Deployment Workflow

### 1. Pre-Deployment Checks

```bash
# Verify Docker
docker --version
docker compose version

# Check disk space
df -h

# Verify configuration
cat docker/env.community.app.local
```

### 2. Build Image

```bash
# With BuildKit (recommended)
DOCKER_BUILDKIT=1 docker compose -f docker/docker-compose.sira-community.app.yml build

# Or use automated script
./docker/build-and-deploy.sh
```

### 3. Deploy Services

```bash
# Start all services
docker compose -f docker/docker-compose.sira-community.app.yml up -d

# Check status
docker compose -f docker/docker-compose.sira-community.app.yml ps
```

### 4. Verify Deployment

```bash
# Check health
curl http://localhost:8080/srv/status

# Check logs
docker compose -f docker/docker-compose.sira-community.app.yml logs -f
```

## Monitoring

### Health Checks

- **Application**: `http://localhost:8080/srv/status`
- **Container Health**: Docker health checks every 30s
- **Nginx**: Health check endpoint configured

### Logs

```bash
# All services
docker compose -f docker/docker-compose.sira-community.app.yml logs -f

# Specific service
docker compose -f docker/docker-compose.sira-community.app.yml logs -f app
docker compose -f docker/docker-compose.sira-community.app.yml logs -f nginx
```

### Metrics

- Container resource usage: `docker stats`
- Application metrics: Discourse admin panel
- Nginx access logs: `/var/log/nginx/access.log`

## Maintenance

### Updates

```bash
# Pull latest code
git pull

# Rebuild and redeploy
./docker/build-and-deploy.sh --rebuild
```

### Database Migrations

```bash
# Run migrations
docker compose -f docker/docker-compose.sira-community.app.yml run --rm migrate
```

### Admin Account Management

#### Automatic Creation (Recommended - Idempotent)

Admin account can be automatically created/updated during deployment:

1. **Enable in environment variables:**
   ```bash
   ENABLE_AUTO_ADMIN=true
   ADMIN_EMAIL=admin@sira.ai
   ADMIN_USERNAME=admin
   ADMIN_PASSWORD=your-secure-password
   ```

2. **Deploy** - Admin account will be created/updated automatically on app startup

3. **Idempotent** - Safe to run multiple times, won't create duplicates

#### Manual Creation

```bash
# Create or update admin account (idempotent)
docker exec sira-community-app bundle exec rake admin:create

# With custom credentials
docker exec sira-community-app bundle exec rake admin:create ADMIN_EMAIL=admin@example.com ADMIN_USERNAME=admin ADMIN_PASSWORD=secure-password

# List all admin users
docker exec sira-community-app bundle exec rake admin:list

# Remove admin privileges
docker exec sira-community-app bundle exec rake admin:remove[username]
```

#### Notes

- **Idempotent**: The `admin:create` task is idempotent - safe to run multiple times
- **One-Time Setup**: Admin account creation is typically a one-time setup step
- **Optional**: Set `ENABLE_AUTO_ADMIN=false` to disable automatic creation
- **Security**: Always set `ADMIN_PASSWORD` in production (don't rely on auto-generated passwords)

### Backup

```bash
# Backup database (example)
docker exec sira-community-db pg_dump -U sira_community > backup.sql

# Backup uploads
docker exec sira-community-app tar -czf /tmp/uploads-backup.tar.gz /var/www/community/public/uploads
```

## Troubleshooting

### Common Issues

1. **Asset Processor Missing**
   - Symptom: 500 errors on page load
   - Solution: Rebuild image or check build logs

2. **Certificate Errors**
   - Symptom: Connection refused to database/Redis
   - Solution: Verify certificates are mounted correctly

3. **Port Conflicts**
   - Symptom: Container won't start
   - Solution: Change ports in `env.community.app.local`

4. **Memory Issues**
   - Symptom: Container killed
   - Solution: Increase memory limits or reduce workers

### Debug Commands

```bash
# Enter container
docker exec -it sira-community-app bash

# Check asset processor
ls -lh /var/www/community/tmp/asset-processor.js

# Test database connection
docker exec sira-community-app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"

# Test Redis connection
docker exec sira-community-app bundle exec rails runner "puts Discourse.redis.ping"
```

## Security

See [SECURITY.md](./SECURITY.md) for detailed security configuration.

### Key Security Features

- Non-root user execution
- mTLS for all connections
- Strong SSL/TLS configuration
- Resource limits
- Health checks
- Comprehensive logging

## Performance Optimization

### Current Optimizations

1. **YJIT Enabled**: Ruby JIT compiler for better performance
2. **Connection Pooling**: Database pool size optimized (40 connections)
3. **Thread Optimization**: Puma threads reduced to 8-12
4. **Resource Limits**: CPU and memory limits configured
5. **Asset Precompilation**: Assets compiled at build time
6. **Log Level**: Reduced to `warn` for production

### Further Optimizations

1. **CDN**: Use CDN for static assets
2. **Caching**: Implement Redis caching layer
3. **Load Balancing**: Multiple app instances behind load balancer
4. **Database Optimization**: Connection pooling, read replicas
5. **Monitoring**: APM tools (New Relic, Datadog)

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy SIRA Community

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and Deploy
        run: |
          cd docker
          ./build-and-deploy.sh
```

## Support

For issues or questions:
1. Check logs: `docker compose logs`
2. Review documentation
3. Check GitHub issues
4. Contact infrastructure team

