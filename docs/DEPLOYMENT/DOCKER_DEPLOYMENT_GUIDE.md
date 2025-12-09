# Custom Docker Deployment Guide for SIRA Community

## Overview

You're absolutely correct - the `discourse_docker` repository pulls from the official Discourse repository, not your fork. To deploy your custom SIRA Community code, you need to create your own Docker setup.

## Two Approaches

### Approach 1: Fork and Modify discourse_docker (Recommended)

Fork the `discourse_docker` repository and modify it to use your source code.

### Approach 2: Create Custom Dockerfile (More Control)

Build your own Docker image directly from your source code.

---

## Approach 1: Fork discourse_docker

### Step 1: Fork discourse_docker Repository

```bash
# Fork https://github.com/discourse/discourse_docker
# Then clone your fork
git clone https://github.com/your-org/discourse_docker.git
cd discourse_docker
```

### Step 2: Modify to Use Your Source

The key file to modify is typically in `templates/web.standalone.yml` or similar. You need to change where it pulls the Discourse source from:

**Original (pulls from official Discourse):**
```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/discourse.git /var/www/discourse
```

**Modified (pulls from your fork):**
```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/thesiraai/sira-community.git /var/www/discourse
          - cd /var/www/discourse
          - git checkout main  # or your branch
```

### Step 3: Build and Deploy

```bash
# Build the image with your changes
./launcher bootstrap app

# Or rebuild existing
./launcher rebuild app
```

**Pros:**
- Leverages all the existing Docker infrastructure
- Gets updates to Docker setup from upstream
- Handles PostgreSQL, Redis, Nginx automatically

**Cons:**
- Need to maintain a fork
- Must merge upstream changes periodically

---

## Approach 2: Custom Dockerfile (Full Control)

Create your own Docker setup from scratch. This gives you complete control.

### Step 1: Create Dockerfile

Create `Dockerfile` in the root of your repository:

