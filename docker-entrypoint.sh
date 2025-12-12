#!/bin/bash
# Don't use set -e here - we want to handle errors gracefully
# SIRA Community Production Entrypoint
# Handles certificate permission issues for read-only volume mounts
# MUST run as root to copy certificates, then switches to community user

# CRITICAL: Backup asset-processor.js FIRST, before ANY other operations
# This file is copied during Docker build and must be preserved
ASSET_PROCESSOR_FILE="/var/www/community/tmp/asset-processor.js"
ASSET_PROCESSOR_BACKUP="/tmp/asset-processor.js.backup"
ASSET_PROCESSOR_PUBLIC="/var/www/community/public/assets/asset-processor.js"

# Backup from either location IMMEDIATELY (before any directory operations)
if [ -f "$ASSET_PROCESSOR_FILE" ]; then
  cp "$ASSET_PROCESSOR_FILE" "$ASSET_PROCESSOR_BACKUP" 2>/dev/null && echo "✓ Backed up asset-processor.js from tmp/ (18M)" >&2 || echo "⚠ Failed to backup from tmp/" >&2
elif [ -f "$ASSET_PROCESSOR_PUBLIC" ]; then
  cp "$ASSET_PROCESSOR_PUBLIC" "$ASSET_PROCESSOR_BACKUP" 2>/dev/null && echo "✓ Backed up asset-processor.js from public/assets/ (18M)" >&2 || echo "⚠ Failed to backup from public/assets/" >&2
fi

# Check if we're running as root - if not, we can't copy certificates
if [ "$(id -u)" != "0" ]; then
  echo "ERROR: Entrypoint must run as root to copy certificates" >&2
  echo "Current user: $(id -u) ($(whoami))" >&2
  # Try to continue anyway - maybe certificates are already copied
fi

# Create writable directory for certificates
CERT_DIR="/var/www/community/tmp/ssl"
mkdir -p "$CERT_DIR" 2>/dev/null || true
if [ "$(id -u)" = "0" ]; then
  chown community:community "$CERT_DIR" 2>/dev/null || true
fi

if [ "$(id -u)" = "0" ]; then
  mkdir -p /var/www/community/tmp/sockets /var/www/community/tmp/pids /var/www/community/log 2>/dev/null || true
  chown -R community:community /var/www/community/tmp /var/www/community/log 2>/dev/null || true
  # Restore asset-processor.js after chown (from /tmp which is not affected by chown -R)
  if [ -f "$ASSET_PROCESSOR_BACKUP" ]; then
    # Restore to both locations for maximum reliability
    cp "$ASSET_PROCESSOR_BACKUP" "$ASSET_PROCESSOR_FILE" 2>/dev/null || true
    cp "$ASSET_PROCESSOR_BACKUP" "$ASSET_PROCESSOR_PUBLIC" 2>/dev/null || true
    chown community:community "$ASSET_PROCESSOR_FILE" "$ASSET_PROCESSOR_PUBLIC" 2>/dev/null || true
    chmod 644 "$ASSET_PROCESSOR_FILE" "$ASSET_PROCESSOR_PUBLIC" 2>/dev/null || true
    rm -f "$ASSET_PROCESSOR_BACKUP" 2>/dev/null || true
    echo "✓ Asset processor restored to tmp/ and public/assets/"
  fi
fi

# Ensure asset processor exists (production-grade fallback)
# This should be built during Docker build, but verify it exists at startup
# If missing, attempt to build it (requires pnpm and dependencies)
if [ ! -f "/var/www/community/tmp/asset-processor.js" ]; then
  echo "WARNING: Asset processor not found - attempting to build at runtime..."
  if [ "$(id -u)" = "0" ]; then
    # Run as community user to build
    if command -v gosu >/dev/null 2>&1; then
      gosu community bash -c "cd /var/www/community && \
        if [ -d frontend/asset-processor ]; then \
          cd frontend/asset-processor && \
          pnpm install >/dev/null 2>&1 && \
          pnpm -C=. node build.js > /var/www/community/tmp/asset-processor.js 2>&1 && \
          echo 'Asset processor built at runtime' || \
          echo 'WARNING: Failed to build asset processor at runtime'; \
        fi"
    fi
  fi
fi

# Create admin account if enabled (idempotent - safe to run multiple times)
# Only run for app service (not sidekiq or migrate)
if [ "${ENABLE_AUTO_ADMIN:-false}" = "true" ] && [ "$POSTGRES_CERT_TYPE" != "migrate" ]; then
  echo "Creating/updating admin account (idempotent)..."
  if [ "$(id -u)" = "0" ]; then
    if command -v gosu >/dev/null 2>&1; then
      gosu community bash -c "cd /var/www/community && \
        bundle exec rake admin:create 2>&1" || \
        echo "WARNING: Failed to create admin account (may already exist)"
    fi
  else
    cd /var/www/community && bundle exec rake admin:create 2>&1 || \
      echo "WARNING: Failed to create admin account (may already exist)"
  fi
