#!/bin/bash
# Don't use set -e here - we want to handle errors gracefully
# SIRA Community Production Entrypoint
# Handles certificate permission issues for read-only volume mounts
# MUST run as root to copy certificates, then switches to community user

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

# Create required Puma directories (sockets, pids, logs)
# These are needed for Puma to start properly
if [ "$(id -u)" = "0" ]; then
  mkdir -p /var/www/community/tmp/sockets /var/www/community/tmp/pids /var/www/community/log 2>/dev/null || true
  chown -R community:community /var/www/community/tmp /var/www/community/log 2>/dev/null || true
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
  if [ -f "/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.crt" ]; then
    cp /opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.crt "$CERT_DIR/postgres-client.crt" 2>/dev/null && \
    chmod 644 "$CERT_DIR/postgres-client.crt" && \
    chown community:community "$CERT_DIR/postgres-client.crt" && \
    echo "Copied postgres-client.crt" || echo "Failed to copy postgres-client.crt" >&2
  fi

  if [ -f "/opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.key" ]; then
    cp /opt/sira-ai/ssl/postgres-community/sira-community-postgres-client.key "$CERT_DIR/postgres-client.key" 2>/dev/null && \
    chmod 600 "$CERT_DIR/postgres-client.key" && \
    chown community:community "$CERT_DIR/postgres-client.key" && \
    echo "Copied postgres-client.key" || echo "Failed to copy postgres-client.key" >&2
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
    export REDIS_SSL_CERT REDIS_SSL_KEY REDIS_SSL_CA REDIS_CLIENT_CERT REDIS_CLIENT_KEY REDIS_CA_FILE REDIS_TLS_CERT REDIS_TLS_KEY REDIS_TLS_CA
    cd /var/www/community
    exec gosu community "$@"
  else
    # Fallback to su - need to pass env vars and command properly
    # Build the command string with all arguments properly quoted
    CMD_ARGS=""
    for arg in "$@"; do
      CMD_ARGS="$CMD_ARGS $(printf '%q' "$arg")"
    done
    # Use su with proper command execution
    exec su -s /bin/bash community -c "cd /var/www/community && export REDIS_SSL_CERT=\"$REDIS_SSL_CERT\" && export REDIS_SSL_KEY=\"$REDIS_SSL_KEY\" && export REDIS_SSL_CA=\"$REDIS_SSL_CA\" && export REDIS_CLIENT_CERT=\"$REDIS_CLIENT_CERT\" && export REDIS_CLIENT_KEY=\"$REDIS_CLIENT_KEY\" && export REDIS_CA_FILE=\"$REDIS_CA_FILE\" && export REDIS_TLS_CERT=\"$REDIS_TLS_CERT\" && export REDIS_TLS_KEY=\"$REDIS_TLS_KEY\" && export REDIS_TLS_CA=\"$REDIS_TLS_CA\" && $CMD_ARGS"
  fi
else
  # Already running as community user, just execute
  cd /var/www/community
  exec "$@"
fi

