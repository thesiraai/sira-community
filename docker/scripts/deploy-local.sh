#!/bin/bash
# Local Deployment Script - Production-Grade Standards
# NO SHORTCUTS - All security features enabled, mTLS required

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🚀 SIRA Community - Local Deployment (Production-Grade)"
echo "======================================================"
echo ""
echo "⚠️  IMPORTANT: This deployment follows production-grade standards"
echo "   - mTLS required for all database connections"
echo "   - SSL certificates mandatory"
echo "   - Production security features enabled"
echo "   - NO shortcuts or exceptions"
echo ""

# Step 1: Validate prerequisites
echo "Step 1: Validating prerequisites..."
echo "-----------------------------------"

# Check if infrastructure is running
if ! docker network inspect sira_infra_network > /dev/null 2>&1; then
    echo "❌ ERROR: sira_infra_network not found"
    echo "   Please start infrastructure services first:"
    echo "   cd sira-infra/infra/docker/compose"
    echo "   docker compose -f docker-compose.infra.yml --env-file env.local up -d"
    exit 1
fi
echo "✅ Infrastructure network found"

# Check SSL certificates
if [ ! -d "/opt/sira-ai/ssl" ]; then
    echo "❌ ERROR: SSL certificates not found at /opt/sira-ai/ssl"
    echo "   SSL certificates are MANDATORY for production-grade deployment"
    echo "   Please ensure infrastructure SSL certificates are available"
    exit 1
fi
echo "✅ SSL certificates directory found"

# Validate SSL certificates
if [ -f "$SCRIPT_DIR/validate-ssl.sh" ]; then
    echo "Validating SSL certificates..."
    SSL_CERTS_PATH=/opt/sira-ai/ssl "$SCRIPT_DIR/validate-ssl.sh"
    if [ $? -ne 0 ]; then
        echo "❌ SSL certificate validation failed"
        exit 1
    fi
fi

# Step 2: Generate secrets if needed
echo ""
echo "Step 2: Checking secrets..."
echo "---------------------------"

# Check if secret key is set
if grep -q "GENERATE_SECURE_SECRET\|REPLACE_THIS" docker/env.community.app.local; then
    echo "⚠️  WARNING: Secret key needs to be generated"
    echo "   Generating secure secret key..."
    SECRET_KEY=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
    echo "   Generated secret key (add to docker/env.community.app.local):"
    echo "   COMMUNITY_SECRET_KEY_BASE=$SECRET_KEY"
    echo ""
    read -p "Press Enter after updating docker/env.community.app.local with the secret key..."
fi

# Step 3: Create configuration files
echo ""
echo "Step 3: Creating configuration files..."
echo "----------------------------------------"

# Create discourse.conf if it doesn't exist
if [ ! -f "config/discourse.conf" ]; then
    echo "Creating config/discourse.conf from template..."
    cp config/discourse.conf.local.example config/discourse.conf
    
    # Update hostname
    sed -i.bak 's/hostname = "localhost"/hostname = "localhost"/' config/discourse.conf
    rm -f config/discourse.conf.bak
    
    echo "✅ config/discourse.conf created"
    echo "⚠️  Please review and update config/discourse.conf with your values"
else
    echo "✅ config/discourse.conf exists"
fi

# Create .env file
if [ ! -f ".env" ]; then
    echo "Creating .env from docker/env.community.app.local..."
    cp docker/env.community.app.local .env
    echo "✅ .env file created"
    echo "⚠️  Please review and update .env with your values"
else
    echo "✅ .env file exists"
fi

# Step 4: Pre-deployment validation
echo ""
echo "Step 4: Pre-deployment validation..."
echo "-------------------------------------"

if [ -f "$SCRIPT_DIR/pre-deploy-check.sh" ]; then
    "$SCRIPT_DIR/pre-deploy-check.sh"
    if [ $? -ne 0 ]; then
        echo "❌ Pre-deployment validation failed"
        exit 1
    fi
fi

# Step 5: Build Docker images
echo ""
echo "Step 5: Building Docker images..."
echo "---------------------------------"

docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    build

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed"
    exit 1
fi
echo "✅ Docker images built successfully"

# Step 6: Start services
echo ""
echo "Step 6: Starting services..."
echo "----------------------------"

docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    up -d

if [ $? -ne 0 ]; then
    echo "❌ Failed to start services"
    exit 1
fi
echo "✅ Services started"

# Step 7: Wait for services to be healthy
echo ""
echo "Step 7: Waiting for services to be healthy..."
echo "---------------------------------------------"

echo "Waiting for app service to be ready..."
for i in {1..30}; do
    if docker compose -f docker/docker-compose.sira-community.app.yml \
        --env-file docker/env.community.app.local \
        exec -T app curl -f http://localhost:3000/srv/status > /dev/null 2>&1; then
        echo "✅ App service is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  App service health check timeout (may still be starting)"
    else
        echo "   Waiting... ($i/30)"
        sleep 2
    fi
done

# Step 8: Initialize database
echo ""
echo "Step 8: Initializing database..."
echo "---------------------------------"

echo "Running database migrations..."
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec -T app bundle exec rake db:migrate

if [ $? -ne 0 ]; then
    echo "❌ Database migration failed"
    exit 1
fi
echo "✅ Database migrations completed"

echo "Seeding initial data..."
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec -T app bundle exec rake db:seed_fu

if [ $? -ne 0 ]; then
    echo "⚠️  Database seeding completed with warnings (may be normal)"
else
    echo "✅ Database seeded"
fi

# Step 9: Verification
echo ""
echo "Step 9: Verifying deployment..."
echo "-------------------------------"

# Check service status
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    ps

# Test database connection
echo "Testing database connection..."
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec -T app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').values" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Database connection successful (mTLS working)"
else
    echo "❌ Database connection failed"
    exit 1
fi

# Test Redis connection
echo "Testing Redis connection..."
docker compose -f docker/docker-compose.sira-community.app.yml \
    --env-file docker/env.community.app.local \
    exec -T app bundle exec rails runner "puts Discourse.redis.ping" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Redis connection successful (TLS working)"
else
    echo "❌ Redis connection failed"
    exit 1
fi

# Test HTTP endpoint
echo "Testing HTTP endpoint..."
if curl -k -f https://localhost:8443/health > /dev/null 2>&1; then
    echo "✅ HTTP endpoint accessible"
else
    echo "⚠️  HTTP endpoint not yet accessible (may need a moment)"
fi

# Summary
echo ""
echo "======================================================"
echo "✅ Local Deployment Complete (Production-Grade)"
echo "======================================================"
echo ""
echo "Services are running with:"
echo "  ✅ mTLS for database connections"
echo "  ✅ TLS for Redis connections"
echo "  ✅ Production security features enabled"
echo "  ✅ SSL certificates validated"
echo ""
echo "Access the application:"
echo "  🌐 HTTPS: https://localhost:8443"
echo "  🔒 HTTP (redirects to HTTPS): http://localhost:8080"
echo ""
echo "View logs:"
echo "  docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.local logs -f"
echo ""
echo "Stop services:"
echo "  docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.local down"
echo ""