fi

# Copy certificates from read-only mount to writable location
# This allows the community user to read them
# MUST run as root to read the read-only mounted files
if [ "$(id -u)" = "0" ]; then
  if [ -f "/opt/sira-ai/ssl/redis/sira-community-redis-client.crt" ]; then
    cp /opt/sira-ai/ssl/redis/sira-community-redis-client.crt "$CERT_DIR/redis-client.crt" 2>/dev/null && \
    chmod 644 "$CERT_DIR/redis-client.crt" && \
    chown community:community "$CERT_DIR/redis-client.crt" && \
    echo "Copied redis-client.crt" || echo "Failed to copy redis-client.crt" >&2
  fi

  if [ -f "/opt/sira-ai/ssl/redis/sira-community-redis-client.key" ]; then
    cp /opt/sira-ai/ssl/redis/sira-community-redis-client.key "$CERT_DIR/redis-client.key" 2>/dev/null && \
    chmod 600 "$CERT_DIR/redis-client.key" && \
    chown community:community "$CERT_DIR/redis-client.key" && \
    echo "Copied redis-client.key" || echo "Failed to copy redis-client.key" >&2
  fi

  if [ -f "/opt/sira-ai/ssl/ca/ca.crt" ]; then
    cp /opt/sira-ai/ssl/ca/ca.crt "$CERT_DIR/ca.crt" 2>/dev/null && \
    chmod 644 "$CERT_DIR/ca.crt" && \
    chown community:community "$CERT_DIR/ca.crt" && \
    echo "Copied ca.crt" || echo "Failed to copy ca.crt" >&2
  fi

  # Copy PostgreSQL certificates (same issue as Redis - root-owned, read-only mount)
  # Determine which certificate to use based on service (migrate uses migrate-client, app/sidekiq use app-client)
  # Priority: 1) POSTGRES_CERT_TYPE env var, 2) command args, 3) default to app-client
  CMD_STRING="$*"
  IS_MIGRATE=false
  
  # Debug: log environment variable value
  echo "DEBUG: POSTGRES_CERT_TYPE='${POSTGRES_CERT_TYPE}'"
  echo "DEBUG: CMD_STRING='${CMD_STRING}'"
  
  # Check POSTGRES_CERT_TYPE environment variable first (most reliable)
  if [ "$POSTGRES_CERT_TYPE" = "migrate" ]; then
    IS_MIGRATE=true
    echo "DEBUG: Detected migrate service via POSTGRES_CERT_TYPE"
  elif [ "$POSTGRES_CERT_TYPE" = "app" ]; then
    IS_MIGRATE=false
    echo "DEBUG: Detected app service via POSTGRES_CERT_TYPE"
  # Fallback: check command string for migration commands
  elif echo "$CMD_STRING" | grep -q "db:migrate\|rails.*migrate"; then
    IS_MIGRATE=true
    echo "DEBUG: Detected migrate service via command string"
  else
    echo "DEBUG: Defaulting to app service (no migrate detected)"
  fi
  
  if [ "$IS_MIGRATE" = "true" ]; then
    # Migration service - use migrate-client certificates
    POSTGRES_CERT_SOURCE="/opt/sira-ai/ssl/postgres-client/migrate-client.crt"
    POSTGRES_KEY_SOURCE="/opt/sira-ai/ssl/postgres-client/migrate-client.key"
    echo "Using migrate-client certificates for migration service"
  else
    # Application service (app or sidekiq) - use app-client certificates
    POSTGRES_CERT_SOURCE="/opt/sira-ai/ssl/postgres-client/app-client.crt"
    POSTGRES_KEY_SOURCE="/opt/sira-ai/ssl/postgres-client/app-client.key"
    echo "Using app-client certificates for application service"
  fi

  if [ -f "$POSTGRES_CERT_SOURCE" ]; then
    cp "$POSTGRES_CERT_SOURCE" "$CERT_DIR/postgres-client.crt" 2>/dev/null && \
    chmod 644 "$CERT_DIR/postgres-client.crt" && \
    chown community:community "$CERT_DIR/postgres-client.crt" && \
    echo "Copied postgres-client.crt from $(basename $POSTGRES_CERT_SOURCE)" || echo "Failed to copy postgres-client.crt" >&2
  else
    echo "WARNING: PostgreSQL certificate not found at $POSTGRES_CERT_SOURCE" >&2
  fi

  if [ -f "$POSTGRES_KEY_SOURCE" ]; then
    cp "$POSTGRES_KEY_SOURCE" "$CERT_DIR/postgres-client.key" 2>/dev/null && \
    chmod 600 "$CERT_DIR/postgres-client.key" && \
    chown community:community "$CERT_DIR/postgres-client.key" && \
    echo "Copied postgres-client.key from $(basename $POSTGRES_KEY_SOURCE)" || echo "Failed to copy postgres-client.key" >&2
  else
    echo "WARNING: PostgreSQL key not found at $POSTGRES_KEY_SOURCE" >&2
  fi
