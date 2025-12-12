#!/bin/bash
# SSL Certificate Validation Script
# Validates that all required SSL certificates exist and are valid

set -e

SSL_BASE_PATH="${SSL_CERTS_PATH:-/opt/sira-ai/ssl}"
ERRORS=0

echo "🔒 Validating SSL Certificates..."
echo "Certificate Path: $SSL_BASE_PATH"
echo ""

# Check if base directory exists
if [ ! -d "$SSL_BASE_PATH" ]; then
    echo "❌ ERROR: SSL certificate directory not found: $SSL_BASE_PATH"
    echo "   Please ensure SSL certificates are mounted at this path"
    exit 1
fi

# Validate CA Certificate
echo "Checking CA Certificate..."
if [ ! -f "$SSL_BASE_PATH/ca/ca.crt" ]; then
    echo "❌ ERROR: CA certificate not found: $SSL_BASE_PATH/ca/ca.crt"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ CA certificate found"
    openssl x509 -in "$SSL_BASE_PATH/ca/ca.crt" -text -noout > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ CA certificate is valid"
    else
        echo "❌ ERROR: CA certificate is invalid"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Validate PostgreSQL Client Certificates
echo ""
echo "Checking PostgreSQL Client Certificates..."
if [ ! -f "$SSL_BASE_PATH/postgres/postgres-client.crt" ]; then
    echo "❌ ERROR: PostgreSQL client certificate not found: $SSL_BASE_PATH/postgres/postgres-client.crt"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ PostgreSQL client certificate found"
    openssl x509 -in "$SSL_BASE_PATH/postgres/postgres-client.crt" -text -noout > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ PostgreSQL client certificate is valid"
    else
        echo "❌ ERROR: PostgreSQL client certificate is invalid"
        ERRORS=$((ERRORS + 1))
    fi
fi

if [ ! -f "$SSL_BASE_PATH/postgres/postgres-client.key" ]; then
    echo "❌ ERROR: PostgreSQL client key not found: $SSL_BASE_PATH/postgres/postgres-client.key"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ PostgreSQL client key found"
    openssl rsa -in "$SSL_BASE_PATH/postgres/postgres-client.key" -check > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ PostgreSQL client key is valid"
    else
        echo "❌ ERROR: PostgreSQL client key is invalid"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Validate Redis Client Certificates
echo ""
echo "Checking Redis Client Certificates..."
if [ ! -f "$SSL_BASE_PATH/redis/redis-client.crt" ]; then
    echo "❌ ERROR: Redis client certificate not found: $SSL_BASE_PATH/redis/redis-client.crt"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ Redis client certificate found"
    openssl x509 -in "$SSL_BASE_PATH/redis/redis-client.crt" -text -noout > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Redis client certificate is valid"
    else
        echo "❌ ERROR: Redis client certificate is invalid"
        ERRORS=$((ERRORS + 1))
    fi
fi

if [ ! -f "$SSL_BASE_PATH/redis/redis-client.key" ]; then
    echo "❌ ERROR: Redis client key not found: $SSL_BASE_PATH/redis/redis-client.key"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ Redis client key found"
    openssl rsa -in "$SSL_BASE_PATH/redis/redis-client.key" -check > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Redis client key is valid"
    else
        echo "❌ ERROR: Redis client key is invalid"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check certificate permissions
echo ""
echo "Checking Certificate Permissions..."
if [ -f "$SSL_BASE_PATH/postgres/postgres-client.key" ]; then
    PERMS=$(stat -c "%a" "$SSL_BASE_PATH/postgres/postgres-client.key")
    if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
        echo "⚠️  WARNING: PostgreSQL client key permissions are $PERMS (should be 600 or 400)"
    else
        echo "✅ PostgreSQL client key permissions are secure"
    fi
fi

if [ -f "$SSL_BASE_PATH/redis/redis-client.key" ]; then
    PERMS=$(stat -c "%a" "$SSL_BASE_PATH/redis/redis-client.key")
    if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
        echo "⚠️  WARNING: Redis client key permissions are $PERMS (should be 600 or 400)"
    else
        echo "✅ Redis client key permissions are secure"
    fi
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All SSL certificates validated successfully!"
    exit 0
else
    echo "❌ Validation failed with $ERRORS error(s)"
    echo "   Please fix the errors above before deploying"
    exit 1
fi