```dockerfile
# Multi-stage build for SIRA Community
FROM ruby:3.3-slim as base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    libpq-dev \
    nodejs \
    npm \
    imagemagick \
    libvips \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm

# Create discourse user
RUN useradd -m -s /bin/bash discourse

# Set working directory
WORKDIR /var/www/discourse

# Copy Gemfile and package files first (for better caching)
COPY Gemfile Gemfile.lock ./
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Install Ruby dependencies
RUN bundle install --deployment --without development test

# Install Node.js dependencies
RUN pnpm install --prod

# Copy application code
COPY . .

# Precompile assets
RUN RAILS_ENV=production bundle exec rake assets:precompile

# Set ownership
RUN chown -R discourse:discourse /var/www/discourse

# Switch to discourse user
USER discourse

# Expose port
EXPOSE 3000

# Start command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### Step 2: Create docker-compose.yml

Create `docker-compose.yml` for complete stack:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: discourse
      POSTGRES_USER: discourse
      POSTGRES_PASSWORD: ${DISCOURSE_DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U discourse"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build:
      context: .
      dockerfile: Dockerfile
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      RAILS_ENV: production
      DISCOURSE_DB_HOST: postgres
      DISCOURSE_DB_NAME: discourse
      DISCOURSE_DB_USERNAME: discourse
      DISCOURSE_DB_PASSWORD: ${DISCOURSE_DB_PASSWORD}
      DISCOURSE_REDIS_HOST: redis
      DISCOURSE_REDIS_PORT: 6379
      DISCOURSE_HOSTNAME: ${DISCOURSE_HOSTNAME:-community.sira.ai}
      DISCOURSE_SECRET_KEY_BASE: ${DISCOURSE_SECRET_KEY_BASE}
      DISCOURSE_SMTP_ADDRESS: ${DISCOURSE_SMTP_ADDRESS}
      DISCOURSE_SMTP_PORT: ${DISCOURSE_SMTP_PORT:-587}
      DISCOURSE_SMTP_USER_NAME: ${DISCOURSE_SMTP_USER_NAME}
      DISCOURSE_SMTP_PASSWORD: ${DISCOURSE_SMTP_PASSWORD}
      DISCOURSE_SMTP_DOMAIN: ${DISCOURSE_SMTP_DOMAIN}
    volumes:
      - ./config/discourse.conf:/var/www/discourse/config/discourse.conf:ro
      - ./public/uploads:/var/www/discourse/public/uploads
      - ./log:/var/www/discourse/log
    ports:
      - "3000:3000"
    restart: unless-stopped

  sidekiq:
    build:
      context: .
      dockerfile: Dockerfile
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      app:
        condition: service_started
    environment:
      RAILS_ENV: production
      DISCOURSE_DB_HOST: postgres
      DISCOURSE_DB_NAME: discourse
      DISCOURSE_DB_USERNAME: discourse
      DISCOURSE_DB_PASSWORD: ${DISCOURSE_DB_PASSWORD}
      DISCOURSE_REDIS_HOST: redis
      DISCOURSE_REDIS_PORT: 6379
    command: bundle exec sidekiq -c 5
    volumes:
      - ./config/discourse.conf:/var/www/discourse/config/discourse.conf:ro
      - ./log:/var/www/discourse/log
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    depends_on:
      - app
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./public:/var/www/discourse/public:ro
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### Step 3: Create .dockerignore

Create `.dockerignore` to exclude unnecessary files:

```
.git
.gitignore
node_modules
log/*
tmp/*
*.log
.env
.env.local
.DS_Store
coverage
.sass-cache
public/uploads
public/backups
```

### Step 4: Create nginx.conf

Create `nginx.conf` for reverse proxy:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream discourse {
        server app:3000;
    }

    server {
        listen 80;
        server_name community.sira.ai;

        # Redirect to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name community.sira.ai;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        client_max_body_size 100m;

        location / {
            proxy_pass http://discourse;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /assets {
            alias /var/www/discourse/public/assets;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

### Step 5: Create .env.example

Create `.env.example` with required variables:

```bash
# Database
DISCOURSE_DB_PASSWORD=your-secure-password

# Hostname
DISCOURSE_HOSTNAME=community.sira.ai

# Secret Key (generate with: ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
DISCOURSE_SECRET_KEY_BASE=your-128-char-hex-string

# SMTP
DISCOURSE_SMTP_ADDRESS=smtp.example.com
DISCOURSE_SMTP_PORT=587
DISCOURSE_SMTP_USER_NAME=your-email@example.com
DISCOURSE_SMTP_PASSWORD=your-smtp-password
DISCOURSE_SMTP_DOMAIN=example.com
```

### Step 6: Build and Run

```bash
# Copy environment file
cp .env.example .env
# Edit .env with your values

# Build and start
docker-compose build
docker-compose up -d

# Run migrations
docker-compose exec app bundle exec rake db:migrate
docker-compose exec app bundle exec rake db:seed_fu

# Check logs
docker-compose logs -f app
```

**Pros:**
- Complete control over the build process
- No dependency on external Docker setup
- Easier to customize for your specific needs
- Can version control your entire Docker setup

**Cons:**
- More work to set up initially
- Must maintain all infrastructure yourself
- Need to handle updates manually

---

## Recommended: Hybrid Approach

Use a custom Dockerfile but base it on the official Discourse Docker image structure:

### Step 1: Study discourse_docker Structure

```bash
git clone https://github.com/discourse/discourse_docker.git /tmp/discourse_docker
# Study the structure, especially:
# - image/base/Dockerfile
# - image/discourse/Dockerfile
# - templates/web.standalone.yml
```

### Step 2: Create Custom Dockerfile Based on Official

Create a Dockerfile that follows the same pattern but uses your source:

```dockerfile
# Base image with all system dependencies
FROM discourse/base:3.3 AS base

# Copy your source code
COPY --chown=discourse:discourse . /var/www/discourse

# Install dependencies
USER discourse
WORKDIR /var/www/discourse
RUN bundle install --deployment --without development test
RUN pnpm install --prod

# Precompile assets
RUN RAILS_ENV=production bundle exec rake assets:precompile

# Final stage
FROM base AS app
CMD ["/sbin/boot"]
```

---

## Production Deployment Steps

### 1. Build Your Image

```bash
# Build the image
docker build -t sira-community:latest .

# Or with docker-compose
docker-compose build
```

### 2. Tag and Push to Registry (Optional)

```bash
# Tag for your registry
docker tag sira-community:latest your-registry.com/sira-community:latest

# Push
docker push your-registry.com/sira-community:latest
```

### 3. Deploy

```bash
# On production server
docker-compose pull  # if using registry
docker-compose up -d

# Run migrations
docker-compose exec app bundle exec rake db:migrate
```

### 4. Update Process

```bash
# Pull latest code
git pull origin main

# Rebuild
docker-compose build

# Restart
docker-compose restart app sidekiq
```

---

## Key Configuration Files Needed

### config/discourse.conf

```ruby
hostname = "community.sira.ai"
db_host = "postgres"  # Docker service name
db_name = "discourse"
db_username = "discourse"
db_password = "your-password"
redis_host = "redis"  # Docker service name
redis_port = 6379
secret_key_base = "your-128-char-hex-string"
smtp_address = "smtp.example.com"
smtp_port = 587
smtp_user_name = "your-email@example.com"
smtp_password = "your-password"
smtp_domain = "example.com"
```

---

## CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/docker-build.yml`:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t sira-community:${{ github.sha }} .
      
      - name: Push to registry
        run: |
          echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login -u "${{ secrets.REGISTRY_USERNAME }}" --password-stdin
          docker tag sira-community:${{ github.sha }} your-registry.com/sira-community:${{ github.sha }}
          docker tag sira-community:${{ github.sha }} your-registry.com/sira-community:latest
          docker push your-registry.com/sira-community:${{ github.sha }}
          docker push your-registry.com/sira-community:latest
```

---

## Troubleshooting

### Build Issues

```bash
# Check build logs
docker-compose build --no-cache

# Debug inside container
docker-compose run --rm app bash
```

### Runtime Issues

```bash
# Check logs
docker-compose logs app
docker-compose logs sidekiq

# Access container
docker-compose exec app bash

# Check database connection
docker-compose exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1')"
```

---

## Summary

**You're correct** - you need your own Docker setup. Choose:

1. **Fork discourse_docker** - Easier, but requires maintaining a fork
2. **Custom Dockerfile** - More work, but complete control
3. **Hybrid** - Best of both worlds

I recommend **Approach 2 (Custom Dockerfile)** for maximum control and independence from the official Discourse Docker setup.