else
  echo "WARNING: Not running as root - cannot copy certificates" >&2
  echo "Certificates must already be in $CERT_DIR" >&2
fi

# Update environment variables to point to writable certificate location
    export REDIS_SSL_CERT="$CERT_DIR/redis-client.crt"
    export REDIS_SSL_KEY="$CERT_DIR/redis-client.key"
    export REDIS_SSL_CA="$CERT_DIR/ca.crt"
    export REDIS_CLIENT_CERT="$CERT_DIR/redis-client.crt"
    export REDIS_CLIENT_KEY="$CERT_DIR/redis-client.key"
    export REDIS_CA_FILE="$CERT_DIR/ca.crt"
    export REDIS_TLS_CERT="$CERT_DIR/redis-client.crt"
    export REDIS_TLS_KEY="$CERT_DIR/redis-client.key"
    export REDIS_TLS_CA="$CERT_DIR/ca.crt"

# PostgreSQL certificates (copied to writable location)
export POSTGRES_SSL_CERT="$CERT_DIR/postgres-client.crt"
export POSTGRES_SSL_KEY="$CERT_DIR/postgres-client.key"
export POSTGRES_SSL_CA="$CERT_DIR/ca.crt"
export POSTGRES_CA_FILE="$CERT_DIR/ca.crt"
export POSTGRES_CLIENT_CERT="$CERT_DIR/postgres-client.crt"
export POSTGRES_CLIENT_KEY="$CERT_DIR/postgres-client.key"

# Switch to community user for running the application
# Use gosu if available (cleaner), otherwise use su
if [ "$(id -u)" = "0" ]; then
  # We're root, switch to community user with environment variables
  if command -v gosu >/dev/null 2>&1; then
    # Use gosu (cleaner, designed for this purpose)
    # Export environment variables so they're available to the command
    export REDIS_SSL_CERT REDIS_SSL_KEY REDIS_SSL_CA REDIS_CLIENT_CERT REDIS_CLIENT_KEY REDIS_CA_FILE REDIS_TLS_CERT REDIS_TLS_KEY REDIS_TLS_CA \
           POSTGRES_SSL_CERT POSTGRES_SSL_KEY POSTGRES_SSL_CA POSTGRES_CA_FILE POSTGRES_CLIENT_CERT POSTGRES_CLIENT_KEY \
           ADMIN_EMAIL ADMIN_USERNAME ADMIN_PASSWORD BUNDLE_PATH APP_ROOT RAILS_ENV
    cd /var/www/community
    # Ensure BUNDLE_PATH is set for bundle to find gems
    export BUNDLE_PATH="${BUNDLE_PATH:-/var/www/community/vendor/bundle}"
    # Use exec to replace shell process and preserve working directory
    # Pass all arguments correctly to gosu
    exec gosu community env BUNDLE_PATH="$BUNDLE_PATH" "$@"
  else
    # Fallback to su - need to pass env vars and command properly
    # Build the command string with all arguments properly quoted
    CMD_ARGS=""
    for arg in "$@"; do
      CMD_ARGS="$CMD_ARGS $(printf '%q' "$arg")"
    done
    # Use su with proper command execution
    exec su -s /bin/bash community -c "cd /var/www/community && export BUNDLE_PATH=\${BUNDLE_PATH:-/var/www/community/vendor/bundle} && export REDIS_SSL_CERT=\"$REDIS_SSL_CERT\" && export REDIS_SSL_KEY=\"$REDIS_SSL_KEY\" && export REDIS_SSL_CA=\"$REDIS_SSL_CA\" && export REDIS_CLIENT_CERT=\"$REDIS_CLIENT_CERT\" && export REDIS_CLIENT_KEY=\"$REDIS_CLIENT_KEY\" && export REDIS_CA_FILE=\"$REDIS_CA_FILE\" && export REDIS_TLS_CERT=\"$REDIS_TLS_CERT\" && export REDIS_TLS_KEY=\"$REDIS_TLS_KEY\" && export REDIS_TLS_CA=\"$REDIS_TLS_CA\" && export POSTGRES_SSL_CERT=\"$POSTGRES_SSL_CERT\" && export POSTGRES_SSL_KEY=\"$POSTGRES_SSL_KEY\" && export POSTGRES_SSL_CA=\"$POSTGRES_SSL_CA\" && export POSTGRES_CA_FILE=\"$POSTGRES_CA_FILE\" && export POSTGRES_CLIENT_CERT=\"$POSTGRES_CLIENT_CERT\" && export POSTGRES_CLIENT_KEY=\"$POSTGRES_CLIENT_KEY\" && export APP_ROOT=\"$APP_ROOT\" && export RAILS_ENV=\"$RAILS_ENV\" && $CMD_ARGS"
  fi
else
  # Already running as community user, just execute
  cd /var/www/community
  exec "$@"
fi

