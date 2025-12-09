# SIRA Community Docker Deployment

Production-ready Docker setup for SIRA Community, designed to integrate seamlessly with the SIRA AI application ecosystem.

## Quick Start

### 1. Configure Environment

```bash
# Copy example environment file
cp docker/env.community.app.example .env

# Edit .env with your configuration
nano .env
```

**Required Configuration:**
- `COMMUNITY_HOSTNAME` - Your domain name
- `COMMUNITY_DB_PASSWORD` - Secure database password
- `COMMUNITY_SECRET_KEY_BASE` - Generate with: `docker/scripts/generate-secret.sh`
- `COMMUNITY_SMTP_*` - Email server configuration

### 2. Generate Secret Key

```bash
chmod +x docker/scripts/generate-secret.sh
./docker/scripts/generate-secret.sh
```

### 3. Create SSL Certificates (for HTTPS)

```bash
# Create SSL directory
mkdir -p docker/nginx/ssl

# For development, create self-signed certificate:
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/ssl/key.pem \
  -out docker/nginx/ssl/cert.pem \
  -subj "/CN=community.sira.ai"

# For production, use Let's Encrypt or your CA certificates
```

### 4. Build and Start

```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f app
```

### 5. Initialize Database

```bash
# Run migrations
docker-compose exec app bundle exec rake db:migrate

# Seed initial data (optional)
docker-compose exec app bundle exec rake db:seed_fu
```

## Services

- **app** - Main Rails application (port 3000)
- **sidekiq** - Background job processor
- **postgres** - PostgreSQL 13 database
- **redis** - Redis 7 cache
- **nginx** - Reverse proxy with SSL (ports 80, 443)

## Integration with SIRA App

### Network Configuration

The Docker setup uses the `sira-network` network, allowing seamless communication with other SIRA services:

```yaml
# In your SIRA app docker-compose.yml
networks:
  sira-network:
    external: true
```

### Environment Variables

Set these in your SIRA app to connect to community:

```bash
COMMUNITY_URL=https://community.sira.ai
COMMUNITY_API_KEY=your-api-key
COMMUNITY_SSO_SECRET=your-sso-secret
```

### API Integration

The community service exposes a REST API at `/api/` endpoints. See `INTEGRATION_GUIDE.md` for details.

## Production Deployment

### 1. Use Production-Grade SSL

Replace self-signed certificates with Let's Encrypt or your CA:

```bash
# Let's Encrypt example
certbot certonly --standalone -d community.sira.ai
cp /etc/letsencrypt/live/community.sira.ai/fullchain.pem docker/nginx/ssl/cert.pem
cp /etc/letsencrypt/live/community.sira.ai/privkey.pem docker/nginx/ssl/key.pem
```

### 2. Configure Backups

```bash
# Backup script
docker-compose exec app bundle exec rake backups:create
```

### 3. Monitor Logs

```bash
# Application logs
docker-compose logs -f app

# All services
docker-compose logs -f

# Specific service
docker-compose logs -f sidekiq
```

### 4. Health Checks

```bash
# Application health
curl http://localhost/health

# Status endpoint
curl http://localhost/srv/status
```

## Maintenance

### Update Application

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose build
docker-compose up -d

# Run migrations if needed
docker-compose exec app bundle exec rake db:migrate
```

### Backup Database

```bash
# Create backup
docker-compose exec postgres pg_dump -U community community > backup_$(date +%Y%m%d).sql

# Restore backup
docker-compose exec -T postgres psql -U community community < backup_20240101.sql
```

### Scale Services

```bash
# Scale sidekiq workers
docker-compose up -d --scale sidekiq=3

# Scale app instances (requires load balancer)
docker-compose up -d --scale app=2
```

## Troubleshooting

### Check Service Status

```bash
docker-compose ps
docker-compose logs app
```

### Access Container Shell

```bash
docker-compose exec app bash
docker-compose exec postgres psql -U community community
docker-compose exec redis redis-cli
```

### Reset Everything

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (WARNING: deletes data)
docker-compose down -v

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d
```

## Environment Variables Reference

See `docker/env.community.app.example` for all available configuration options.

## Security Considerations

1. **Change all default passwords** in `.env`
2. **Use strong secret keys** (128-character hex)
3. **Enable HTTPS** with valid SSL certificates
4. **Restrict network access** using firewall rules
5. **Regular backups** of database and uploads
6. **Keep images updated** with security patches

## Support

For integration help, see `INTEGRATION_GUIDE.md`.

For deployment issues, check logs:
```bash
docker-compose logs -f
```



