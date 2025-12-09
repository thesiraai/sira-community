#!/bin/bash
# SSL Certificate Setup Script for SIRA Community

set -e

SSL_DIR="docker/nginx/ssl"
DOMAIN="${COMMUNITY_HOSTNAME:-community.sira.ai}"

echo "🔒 Setting up SSL certificates for $DOMAIN..."

# Create SSL directory
mkdir -p "$SSL_DIR"

# Check if certificates already exist
if [ -f "$SSL_DIR/cert.pem" ] && [ -f "$SSL_DIR/key.pem" ]; then
    echo "✅ SSL certificates already exist"
    exit 0
fi

# Check if Let's Encrypt certificates exist
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "📋 Found Let's Encrypt certificates, copying..."
    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"
    chmod 644 "$SSL_DIR/cert.pem"
    chmod 600 "$SSL_DIR/key.pem"
    echo "✅ Let's Encrypt certificates copied"
    exit 0
fi

# Generate self-signed certificate for development
echo "⚠️  No certificates found. Generating self-signed certificate for development..."
echo "   For production, use Let's Encrypt or your CA certificates"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/key.pem" \
    -out "$SSL_DIR/cert.pem" \
    -subj "/CN=$DOMAIN/O=SIRA Community/C=US" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN"

chmod 644 "$SSL_DIR/cert.pem"
chmod 600 "$SSL_DIR/key.pem"

echo "✅ Self-signed certificate generated"
echo "⚠️  WARNING: Self-signed certificates are for development only!"
echo "   For production, replace with valid SSL certificates"



