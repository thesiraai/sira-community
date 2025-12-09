#!/bin/bash
# SIRA Community Deployment Script
# Handles deployment for different environments

set -e

ENVIRONMENT="${1:-prod}"
ENV_FILE="docker/env.$ENVIRONMENT"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: Environment file '$ENV_FILE' not found"
    echo "Available environments: local, dev, test, stage, prod"
    exit 1
fi

echo "🚀 Deploying SIRA Community to: $ENVIRONMENT"
echo ""

# Validate environment file
echo "🔍 Validating environment configuration..."
if [ -f "docker/scripts/validate-env.sh" ]; then
    bash docker/scripts/validate-env.sh "$ENV_FILE" || {
        echo "❌ Environment validation failed. Please fix errors before deploying."
        exit 1
    }
fi

# Copy environment file
echo "📋 Copying environment file..."
cp "$ENV_FILE" .env
echo "✅ Environment file copied to .env"

# Build images
echo "🔨 Building Docker images..."
docker-compose build --no-cache

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Start services
echo "▶️  Starting services..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
docker-compose ps

# Run migrations
echo "📦 Running database migrations..."
docker-compose exec -T app bundle exec rake db:migrate || {
    echo "⚠️  Migration failed or database already migrated"
}

# Seed database if first deployment
if [ "$ENVIRONMENT" = "local" ] || [ "$ENVIRONMENT" = "dev" ]; then
    read -p "Seed database with initial data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🌱 Seeding database..."
        docker-compose exec -T app bundle exec rake db:seed_fu
    fi
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Service Status:"
docker-compose ps
echo ""
echo "📝 View logs:"
echo "   docker-compose logs -f app"
echo ""
echo "🌐 Application URL:"
grep "COMMUNITY_HOSTNAME" .env | cut -d'=' -f2 | sed 's/^/   https:\/\//'



