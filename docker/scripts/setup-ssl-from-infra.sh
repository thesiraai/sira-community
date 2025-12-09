#!/bin/bash
# Setup SSL Certificates from Infrastructure Containers
# This script copies SSL certificates from infrastructure containers to local path

set -e

SSL_TARGET_PATH="${SSL_CERTS_PATH:-/opt/sira-ai/ssl}"
INFRA_POSTGRES="sira_infra_postgres"
INFRA_REDIS="sira_infra_redis"

echo "🔒 Setting up SSL certificates from infrastructure..."
echo "Target path: $SSL_TARGET_PATH"
echo ""

# Check if infrastructure containers are running
if ! docker ps --format "{{.Names}}" | grep -q "^${INFRA_POSTGRES}$"; then
    echo "❌ ERROR: Infrastructure PostgreSQL container not found: $INFRA_POSTGRES"
    exit 1
fi

if ! docker ps --format "{{.Names}}" | grep -q "^${INFRA_REDIS}$"; then
    echo "❌ ERROR: Infrastructure Redis container not found: $INFRA_REDIS"
    exit 1
fi

echo "✅ Infrastructure containers found"

# Create target directory structure
echo "Creating directory structure..."
mkdir -p "$SSL_TARGET_PATH/ca"
mkdir -p "$SSL_TARGET_PATH/postgres"
mkdir -p "$SSL_TARGET_PATH/redis"

# Check if certificates exist in containers
echo ""
echo "Checking for certificates in infrastructure containers..."

# Try to find certificates in common locations
CERT_LOCATIONS=(
    "/opt/sira-ai/ssl"
    "/etc/ssl/sira-ai"
    "/var/lib/postgresql/ssl"
    "/ssl"
)

FOUND_CERTS=false

for LOC in "${CERT_LOCATIONS[@]}"; do
    if docker exec "$INFRA_POSTGRES" test -f "$LOC/ca/ca.crt" 2>/dev/null; then
        echo "✅ Found certificates at: $LOC"
        CERT_BASE="$LOC"
        FOUND_CERTS=true
        break
    fi
done

if [ "$FOUND_CERTS" = false ]; then
    echo "⚠️  Certificates not found in standard locations"
    echo ""
    echo "Please check infrastructure documentation for certificate location."
    echo "Or contact infrastructure team for certificate setup."
    echo ""
    echo "For local development, you may need to:"
    echo "1. Check infrastructure docker-compose.yml for certificate mounts"
    echo "2. Copy certificates from infrastructure volume mounts"
    echo "3. Request certificates from infrastructure team"
    exit 1
fi

# Copy CA certificate
echo ""
echo "Copying CA certificate..."
if docker exec "$INFRA_POSTGRES" test -f "$CERT_BASE/ca/ca.crt" 2>/dev/null; then
    docker cp "$INFRA_POSTGRES:$CERT_BASE/ca/ca.crt" "$SSL_TARGET_PATH/ca/ca.crt"
    echo "✅ CA certificate copied"
else
    echo "❌ CA certificate not found in container"
    exit 1
fi

# Copy PostgreSQL certificates
echo "Copying PostgreSQL certificates..."
if docker exec "$INFRA_POSTGRES" test -f "$CERT_BASE/postgres/postgres-client.crt" 2>/dev/null; then
    docker cp "$INFRA_POSTGRES:$CERT_BASE/postgres/postgres-client.crt" "$SSL_TARGET_PATH/postgres/postgres-client.crt"
    docker cp "$INFRA_POSTGRES:$CERT_BASE/postgres/postgres-client.key" "$SSL_TARGET_PATH/postgres/postgres-client.key"
    echo "✅ PostgreSQL certificates copied"
else
    echo "⚠️  PostgreSQL certificates not found - checking alternative locations..."
    # Try to find in container
    docker exec "$INFRA_POSTGRES" find / -name "postgres-client.crt" 2>/dev/null | head -1 || echo "   Not found"
fi

# Copy Redis certificates
echo "Copying Redis certificates..."
if docker exec "$INFRA_REDIS" test -f "$CERT_BASE/redis/redis-client.crt" 2>/dev/null; then
    docker cp "$INFRA_REDIS:$CERT_BASE/redis/redis-client.crt" "$SSL_TARGET_PATH/redis/redis-client.crt"
    docker cp "$INFRA_REDIS:$CERT_BASE/redis/redis-client.key" "$SSL_TARGET_PATH/redis/redis-client.key"
    echo "✅ Redis certificates copied"
else
    echo "⚠️  Redis certificates not found - checking alternative locations..."
    docker exec "$INFRA_REDIS" find / -name "redis-client.crt" 2>/dev/null | head -1 || echo "   Not found"
fi

# Set permissions
echo ""
echo "Setting certificate permissions..."
chmod 644 "$SSL_TARGET_PATH/ca/ca.crt" 2>/dev/null || true
chmod 644 "$SSL_TARGET_PATH/postgres/postgres-client.crt" 2>/dev/null || true
chmod 600 "$SSL_TARGET_PATH/postgres/postgres-client.key" 2>/dev/null || true
chmod 644 "$SSL_TARGET_PATH/redis/redis-client.crt" 2>/dev/null || true
chmod 600 "$SSL_TARGET_PATH/redis/redis-client.key" 2>/dev/null || true

echo "✅ Permissions set"

# Validate
echo ""
echo "Validating certificates..."
if [ -f "$SSL_TARGET_PATH/ca/ca.crt" ]; then
    echo "✅ CA certificate: $SSL_TARGET_PATH/ca/ca.crt"
fi
if [ -f "$SSL_TARGET_PATH/postgres/postgres-client.crt" ]; then
    echo "✅ PostgreSQL certificate: $SSL_TARGET_PATH/postgres/postgres-client.crt"
fi
if [ -f "$SSL_TARGET_PATH/redis/redis-client.crt" ]; then
    echo "✅ Redis certificate: $SSL_TARGET_PATH/redis/redis-client.crt"
fi

echo ""
echo "✅ SSL certificate setup complete!"
echo ""
echo "Note: On Windows, certificates may need to be accessible at:"
echo "  - C:\opt\sira-ai\ssl (Windows path)"
echo "  - Or mounted via Docker volume"
echo ""

