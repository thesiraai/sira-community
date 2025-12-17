# SIRA Community - Discourse Docker Deployment

This directory contains the Docker configuration for deploying Discourse using the official `discourse/discourse:latest` Docker image.

## Architecture

- **Discourse Container**: Official Discourse image (`discourse/discourse:latest`)
- **Nginx Reverse Proxy**: HTTPS termination and routing
- **Custom Plugin**: `plugins/discourse-sira-ai` mounted into container
- **Infrastructure**: Connects to existing SIRA infrastructure (postgres-community, redis-community)

## Files

- `docker-compose.discourse.yml` - Docker Compose configuration
- `env.discourse.local` - Local environment variables
- `env.discourse.prod` - Production environment template
- `nginx/nginx-discourse.conf` - Nginx reverse proxy configuration
- `nginx/ssl/` - SSL certificates (fullchain.pem, privkey.pem)
- `nginx/logs/` - Nginx access/error logs
- `start-discourse.sh` / `start-discourse.ps1` - Helper scripts to start services

## Quick Start

1. **Configure environment variables:**
   ```bash
   # Edit docker/env.discourse.local with your actual values
   # Ensure COMMUNITY_SECRET_KEY_BASE and SIRA_API_KEY are set
   ```

2. **Place SSL certificates:**
   Copy your SSL certificates to `docker/nginx/ssl/`:
   - `fullchain.pem` - Server certificate + CA chain
   - `privkey.pem` - Private key

3. **Start services:**
   ```bash
   cd docker
   ./start-discourse.sh
   # Or on Windows:
   .\start-discourse.ps1
   ```

4. **Access Discourse:**
   - Add to hosts file: `127.0.0.1 local.community.sira.ai`
   - Access: `https://local.community.sira.ai:8443`

## One Product Mode (served under SIRA App at `/community`)

For the “one product” UX, Discourse is **not** accessed on its own hostname (like `local.community.sira.ai`). Instead it is reverse-proxied by the SIRA App edge nginx and served under:

- `https://<env>.app.sira.ai/community/...`

In this mode, this repo provides a compose file that runs **only** the Discourse container (no external nginx), so that SIRA App nginx can proxy `/community/*` to it securely on an internal Docker network.

### Start Discourse for one-product mode (local template)

```bash
cd docker
cp env.discourse.oneproduct.example env.discourse.oneproduct.local
# edit env.discourse.oneproduct.local (secrets, hostname, port)
docker compose -f docker-compose.discourse.oneproduct.yml --env-file env.discourse.oneproduct.local up -d
```

**Recommended upstream from SIRA App nginx (same-host Docker):**
- `DISCOURSE_UPSTREAM=http://discourse:3000`

**Important security note (production):**
- Do **not** publish Discourse ports to the host; only the SIRA App nginx container should reach it over the private Docker network.

### TLS certificate note (local domain)

The nginx container terminates HTTPS using the certs in `docker/nginx/ssl/` (`fullchain.pem`, `privkey.pem`).
If your certificate was issued for a different hostname (e.g. `community.sira.ai`), your browser will show a TLS warning.
For a clean local dev experience, generate a cert for `local.community.sira.ai` (e.g. with `mkcert`) and place it in `docker/nginx/ssl/`.

## Create/Register the Admin Account (first install)

On a fresh database, Discourse has no human admin yet. You must complete the setup wizard once to create the first admin user.

### Option A (recommended): Web UI wizard

1. Open: `https://local.community.sira.ai:8443`
2. Click **Register Admin Account** (or open the wizard directly at `https://local.community.sira.ai:8443/wizard`)
3. Enter the admin **email**, **username**, and **password**
4. If email verification is enabled, click the activation link sent to the admin email

### Option B: CLI fallback (inside the container)

If the wizard is blocked for any reason, you can create an admin from inside the container:

```bash
docker exec -it sira-discourse bash -lc "cd /var/www/discourse && bundle exec rake admin:create"
```

If you see `fatal: detected dubious ownership in repository at '/var/www/discourse'`, run once:

```bash
docker exec -it sira-discourse bash -lc "git config --global --add safe.directory /var/www/discourse"
```

## Services

- **discourse** - Discourse application (internal port 3000, accessed via nginx)
- **discourse-nginx** - Nginx reverse proxy (HTTPS on port 8443)

## Environment Variables

Key variables in `env.discourse.local`:

- `DISCOURSE_HOSTNAME` - Domain name (e.g., `local.community.sira.ai`)
- `DISCOURSE_PORT` - Port for URL generation (e.g., `8443`)
- `COMMUNITY_DB_NAME`, `COMMUNITY_DB_USERNAME`, `COMMUNITY_DB_PASSWORD` - PostgreSQL credentials
- `REDIS_PASSWORD` - Redis password
- `SIRA_API_KEY` - SIRA AI API key for integration
- `DISCOURSE_SECRET_KEY_BASE` - Rails secret key

## Troubleshooting

- **Check logs:** `docker compose -f docker/docker-compose.discourse.yml logs -f discourse`
- **Check nginx logs:** `docker compose -f docker/docker-compose.discourse.yml logs -f discourse-nginx`
- **Database connection:** Verify `postgres-community` service is running and credentials match
- **Redis connection:** Verify `redis-community` service is running and password matches
- **SSL errors:** Ensure certificates are in `docker/nginx/ssl/` and CA is trusted

## Production Deployment

For production, update `env.discourse.prod` with:
1. Strong, unique passwords
2. Production SMTP settings
3. Production SSL certificates
4. Production SIRA API key

Then use: `docker compose -f docker/docker-compose.discourse.yml --env-file docker/env.discourse.prod up -d`
