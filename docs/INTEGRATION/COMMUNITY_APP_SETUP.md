# Community App (Discourse) Setup for Integration

## Overview

This document outlines the **minimal configuration changes** needed in the Discourse Community App to enable integration with SIRA App. **No code changes are required** - Discourse already supports all integration features out of the box.

## Required Configuration (Admin Panel Only)

### 1. Enable Discourse Connect (SSO)

**Location:** Admin Panel → Settings → Login

1. Navigate to: `https://local.community.sira.ai:8443/admin/site_settings/category/login`
2. Enable the following settings:

```
enable_discourse_connect = true
discourse_connect_url = https://app.sira.ai/auth/discourse/callback
discourse_connect_secret = [GENERATE_SECURE_SECRET_KEY]
```

**Important:**
- Generate a secure secret key (e.g., using `ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"`)
- Share this secret key with the SIRA App team (store in their `DISCOURSE_SSO_SECRET` env var)
- The `discourse_connect_url` must match the callback URL in SIRA App

**Optional Settings:**
```
discourse_connect_provider_name = SIRA App
discourse_connect_overrides_email = true
discourse_connect_overrides_username = true
discourse_connect_overrides_name = true
```

### 2. Generate API Key

**Location:** Admin Panel → API → Keys

1. Navigate to: `https://local.community.sira.ai:8443/admin/api/keys`
2. Click "New API Key"
3. Configure:
   - **Description:** "SIRA App Integration"
   - **User:** Select "system" user (or create dedicated API user)
   - **Scopes:** Select required scopes:
     - `read` - Read topics, posts, users
     - `write` - Create/update topics and posts (if needed)
     - `message_bus` - Access message bus (if needed)
4. Copy the generated API key
5. Share with SIRA App team (store in their `DISCOURSE_API_KEY` env var)

### 3. Configure CORS (Optional, if needed)

**Location:** Admin Panel → Settings → Security

If SIRA App needs to make direct API calls from the browser (not recommended), configure CORS:

```
cors_origins = https://app.sira.ai
cors_credentials = true
```

**Note:** It's recommended to proxy API calls through SIRA App backend instead of direct browser calls.

## What's NOT Required

### ❌ No Code Changes Needed

- Discourse already supports Discourse Connect (SSO) out of the box
- Discourse API is already available
- No plugin modifications required for basic integration
- No custom code needed in Discourse

### ❌ Plugin Updates Are Optional

The `discourse-sira-ai` plugin updates are **optional** and for **future enhancements**:
- Current plugin code is placeholder for future SIRA AI-specific features
- Basic SSO and API integration work without the plugin
- Plugin can be enhanced later for custom features

## Configuration Checklist

Before sharing integration docs with SIRA App team, ensure:

- [ ] Discourse Connect enabled
- [ ] SSO secret key generated and shared securely
- [ ] API key generated with appropriate scopes
- [ ] API key shared securely with SIRA App team
- [ ] CORS configured (if direct browser API calls needed)
- [ ] Test SSO flow works (can test manually)

## Testing SSO Configuration

You can test SSO configuration manually:

1. Visit: `https://local.community.sira.ai:8443/session/sso_provider`
2. You should see SSO login page (if not configured, you'll see an error)
3. Once SIRA App implements SSO endpoints, test the full flow

## Security Notes

- **SSO Secret:** Must be kept secure, never commit to git
- **API Key:** Store securely, rotate periodically
- **HTTPS:** Ensure all redirects use HTTPS
- **Scopes:** Grant minimum required API scopes

## Summary

**For Community App Team:**
- ✅ Configure Discourse Connect (admin panel)
- ✅ Generate API key (admin panel)
- ✅ Share secrets securely with SIRA App team
- ❌ No code changes required
- ❌ No plugin modifications required

**For SIRA App Team:**
- ✅ All implementation code provided in integration guide
- ✅ Can proceed with implementation immediately
- ✅ Just need the secrets from Community App team

---

**Last Updated:** December 16, 2025

