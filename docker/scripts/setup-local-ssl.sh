#!/bin/bash
# SSL Certificate Setup Guide for Local Deployment
# This script provides instructions for setting up SSL certificates for local deployment

set -e

echo "🔒 SSL Certificate Setup for Local Deployment"
echo "=============================================="
echo ""
echo "For production-grade local deployment, SSL certificates are MANDATORY."
echo "These certificates come from the SIRA infrastructure setup."
echo ""

# Check if certificates already exist
if [ -d "/opt/sira-ai/ssl" ] && [ -f "/opt/sira-ai/ssl/ca/ca.crt" ]; then
    echo "✅ SSL certificates found at /opt/sira-ai/ssl"
    echo ""
    echo "Certificate structure:"
    ls -la /opt/sira-ai/ssl/ca/
    ls -la /opt/sira-ai/ssl/postgres/ 2>/dev/null || echo "⚠️  PostgreSQL certificates not found"
    ls -la /opt/sira-ai/ssl/redis/ 2>/dev/null || echo "⚠️  Redis certificates not found"
    echo ""
    echo "Running validation..."
    ./docker/scripts/validate-ssl.sh
    exit 0
fi

echo "❌ SSL certificates not found at /opt/sira-ai/ssl"
echo ""
echo "📋 SSL Certificate Setup Instructions"
echo "======================================"
echo ""
echo "SSL certificates are required from the SIRA infrastructure setup."
echo ""
echo "Option 1: Use Infrastructure Certificates (Recommended)"
echo "--------------------------------------------------------"
echo "1. Ensure SIRA infrastructure is running:"
echo "   cd sira-infra/infra/docker/compose"
echo "   docker compose -f docker-compose.infra.yml --env-file env.local up -d"
echo ""
echo "2. Certificates should be available at:"
echo "   /opt/sira-ai/ssl/ca/ca.crt"
echo "   /opt/sira-ai/ssl/postgres/postgres-client.crt"
echo "   /opt/sira-ai/ssl/postgres/postgres-client.key"
echo "   /opt/sira-ai/ssl/redis/redis-client.crt"
echo "   /opt/sira-ai/ssl/redis/redis-client.key"
echo ""
echo "3. Verify certificates are accessible:"
echo "   ls -la /opt/sira-ai/ssl/"
echo ""
echo "Option 2: Copy from Infrastructure Container"
echo "--------------------------------------------"
echo "If certificates are in infrastructure containers, copy them:"
echo ""
echo "1. Find infrastructure container:"
echo "   docker ps | grep sira_infra"
echo ""
echo "2. Copy certificates (example):"
echo "   docker cp sira_infra_postgres:/opt/sira-ai/ssl /opt/sira-ai/ssl"
echo ""
echo "3. Set proper permissions:"
echo "   sudo chmod 600 /opt/sira-ai/ssl/postgres/postgres-client.key"
echo "   sudo chmod 600 /opt/sira-ai/ssl/redis/redis-client.key"
echo "   sudo chmod 644 /opt/sira-ai/ssl/ca/ca.crt"
echo ""
echo "Option 3: Request from Infrastructure Team"
echo "-------------------------------------------"
echo "Contact the infrastructure team to obtain SSL certificates for local development."
echo ""
echo "⚠️  IMPORTANT:"
echo "   - Certificates are MANDATORY for production-grade deployment"
echo "   - No shortcuts or exceptions allowed"
echo "   - All database connections require mTLS"
echo "   - All Redis connections require TLS"
echo ""
echo "After setting up certificates, run:"
echo "   ./docker/scripts/validate-ssl.sh"
echo ""

exit 1

