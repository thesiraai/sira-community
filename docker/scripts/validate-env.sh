#!/bin/bash
# Environment File Validation Script
# Validates that all required environment variables are set correctly

set -e

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

echo "🔍 Validating environment file: $ENV_FILE"
echo ""

# Source the environment file
set -a
source "$ENV_FILE"
set +a

ERRORS=0
WARNINGS=0

# Function to check required variable
check_required() {
    local var_name=$1
    local var_value="${!var_name}"
    
    if [ -z "$var_value" ]; then
        echo "❌ Missing required variable: $var_name"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    
    # Check for placeholder values
    if echo "$var_value" | grep -qiE "change_me|placeholder|replace|example|localhost.*prod|dev.*prod"; then
        if [ "$ENV_FILE" = "docker/env.prod" ] || [ "$ENV_FILE" = ".env" ]; then
            echo "⚠️  Warning: $var_name may contain placeholder value"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
    
    return 0
}

# Function to validate format
validate_format() {
    local var_name=$1
    local var_value="${!var_name}"
    local pattern=$2
    local description=$3
    
    if [ -n "$var_value" ] && ! echo "$var_value" | grep -qE "$pattern"; then
        echo "❌ Invalid format for $var_name: $description"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    
    return 0
}

# Required variables
echo "📋 Checking required variables..."
check_required "COMMUNITY_HOSTNAME"
check_required "COMMUNITY_DB_NAME"
check_required "COMMUNITY_DB_USER"
check_required "COMMUNITY_DB_PASSWORD"
check_required "COMMUNITY_SECRET_KEY_BASE"
check_required "COMMUNITY_SMTP_ADDRESS"
check_required "COMMUNITY_SMTP_USER_NAME"
check_required "COMMUNITY_SMTP_PASSWORD"

echo ""

# Format validations
echo "🔐 Validating security settings..."

# Secret key base must be 128 hex characters
if [ -n "$COMMUNITY_SECRET_KEY_BASE" ]; then
    if [ ${#COMMUNITY_SECRET_KEY_BASE} -ne 128 ]; then
        echo "❌ COMMUNITY_SECRET_KEY_BASE must be exactly 128 characters (got ${#COMMUNITY_SECRET_KEY_BASE})"
        ERRORS=$((ERRORS + 1))
    elif ! echo "$COMMUNITY_SECRET_KEY_BASE" | grep -qE "^[0-9a-f]{128}$"; then
        echo "❌ COMMUNITY_SECRET_KEY_BASE must be hexadecimal (0-9, a-f)"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ COMMUNITY_SECRET_KEY_BASE format is valid"
    fi
fi

# Password strength check (for server environments)
if [[ "$ENV_FILE" == *".dev" ]] || [[ "$ENV_FILE" == *".test" ]] || [[ "$ENV_FILE" == *".stage" ]] || [[ "$ENV_FILE" == *".prod" ]] || [[ "$ENV_FILE" == ".env" ]]; then
    if [ ${#COMMUNITY_DB_PASSWORD} -lt 32 ]; then
        echo "⚠️  Warning: COMMUNITY_DB_PASSWORD is less than 32 characters (recommended for servers)"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if [ -n "$COMMUNITY_REDIS_PASSWORD" ] && [ ${#COMMUNITY_REDIS_PASSWORD} -lt 32 ]; then
        echo "⚠️  Warning: COMMUNITY_REDIS_PASSWORD is less than 32 characters (recommended for servers)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Hostname validation
if [ -n "$COMMUNITY_HOSTNAME" ]; then
    if [[ "$COMMUNITY_HOSTNAME" == "localhost" ]] && [[ "$ENV_FILE" != *"local"* ]]; then
        echo "⚠️  Warning: COMMUNITY_HOSTNAME is 'localhost' in non-local environment"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Port validation
if [ -n "$COMMUNITY_PORT" ]; then
    if [ "$COMMUNITY_PORT" -lt 1024 ] || [ "$COMMUNITY_PORT" -gt 65535 ]; then
        echo "❌ Invalid COMMUNITY_PORT: must be between 1024 and 65535"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Database pool validation
if [ -n "$COMMUNITY_DB_POOL" ]; then
    if [ "$COMMUNITY_DB_POOL" -lt 1 ] || [ "$COMMUNITY_DB_POOL" -gt 50 ]; then
        echo "⚠️  Warning: COMMUNITY_DB_POOL is outside recommended range (1-50)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Validation passed! Environment file is ready."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Validation passed with $WARNINGS warning(s). Review warnings above."
    exit 0
else
    echo "❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)."
    echo "Please fix the errors before deploying."
    exit 1
fi



