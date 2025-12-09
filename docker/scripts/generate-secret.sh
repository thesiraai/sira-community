#!/bin/bash
# Generate secret key base for SIRA Community

echo "Generating 128-character hex secret key base..."
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
echo ""
echo "Copy this value to your .env file as COMMUNITY_SECRET_KEY_BASE"



