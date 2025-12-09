#!/bin/bash
# Pre-Deployment Validation Script
# Validates all requirements before deployment

set -e

ERRORS=0
WARNINGS=0

echo "🔍 Pre-Deployment Validation Check"
echo "===================================="
echo ""

# Check if discourse.conf exists
echo "1. Checking configuration files..."
if [ ! -f "config/discourse.conf" ]; then
    echo "❌ ERROR: config/discourse.conf not found"
    echo "   Create it from config/discourse.conf.example"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ config/discourse.conf exists"
    
    # Check if hostname is set (not default)
    if grep -q 'hostname = "www.example.com"' config/discourse.conf; then
        echo "❌ ERROR: hostname is still set to default (www.example.com)"
        echo "   Update hostname in config/discourse.conf"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ hostname is configured"
    fi
    
    # Check if secret_key_base is set
    if grep -q '^secret_key_base = $' config/discourse.conf || grep -q '^secret_key_base = ""' config/discourse.conf; then
        echo "❌ ERROR: secret_key_base is not set"
        echo "   Generate with: ruby -e \"require 'securerandom'; puts SecureRandom.hex(64)\""
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ secret_key_base is configured"
    fi
fi

# Check environment file
echo ""
echo "2. Checking environment configuration..."
if [ ! -f ".env" ]; then
    echo "⚠️  WARNING: .env file not found"
    echo "   Copy from docker/env.community.app.prod and configure"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ .env file exists"
    
    # Check for placeholder values
    if grep -q "CHANGE_ME\|REPLACE_WITH\|0000000000000000" .env; then
        echo "⚠️  WARNING: .env contains placeholder values"
        echo "   Replace all placeholders with actual production values"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "✅ .env appears to be configured"
    fi
fi

# Check SSL certificates (if path is set)
echo ""
echo "3. Checking SSL certificates..."
if [ -n "$SSL_CERTS_PATH" ] && [ -d "$SSL_CERTS_PATH" ]; then
    ./docker/scripts/validate-ssl.sh
    if [ $? -ne 0 ]; then
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "⚠️  WARNING: SSL_CERTS_PATH not set or directory not found"
    echo "   SSL certificates must be available at /opt/sira-ai/ssl"
    WARNINGS=$((WARNINGS + 1))
fi

# Check Docker network
echo ""
echo "4. Checking Docker network..."
if docker network inspect sira_infra_network > /dev/null 2>&1; then
    echo "✅ sira_infra_network exists"
else
    echo "⚠️  WARNING: sira_infra_network not found"
    echo "   Ensure infrastructure services are running"
    WARNINGS=$((WARNINGS + 1))
fi

# Check if infrastructure services are accessible
echo ""
echo "5. Checking infrastructure services..."
if docker network inspect sira_infra_network > /dev/null 2>&1; then
    # Try to resolve postgres host
    if docker run --rm --network sira_infra_network alpine nslookup postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL service is accessible"
    else
        echo "⚠️  WARNING: Cannot resolve postgres host"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if docker run --rm --network sira_infra_network alpine nslookup redis > /dev/null 2>&1; then
        echo "✅ Redis service is accessible"
    else
        echo "⚠️  WARNING: Cannot resolve redis host"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "⚠️  WARNING: Cannot check services (network not found)"
fi

# Summary
echo ""
echo "===================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed! Ready for deployment."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Validation completed with $WARNINGS warning(s)"
    echo "   Review warnings above before deploying"
    exit 0
else
    echo "❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)"
    echo "   Please fix all errors before deploying"
    exit 1
fi

