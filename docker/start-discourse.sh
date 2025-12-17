#!/bin/bash
# Quick start script for Discourse using official Docker image

set -e

echo "=== Starting SIRA Discourse Community ==="
echo ""

# Check if environment file exists
if [ ! -f "env.discourse.local" ]; then
    echo "ERROR: env.discourse.local not found!"
    echo "Please configure env.discourse.local with your settings."
    exit 1
fi

# Check if secret key is set
if grep -q "CHANGE_ME" env.discourse.local; then
    echo "WARNING: Please update CHANGE_ME values in env.discourse.local"
    echo "  - Generate secret key: ruby -e \"require 'securerandom'; puts SecureRandom.hex(64)\""
    echo "  - Set SIRA_API_KEY"
    echo "  - Configure SMTP settings"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Pull latest images (only downloads if updates available)
echo "Checking for image updates..."
docker compose -f docker-compose.discourse.yml pull

# Start Discourse
echo "Starting Discourse..."
docker compose -f docker-compose.discourse.yml up -d

echo ""
echo "✓ Discourse is starting..."
echo "  - Access at: https://local.community.sira.ai:8443"
echo "  - Check logs: docker compose -f docker-compose.discourse.yml logs -f discourse"
echo "  - Stop: docker compose -f docker-compose.discourse.yml down"

