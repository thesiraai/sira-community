#!/bin/bash
# Generate Environment File with Secure Random Values
# Usage: ./generate-env.sh [environment] [output_file]

set -e

ENVIRONMENT="${1:-prod}"
OUTPUT_FILE="${2:-.env}"

if [ ! -f "docker/env.$ENVIRONMENT" ]; then
    echo "❌ Error: Template file 'docker/env.$ENVIRONMENT' not found"
    echo "Available environments: local, dev, test, stage, prod"
    exit 1
fi

echo "🔧 Generating environment file for: $ENVIRONMENT"
echo "📝 Output file: $OUTPUT_FILE"
echo ""

# Check if output file exists
if [ -f "$OUTPUT_FILE" ]; then
    read -p "⚠️  File $OUTPUT_FILE already exists. Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Copy template
cp "docker/env.$ENVIRONMENT" "$OUTPUT_FILE"

# Generate secret key base if it contains placeholder
if grep -q "REPLACE_WITH\|local_development_secret" "$OUTPUT_FILE"; then
    echo "🔐 Generating secret key base..."
    SECRET_KEY=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/REPLACE_WITH_128_CHAR_HEX_STRING_GENERATED_FOR_PRODUCTION_ONLY/$SECRET_KEY/g" "$OUTPUT_FILE"
        sed -i '' "s/local_development_secret_key_base_64_chars_minimum_for_rails_app_2024_local_dev_only_not_for_production_use/$SECRET_KEY/g" "$OUTPUT_FILE"
    else
        # Linux
        sed -i "s/REPLACE_WITH_128_CHAR_HEX_STRING_GENERATED_FOR_PRODUCTION_ONLY/$SECRET_KEY/g" "$OUTPUT_FILE"
        sed -i "s/local_development_secret_key_base_64_chars_minimum_for_rails_app_2024_local_dev_only_not_for_production_use/$SECRET_KEY/g" "$OUTPUT_FILE"
    fi
    echo "✅ Secret key generated"
fi

# Generate secure passwords for server environments
if [[ "$ENVIRONMENT" != "local" ]]; then
    echo "🔐 Generating secure passwords..."
    
    # Database password
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/.*_DB_P@ssw0rd.*/COMMUNITY_DB_PASSWORD=$DB_PASSWORD/g" "$OUTPUT_FILE"
    else
        sed -i "s/.*_DB_P@ssw0rd.*/COMMUNITY_DB_PASSWORD=$DB_PASSWORD/g" "$OUTPUT_FILE"
    fi
    
    # Redis password
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/.*_Redis_P@ssw0rd.*/COMMUNITY_REDIS_PASSWORD=$REDIS_PASSWORD/g" "$OUTPUT_FILE"
    else
        sed -i "s/.*_Redis_P@ssw0rd.*/COMMUNITY_REDIS_PASSWORD=$REDIS_PASSWORD/g" "$OUTPUT_FILE"
    fi
    
    echo "✅ Passwords generated"
fi

echo ""
echo "✅ Environment file generated: $OUTPUT_FILE"
echo ""
echo "⚠️  IMPORTANT: Review and update the following:"
echo "   - COMMUNITY_SMTP_PASSWORD (SendGrid API key)"
echo "   - SIRA_API_KEY (SIRA API key)"
echo "   - COMMUNITY_HOSTNAME (verify domain)"
echo ""
echo "🔍 Validate the file:"
echo "   ./docker/scripts/validate-env.sh $OUTPUT_FILE"
echo ""



