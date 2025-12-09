#!/bin/bash
# SIRA Community Docker Initialization Script

set -e

echo "🚀 Initializing SIRA Community..."

# Wait for database to be ready
echo "⏳ Waiting for PostgreSQL..."
until PGPASSWORD=$COMMUNITY_DB_PASSWORD psql -h postgres -U $COMMUNITY_DB_USER -d $COMMUNITY_DB_NAME -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "✅ PostgreSQL is ready"

# Wait for Redis to be ready
echo "⏳ Waiting for Redis..."
until redis-cli -h redis -a "$COMMUNITY_REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; do
  echo "Redis is unavailable - sleeping"
  sleep 2
done
echo "✅ Redis is ready"

# Run database migrations
echo "📦 Running database migrations..."
bundle exec rake db:migrate

# Seed database if needed
if [ "$COMMUNITY_SEED_DB" = "true" ]; then
  echo "🌱 Seeding database..."
  bundle exec rake db:seed_fu
fi

echo "✅ SIRA Community initialization complete!"

# Execute the main command
exec "$@"



